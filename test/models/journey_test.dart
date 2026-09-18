import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/journey.dart';

void main() {
  test('Journey json round-trips stops, windows, and GPS trace', () {
    final original = Journey(
      id: 'j1',
      createdAt: DateTime(2026, 9, 7, 7),
      status: JourneyStatus.completed,
      stops: [
        JourneyStop(
          id: 's1',
          title: 'School drop',
          kind: JourneyStopKind.hardStop,
          location: const LatLng(37.74, -122.48),
          placeQuery: 'school',
          windowStart: DateTime(2026, 9, 7, 8, 15),
        ),
        JourneyStop(
          id: 's2',
          title: 'Roam for work',
          kind: JourneyStopKind.roamForWork,
          windowEnd: DateTime(2026, 9, 7, 14),
        ),
      ],
      trace: const [LatLng(37.74, -122.48), LatLng(37.70, -122.41)],
    );

    final restored = Journey.fromJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.status, JourneyStatus.completed);
    expect(restored.createdAt, original.createdAt);
    expect(restored.stops, hasLength(2));
    expect(restored.stops.first.title, 'School drop');
    expect(restored.stops.first.location, original.stops.first.location);
    expect(restored.stops.last.kind, JourneyStopKind.roamForWork);
    expect(restored.stops.last.windowEnd, original.stops.last.windowEnd);
    expect(restored.trace, original.trace);
  });

  test('rest and fuel kinds round-trip', () {
    final original = Journey(
      id: 'j2',
      createdAt: DateTime(2026, 9, 8),
      status: JourneyStatus.active,
      stops: const [
        JourneyStop(
          id: 'r1',
          title: 'Lincoln Rest Area',
          kind: JourneyStopKind.rest,
          location: LatLng(37.76, -122.43),
        ),
        JourneyStop(
          id: 'f1',
          title: 'Shell',
          kind: JourneyStopKind.fuel,
          location: LatLng(37.75, -122.44),
        ),
      ],
    );
    final restored = Journey.fromJson(original.toJson());
    expect(restored.stops.first.kind, JourneyStopKind.rest);
    expect(restored.stops.last.kind, JourneyStopKind.fuel);
  });

  test('isMissedAt is true only after the window deadline', () {
    final stop = JourneyStop(
      id: 's1',
      title: 'School drop',
      kind: JourneyStopKind.hardStop,
      windowStart: DateTime(2026, 9, 7, 8, 15),
      windowEnd: DateTime(2026, 9, 7, 8, 15),
    );
    expect(stop.isMissedAt(DateTime(2026, 9, 7, 8, 15)), isFalse);
    expect(stop.isMissedAt(DateTime(2026, 9, 7, 8, 16)), isTrue);

    const open = JourneyStop(
      id: 's2',
      title: 'Cafe',
      kind: JourneyStopKind.hardStop,
    );
    expect(open.isMissedAt(DateTime(2026, 9, 7, 22)), isFalse);
  });
}
