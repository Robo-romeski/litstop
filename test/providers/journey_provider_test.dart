import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/journey.dart';
import 'package:litstop/providers/journey_provider.dart';
import 'package:litstop/services/busy_zone_selector.dart';
import 'package:litstop/services/constraint_poi.dart';
import 'package:litstop/services/journey_geocoder.dart';
import 'package:litstop/services/journey_prompt_parser.dart';
import 'package:litstop/services/journey_store.dart';
import 'package:litstop/services/routes_service.dart';

class _FakeLocator implements StopLocator {
  _FakeLocator(this.coords);
  final Map<String, LatLng> coords;

  @override
  Future<LatLng?> locate(String query) async {
    for (final entry in coords.entries) {
      if (query.toLowerCase().contains(entry.key)) return entry.value;
    }
    return null;
  }
}

void main() {
  late JourneyProvider provider;
  final now = DateTime(2026, 9, 6, 7, 0);
  final school = const LatLng(37.74, -122.48);
  final sfo = const LatLng(37.62, -122.38);

  setUp(() {
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({
        'school': school,
        'sfo': sfo,
      }),
    );
  });

  test('parsePrompt stores a draft journey', () {
    provider.parsePrompt(
      'School drop at 8:15, then drive until 2, be at SFO arrivals by 6.',
      now: now,
    );
    expect(provider.draft, isNotNull);
    expect(provider.draft!.status, JourneyStatus.draft);
    expect(provider.draft!.stops, hasLength(3));
    expect(provider.active, isNull);
  });

  test('confirmDraft promotes draft to active', () async {
    provider.parsePrompt('Lunch at home', now: now);
    await provider.confirmDraft();
    expect(provider.draft, isNull);
    expect(provider.active?.status, JourneyStatus.active);
    expect(
        provider.active!.stops.single.title.toLowerCase(), contains('lunch'));
  });

  test('confirmDraft no-ops on empty prompt', () async {
    provider.parsePrompt('   ,  ,', now: now);
    await provider.confirmDraft();
    expect(provider.active, isNull);
  });

  test('removeStop updates the draft list', () {
    provider.parsePrompt('A, B, C', now: now);
    provider.removeStop('s2');
    expect(provider.draft!.stops.map((s) => s.title), ['A', 'C']);
  });

  test('nextStop is the first active stop', () async {
    provider.parsePrompt('School drop, SFO', now: now);
    expect(provider.nextStop, isNull);
    await provider.confirmDraft();
    expect(provider.nextStop!.title, contains('School'));
  });

  test('markers stay empty until locations resolve', () {
    provider.parsePrompt('School drop, SFO', now: now);
    expect(provider.markers, isEmpty);
    expect(provider.polylines, isEmpty);
  });

  test('confirmDraft geocodes hard stops and draws a polyline', () async {
    provider.parsePrompt(
      'School drop at 8:15, then drive until 2, be at SFO arrivals by 6.',
      now: now,
    );
    await provider.confirmDraft();

    expect(provider.markers, hasLength(2));
    expect(provider.polylines, hasLength(1));
    expect(provider.polylines.single.points, [school, sfo]);
    expect(provider.nextActionSpeech, 'Next stop: School drop.');
  });

  test('speak is called with next-action copy', () async {
    String? heard;
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school}),
      speak: (text) async => heard = text,
    );
    provider.parsePrompt('School drop', now: now);
    await provider.confirmDraft();
    expect(heard, 'Next stop: School drop.');
  });

  test('uses RoutePlanner polyline when routing succeeds', () async {
    final via = const LatLng(37.70, -122.41);
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      router: _FakeRouter(
        polyline: [school, via, sfo],
      ),
    );
    provider.parsePrompt('School drop, SFO', now: now);
    await provider.confirmDraft();
    expect(provider.polylines.single.points, [school, via, sfo]);
  });

  test('falls back to stop order when routing fails', () async {
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      router: _FakeRouter(fail: true),
    );
    provider.parsePrompt('School drop, SFO', now: now);
    await provider.confirmDraft();
    expect(provider.polylines.single.points, [school, sfo]);
  });

  test('applies optimized intermediate order to located stops', () async {
    final cafe = const LatLng(37.78, -122.41);
    final diner = const LatLng(37.76, -122.40);
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({
        'school': school,
        'cafe': cafe,
        'diner': diner,
        'sfo': sfo,
      }),
      router: _FakeRouter(
        polyline: [school, diner, cafe, sfo],
        optimizedIntermediateIndex: const [1, 0],
      ),
    );
    provider.parsePrompt('School drop, cafe, diner, SFO', now: now);
    await provider.confirmDraft();
    expect(
      provider.active!.stops.where((s) => s.hasLocation).map((s) => s.title),
      ['School drop', 'diner', 'cafe', 'SFO'],
    );
  });

  test('anchors roam-for-work to a predicted busy zone on the way', () async {
    final onTheWay = LatLng(
      (school.latitude + sfo.latitude) / 2,
      (school.longitude + sfo.longitude) / 2,
    );
    final far = const LatLng(37.90, -122.20);
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      zoneSupplier: () => [
        PredictedBusyZone(location: far, score: 1.0, label: 'far'),
        PredictedBusyZone(
          location: onTheWay,
          score: 0.5,
          label: PredictedActivityCopy.zoneTitle,
        ),
      ],
    );
    provider.parsePrompt(
      'School drop at 8:15, then drive until 2, be at SFO arrivals by 6.',
      now: now,
    );
    await provider.confirmDraft();

    final roam = provider.active!.stops.singleWhere(
      (s) => s.kind == JourneyStopKind.roamForWork,
    );
    expect(roam.location, onTheWay);
    expect(provider.markers, hasLength(3));
    expect(provider.polylines.single.points, [school, onTheWay, sfo]);
  });

  test('roam next-stop speech uses predicted-busy copy', () async {
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'sfo': sfo}),
      zoneSupplier: () => [
        PredictedBusyZone(
          location: const LatLng(37.77, -122.42),
          score: 0.8,
          label: PredictedActivityCopy.zoneTitle,
        ),
      ],
    );
    provider.parsePrompt(
      'drive until 2, be at SFO arrivals by 6.',
      now: now,
    );
    await provider.confirmDraft();
    expect(
      provider.nextActionSpeech,
      startsWith(PredictedActivityCopy.roamSpeech),
    );
    expect(provider.nextActionSpeech!.toLowerCase(), isNot(contains('surge')));
  });

  test('completeActive saves history and traces that reload from the store',
      () async {
    final store = MemoryJourneyStore();
    var n = 0;
    var j = 0;
    final first = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      store: store,
    );
    await first.restore();
    first.parsePrompt(
      'School drop at 8:15, then drive until 2, be at SFO arrivals by 6.',
      now: now,
    );
    await first.confirmDraft();
    first.recordTracePoint(school);
    first.recordTracePoint(sfo);
    await first.completeActive();

    expect(first.active, isNull);
    expect(first.history, hasLength(1));
    expect(first.history.single.status, JourneyStatus.completed);
    expect(first.history.single.stops, hasLength(3));
    expect(first.history.single.trace, [school, sfo]);

    n = 0;
    j = 0;
    final reloaded = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      store: store,
    );
    await reloaded.restore();
    expect(reloaded.history, hasLength(1));
    expect(reloaded.history.single.id, first.history.single.id);
    expect(reloaded.history.single.trace, [school, sfo]);
    expect(
      reloaded.history.single.stops.map((s) => s.title),
      first.history.single.stops.map((s) => s.title),
    );
  });

  test('missed window drops the stop, reorders remaining, and speaks',
      () async {
    final cafe = const LatLng(37.78, -122.41);
    final diner = const LatLng(37.76, -122.40);
    String? heard;
    var n = 0;
    var j = 0;
    final router = _FakeRouter(
      polyline: [school, cafe, diner, sfo],
      optimizedByCall: const [
        [0, 1],
        [1, 0],
      ],
    );
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({
        'school': school,
        'cafe': cafe,
        'diner': diner,
        'sfo': sfo,
      }),
      router: router,
      speak: (text) async => heard = text,
      clock: () => now,
    );
    provider.parsePrompt(
      'School drop at 8:15, cafe, diner, SFO arrivals by 6',
      now: now,
    );
    await provider.confirmDraft();
    expect(provider.nextStop!.title, contains('School'));
    expect(heard, 'Next stop: School drop.');
    expect(router.planCalls, 1);

    await provider.tick(now: DateTime(2026, 9, 6, 9, 0), here: school);

    expect(
      provider.active!.stops.map((s) => s.title),
      ['diner', 'cafe', 'SFO arrivals'],
    );
    expect(provider.nextActionSpeech, 'Next stop: diner.');
    expect(heard, 'Next stop: diner.');
    expect(router.planCalls, 2);

    await provider.tick(now: DateTime(2026, 9, 6, 9, 1), here: school);
    expect(router.planCalls, 2);
  });

  test('skipNextStop drops the current stop and speaks the new next', () async {
    String? heard;
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      speak: (text) async => heard = text,
    );
    provider.parsePrompt('School drop, SFO arrivals', now: now);
    await provider.confirmDraft();
    await provider.skipNextStop(here: school);
    expect(provider.nextStop!.title, contains('SFO'));
    expect(heard, 'Next stop: SFO arrivals.');
  });

  test('fatigue flag inserts a rest stop ahead of remaining hard stops',
      () async {
    String? heard;
    var tired = false;
    var n = 0;
    var j = 0;
    final restAt = const LatLng(37.76, -122.43);
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      needsRest: () => tired,
      findConstraint: (kind, from) async => ConstraintCandidate(
        title: 'Lincoln Rest Area',
        location: restAt,
      ),
      speak: (text) async => heard = text,
      clock: () => now,
    );
    provider.parsePrompt('School drop, SFO arrivals', now: now);
    await provider.confirmDraft();
    expect(provider.nextStop!.title, contains('School'));

    tired = true;
    await provider.considerConstraints(here: school);

    expect(provider.active!.stops.first.kind, JourneyStopKind.rest);
    expect(provider.active!.stops.first.title, 'Lincoln Rest Area');
    expect(
      provider.active!.stops.map((s) => s.title),
      ['Lincoln Rest Area', 'School drop', 'SFO arrivals'],
    );
    expect(heard, contains('Fatigue limit reached'));
    expect(heard!.toLowerCase(), isNot(contains('surge')));
    expect(
      provider.nextActionSpeech,
      'Take a rest stop at Lincoln Rest Area.',
    );
  });

  test('skip of an inserted rest stop leaves the original plan', () async {
    var tired = true;
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      needsRest: () => tired,
      findConstraint: (kind, from) async => const ConstraintCandidate(
        title: 'Lincoln Rest Area',
        location: LatLng(37.76, -122.43),
      ),
      clock: () => now,
    );
    provider.parsePrompt('School drop, SFO arrivals', now: now);
    await provider.confirmDraft();
    expect(provider.nextStop!.kind, JourneyStopKind.rest);

    await provider.skipNextStop(here: school);
    expect(
      provider.active!.stops.map((s) => s.title),
      ['School drop', 'SFO arrivals'],
    );

    await provider.considerConstraints(here: school);
    expect(
      provider.active!.stops.map((s) => s.title),
      ['School drop', 'SFO arrivals'],
    );
  });

  test('fuel flag inserts a gas stop', () async {
    var n = 0;
    var j = 0;
    provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j${++j}',
      locator: _FakeLocator({'school': school, 'sfo': sfo}),
      needsFuel: () => true,
      findConstraint: (kind, from) async => const ConstraintCandidate(
        title: 'Shell',
        location: LatLng(37.75, -122.44),
      ),
      clock: () => now,
    );
    provider.parsePrompt('School drop, SFO arrivals', now: now);
    await provider.confirmDraft();
    expect(provider.nextStop!.kind, JourneyStopKind.fuel);
    expect(provider.nextActionSpeech, 'Stop for gas at Shell.');
  });
}

class _FakeRouter implements RoutePlanner {
  _FakeRouter({
    this.polyline = const [],
    this.optimizedIntermediateIndex = const [],
    this.optimizedByCall,
    this.fail = false,
  });

  final List<LatLng> polyline;
  final List<int> optimizedIntermediateIndex;
  final List<List<int>>? optimizedByCall;
  final bool fail;
  int planCalls = 0;

  @override
  Future<PlannedRoute> plan({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> intermediates = const [],
  }) async {
    if (fail) throw Exception('routes down');
    final optimized =
        optimizedByCall != null && planCalls < optimizedByCall!.length
            ? optimizedByCall![planCalls]
            : optimizedIntermediateIndex;
    planCalls++;
    return PlannedRoute(
      polyline: polyline,
      optimizedIntermediateIndex: optimized,
    );
  }
}
