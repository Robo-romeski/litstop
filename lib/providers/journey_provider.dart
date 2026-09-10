import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/journey.dart';
import '../services/busy_zone_selector.dart';
import '../services/constraint_poi.dart';
import '../services/journey_geocoder.dart';
import '../services/journey_prompt_parser.dart';
import '../services/journey_store.dart';
import '../services/routes_service.dart';
import '../utils/heatmap_utils.dart';

typedef JourneySpeaker = Future<void> Function(String text);

class JourneyProvider with ChangeNotifier {
  final JourneyPromptParser _parser;
  final String Function() _journeyId;
  final StopLocator? _locator;
  final RoutePlanner? _router;
  final JourneySpeaker? _speak;
  final BusyZoneSupplier? _zones;
  final JourneyStore? _store;
  final Duration _debounce;
  final Duration _autoTick;
  final DateTime Function() _clock;
  final ConstraintSignal? _needsRest;
  final ConstraintSignal? _needsFuel;
  final ConstraintFinder? _findConstraint;

  Journey? _draft;
  Journey? _active;
  List<LatLng> _routePoints = const [];
  List<LatLng> _trace = [];
  List<Journey> _history = [];
  Future<void>? _restoreFuture;
  Timer? _tickTimer;
  DateTime? _lastReplanAt;
  LatLng? _lastReplanHere;
  String? _lastSpoken;
  bool _replanInFlight = false;
  bool _skippedRest = false;
  bool _skippedFuel = false;

  static const historyLimit = 20;
  static const defaultDebounce = Duration(minutes: 2);

  JourneyProvider({
    JourneyPromptParser? parser,
    String Function()? journeyId,
    StopLocator? locator,
    RoutePlanner? router,
    JourneySpeaker? speak,
    BusyZoneSupplier? zoneSupplier,
    JourneyStore? store,
    Duration debounce = defaultDebounce,
    Duration autoTick = Duration.zero,
    DateTime Function()? clock,
    ConstraintSignal? needsRest,
    ConstraintSignal? needsFuel,
    ConstraintFinder? findConstraint,
  })  : _parser = parser ?? JourneyPromptParser(),
        _journeyId = journeyId ?? const Uuid().v4,
        _locator = locator,
        _router = router,
        _speak = speak,
        _zones = zoneSupplier,
        _store = store,
        _debounce = debounce,
        _autoTick = autoTick,
        _clock = clock ?? DateTime.now,
        _needsRest = needsRest,
        _needsFuel = needsFuel,
        _findConstraint = findConstraint {
    unawaited(restore());
  }

  Journey? get draft => _draft;
  Journey? get active => _active;
  List<Journey> get history => List.unmodifiable(_history);
  List<JourneyStop> get visibleStops => (_active ?? _draft)?.stops ?? const [];

  JourneyStop? get nextStop {
    final stops = _active?.stops;
    if (stops == null || stops.isEmpty) return null;
    return stops.first;
  }

  String? get nextActionSpeech {
    final stop = nextStop;
    if (stop == null) return null;
    if (stop.kind == JourneyStopKind.roamForWork) {
      final until = stop.windowEnd;
      if (until == null) return '${PredictedActivityCopy.roamSpeech}.';
      return '${PredictedActivityCopy.roamSpeech} until ${_formatClock(until)}.';
    }
    if (stop.kind == JourneyStopKind.rest) {
      return 'Take a rest stop at ${stop.title}.';
    }
    if (stop.kind == JourneyStopKind.fuel) {
      return 'Stop for gas at ${stop.title}.';
    }
    return 'Next stop: ${stop.title}.';
  }

  Set<Marker> get markers {
    final journey = _active;
    if (journey == null) return const {};
    final out = <Marker>{};
    for (var i = 0; i < journey.stops.length; i++) {
      final stop = journey.stops[i];
      if (!stop.hasLocation) continue;
      out.add(
        Marker(
          markerId: MarkerId('journey-${stop.id}'),
          position: stop.location!,
          infoWindow: InfoWindow(title: '${i + 1}. ${stop.title}'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _hueFor(stop.kind),
          ),
          zIndex: 20.0 + i,
        ),
      );
    }
    return out;
  }

