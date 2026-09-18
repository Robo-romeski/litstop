import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/services/busy_zone_selector.dart';

void main() {
  test('copy never says surge', () {
    const strings = [
      PredictedActivityCopy.zoneTitle,
      PredictedActivityCopy.zoneSnippet,
      PredictedActivityCopy.addZoneTitle,
      PredictedActivityCopy.addZoneBody,
      PredictedActivityCopy.addZoneConfirm,
      PredictedActivityCopy.roamSpeech,
    ];
    for (final text in strings) {
      expect(text.toLowerCase(), isNot(contains('surge')));
    }
  });

  test('merges hotspot and event locations', () {
    final downtown = const LatLng(37.77, -122.42);
    final stadium = const LatLng(37.75, -122.38);
    final zones = buildPredictedBusyZones(
      now: DateTime(2026, 9, 7, 12),
      hotspots: [downtown],
      eventLocations: [stadium],
    );
    expect(zones.map((z) => z.location), containsAll([downtown, stadium]));
    expect(
      zones.every((z) => z.label == PredictedActivityCopy.zoneTitle),
      isTrue,
    );
  });

  test('seeds time-of-day zones when nothing else is known', () {
    final center = const LatLng(37.77, -122.42);
    final morning = buildPredictedBusyZones(
      now: DateTime(2026, 9, 7, 8),
      fallbackCenter: center,
    );
    final evening = buildPredictedBusyZones(
      now: DateTime(2026, 9, 7, 17),
      fallbackCenter: center,
    );
    expect(morning, isNotEmpty);
    expect(evening, isNotEmpty);
    expect(morning.first.location, isNot(evening.first.location));
  });

  test('roam anchor prefers the zone on the way between stops', () {
    final from = const LatLng(37.74, -122.48);
    final toward = const LatLng(37.62, -122.38);
    final onTheWay = LatLng(
      (from.latitude + toward.latitude) / 2,
      (from.longitude + toward.longitude) / 2,
    );
    final far = const LatLng(37.9, -122.2);
    final picked = pickRoamAnchor(
      zones: [
        PredictedBusyZone(location: far, score: 1.0, label: 'far'),
        PredictedBusyZone(location: onTheWay, score: 0.6, label: 'mid'),
      ],
      from: from,
      toward: toward,
    );
    expect(picked, onTheWay);
  });
}