  Set<Polyline> get polylines {
    final journey = _active;
    if (journey == null) return const {};
    final points = _routePoints.isNotEmpty
        ? _routePoints
        : [
            for (final stop in journey.stops)
              if (stop.hasLocation) stop.location!,
          ];
    if (points.length < 2) return const {};
    return {
      Polyline(
        polylineId: PolylineId('journey-${journey.id}'),
        points: points,
        width: 5,
        color: Colors.deepOrange,
      ),
    };
  }

  void parsePrompt(String prompt, {DateTime? now}) {
    final stops = _parser.parse(prompt, now: now);
    _draft = Journey(
      id: _journeyId(),
      createdAt: now ?? DateTime.now(),
      stops: stops,
      status: JourneyStatus.draft,
    );
    notifyListeners();
  }

  Future<void> confirmDraft() async {
    if (_draft == null || _draft!.stops.isEmpty) return;
    _active = _draft!.copyWith(status: JourneyStatus.active);
    _draft = null;
    _trace = [];
    _skippedRest = false;
    _skippedFuel = false;
    notifyListeners();
    await _geocodeActive();
    _anchorRoamStops();
    await _maybeInsertConstraints();
    await _routeActive();
    _lastReplanAt = _clock();
    _syncTicker();
    await _speakNextIfChanged();
  }

  Future<void> tick({DateTime? now, LatLng? here}) async {
    final journey = _active;
    if (journey == null || journey.stops.isEmpty) return;
    if (_replanInFlight) return;
    final clock = now ?? _clock();

    final dropped = _dropMissedStops(clock);
    if (_active == null || _active!.stops.isEmpty) {
      await completeActive();
      return;
    }

    final inserted = await _maybeInsertConstraints(here: here);

    final moved = here != null &&
        (_lastReplanHere == null ||
            HeatmapUtils.calculateDistance(_lastReplanHere!, here) >= 0.05);
    if (!dropped && !inserted && !moved) return;
    if (!dropped &&
        !inserted &&
        _lastReplanAt != null &&
        clock.difference(_lastReplanAt!) < _debounce) {
      _lastReplanHere ??= here;
      return;
    }

    await _replanRemaining(
      from: here,
      at: clock,
      speak: dropped && !inserted,
    );
  }

  Future<void> skipNextStop({DateTime? now, LatLng? here}) async {
    final journey = _active;
    if (journey == null || journey.stops.isEmpty) return;
    final skipped = journey.stops.first;
    if (skipped.kind == JourneyStopKind.rest) _skippedRest = true;
    if (skipped.kind == JourneyStopKind.fuel) _skippedFuel = true;
    final rest = journey.stops.sublist(1);
    if (rest.isEmpty) {
      await completeActive();
      return;
    }
    _active = journey.copyWith(stops: rest);
    notifyListeners();
    await _replanRemaining(from: here, at: now ?? _clock(), speak: true);
  }

  Future<bool> considerConstraints({LatLng? here}) {
    return _maybeInsertConstraints(here: here);
  }

  Future<bool> _maybeInsertConstraints({LatLng? here}) async {
    final journey = _active;
    if (journey == null || journey.stops.isEmpty) return false;

    LatLng? from = here;
    if (from == null) {
      for (final stop in journey.stops) {
        if (stop.hasLocation) {
          from = stop.location;
          break;
        }
      }
    }
    if (from == null) from = _lastReplanHere;
    if (from == null) return false;

    if (_needsRest?.call() == true &&
        !_skippedRest &&
        !_hasKind(JourneyStopKind.rest)) {
      return _insertConstraint(JourneyStopKind.rest, from);
    }
    if (_needsFuel?.call() == true &&
        !_skippedFuel &&
        !_hasKind(JourneyStopKind.fuel)) {
      return _insertConstraint(JourneyStopKind.fuel, from);
    }
    return false;
  }

  bool _hasKind(JourneyStopKind kind) {
    return _active?.stops.any((s) => s.kind == kind) ?? false;
  }

  Future<bool> _insertConstraint(JourneyStopKind kind, LatLng from) async {
    final journey = _active;
    if (journey == null) return false;
    ConstraintCandidate? candidate;
    try {
      candidate = await _findConstraint?.call(kind, from);
    } catch (_) {}
    final title = candidate?.title ??
        (kind == JourneyStopKind.fuel ? 'Gas station' : 'Rest stop');
    final location = candidate?.location ?? from;
    final prompt = kind == JourneyStopKind.fuel
        ? 'Fuel is low. Adding a gas stop at $title. Skip if you want to keep driving.'
        : 'Fatigue limit reached. Adding a rest stop at $title. Skip if you want to keep driving.';
    if (_speak != null) await _speak!(prompt);

    _active = journey.copyWith(
      stops: [
        JourneyStop(
          id: 'c-${_clock().microsecondsSinceEpoch}',
          title: title,
          kind: kind,
          location: location,
        ),
        ...journey.stops,
      ],
    );
    _lastSpoken = nextActionSpeech;
    notifyListeners();
    return true;
  }

  static double _hueFor(JourneyStopKind kind) {
    switch (kind) {
      case JourneyStopKind.roamForWork:
        return BitmapDescriptor.hueAzure;
      case JourneyStopKind.rest:
        return BitmapDescriptor.hueGreen;
      case JourneyStopKind.fuel:
        return BitmapDescriptor.hueYellow;
      case JourneyStopKind.hardStop:
        return BitmapDescriptor.hueOrange;
    }
  }

  bool _dropMissedStops(DateTime now) {
    final journey = _active;
    if (journey == null) return false;
    final remaining =
        journey.stops.where((stop) => !stop.isMissedAt(now)).toList();
    if (remaining.length == journey.stops.length) return false;
    _active = journey.copyWith(stops: remaining);
    notifyListeners();
    return true;
  }

  Future<void> _replanRemaining({
    LatLng? from,
    required DateTime at,
    required bool speak,
  }) async {
    if (_replanInFlight) return;
    _replanInFlight = true;
    try {
      await _routeActive(from: from);
      _lastReplanAt = at;
      if (from != null) _lastReplanHere = from;
      if (speak) await _speakNextIfChanged();
    } finally {
      _replanInFlight = false;
    }
  }

  Future<void> _speakNextIfChanged() async {
    final speech = nextActionSpeech;
    if (speech == null || speech == _lastSpoken) return;
    _lastSpoken = speech;
    if (_speak != null) await _speak!(speech);
  }

  void _syncTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
    if (_autoTick <= Duration.zero || _active == null) return;
    _tickTimer = Timer.periodic(_autoTick, (_) => tick());
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  Future<void> restore() {
    final store = _store;
    if (store == null) return Future.value();
    return _restoreFuture ??= () async {
      try {
        _history = await store.load();
        notifyListeners();
      } catch (_) {}
    }();
  }

  void recordTracePoint(LatLng point) {
    if (_active == null) return;
    if (_trace.isNotEmpty) {
      final last = _trace.last;
      if (HeatmapUtils.calculateDistance(last, point) < 0.05) return;
    }
    _trace.add(point);
  }

  Future<void> completeActive() async {
    await restore();
    final journey = _active;
    if (journey == null) return;
    final trace = _trace.isNotEmpty
        ? List<LatLng>.of(_trace)
        : List<LatLng>.of(_routePoints);
    final completed = journey.copyWith(
      status: JourneyStatus.completed,
      trace: trace,
    );
    _history = [completed, ..._history].take(historyLimit).toList();
    _active = null;
    _routePoints = const [];
    _trace = [];
    _lastSpoken = null;
    _lastReplanAt = null;
    _lastReplanHere = null;
    _skippedRest = false;
    _skippedFuel = false;
    _syncTicker();
    notifyListeners();
    await _persistHistory();
  }

  Future<void> _persistHistory() async {
    final store = _store;
    if (store == null) return;
    try {
      await store.saveAll(_history);
    } catch (_) {}
  }

  Future<void> _geocodeActive() async {
    final journey = _active;
    final locator = _locator;
    if (journey == null || locator == null) return;
    final resolved = <JourneyStop>[];
    for (final stop in journey.stops) {
      if (stop.hasLocation || stop.kind == JourneyStopKind.roamForWork) {
        resolved.add(stop);
        continue;
      }
      final query = stop.placeQuery ?? stop.title;
      try {
        final location = await locator.locate(query);
        resolved
            .add(location == null ? stop : stop.copyWith(location: location));
      } catch (_) {
        resolved.add(stop);
      }
    }
    _active = journey.copyWith(stops: resolved);
    notifyListeners();
  }

  void _anchorRoamStops() {
    final journey = _active;
    if (journey == null) return;
    final zones = _zones?.call() ?? const <PredictedBusyZone>[];
    if (zones.isEmpty) return;

    final stops = [...journey.stops];
    var changed = false;
    for (var i = 0; i < stops.length; i++) {
      if (stops[i].kind != JourneyStopKind.roamForWork ||
          stops[i].hasLocation) {
        continue;
      }
      LatLng? from;
      LatLng? toward;
      for (var j = i - 1; j >= 0; j--) {
        if (stops[j].hasLocation) {
          from = stops[j].location;
          break;
        }
      }
      for (var j = i + 1; j < stops.length; j++) {
        if (stops[j].hasLocation) {
          toward = stops[j].location;
          break;
        }
      }
      final anchor = pickRoamAnchor(
        zones: zones,
        from: from,
        toward: toward,
      );
      if (anchor == null) continue;
      stops[i] = stops[i].copyWith(location: anchor);
      changed = true;
    }
    if (!changed) return;
    _active = journey.copyWith(stops: stops);
    notifyListeners();
  }

  Future<void> _routeActive({LatLng? from}) async {
    final journey = _active;
    if (journey == null) return;
    final located = journey.stops.where((s) => s.hasLocation).toList();
    final useGpsOrigin = from != null;

    if (located.isEmpty) {
      _routePoints = from != null ? [from] : const [];
      notifyListeners();
      return;
    }

    if (!useGpsOrigin && located.length < 2) {
      _routePoints = [for (final s in located) s.location!];
      notifyListeners();
      return;
    }

    final originPoint = from ?? located.first.location!;
    final destination = located.last;
    final mids = useGpsOrigin
        ? located.sublist(0, located.length - 1)
        : located.sublist(1, located.length - 1);
    final capped = mids.take(RoutesService.maxIntermediates).toList();
    final leftover = mids.skip(RoutesService.maxIntermediates).toList();

    _routePoints = [
      originPoint,
      ...capped.map((s) => s.location!),
      ...leftover.map((s) => s.location!),
      destination.location!,
    ];

    final router = _router;
    if (router == null) {
      notifyListeners();
      return;
    }

    try {
      final planned = await router.plan(
        origin: originPoint,
        destination: destination.location!,
        intermediates: [for (final s in capped) s.location!],
      );
      if (planned.polyline.isNotEmpty) {
        _routePoints = planned.polyline;
      }
      final order = planned.optimizedIntermediateIndex;
      if (order.length == capped.length &&
          order.toSet().length == order.length) {
        final reorderedMids = [
          for (final i in order)
            if (i >= 0 && i < capped.length) capped[i],
        ];
        if (reorderedMids.length == capped.length) {
          final locatedOrder = [
            if (!useGpsOrigin) located.first,
            ...reorderedMids,
            ...leftover,
            destination,
          ];
          var cursor = 0;
          final merged = [
            for (final stop in journey.stops)
              if (stop.hasLocation) locatedOrder[cursor++] else stop,
          ];
          if (cursor == locatedOrder.length) {
            _active = journey.copyWith(stops: merged);
          }
        }
      }
    } catch (_) {
      // Keep listed order and straight-line fallback already set.
    }
    notifyListeners();
  }

  void clear() {
    _draft = null;
    _active = null;
    _routePoints = const [];
    _trace = [];
    _lastSpoken = null;
    _lastReplanAt = null;
    _lastReplanHere = null;
    _skippedRest = false;
    _skippedFuel = false;
    _syncTicker();
    notifyListeners();
  }

  void removeStop(String id) {
    final target = _draft ?? _active;
    if (target == null) return;
    final next = target.copyWith(
      stops: target.stops.where((s) => s.id != id).toList(),
    );
    if (_draft != null) {
      _draft = next;
    } else {
      _active = next;
    }
    notifyListeners();
  }

  static String _formatClock(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final mer = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $mer';
  }
}
