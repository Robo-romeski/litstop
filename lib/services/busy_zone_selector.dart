import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/heatmap_utils.dart';

class PredictedActivityCopy {
  static const zoneTitle = 'Predicted busy';
  static const zoneSnippet = 'Likely more activity in the next 90 minutes';
  static const addZoneTitle = 'Add predicted busy zone';
  static const addZoneBody =
      'Mark this spot as likely busy? This is a prediction, not live platform pricing.';
  static const addZoneConfirm = 'Predicted busy zone added';
  static const roamSpeech = 'Roam for work toward predicted busy areas';
}

class PredictedBusyZone {
  final LatLng location;
  final double score;
  final String label;

  const PredictedBusyZone({
    required this.location,
    required this.score,
    required this.label,
  });
}

typedef BusyZoneSupplier = List<PredictedBusyZone> Function();

/// Combines heatmap pins, event locations, and time-of-day seeds.
List<PredictedBusyZone> buildPredictedBusyZones({
  required DateTime now,
  List<LatLng> hotspots = const [],
  List<LatLng> eventLocations = const [],
  LatLng? fallbackCenter,
}) {
  final peak = _isPeakHour(now.hour);
  final zones = <PredictedBusyZone>[
    for (final spot in hotspots)
      PredictedBusyZone(
        location: spot,
        score: peak ? 0.9 : 0.75,
        label: PredictedActivityCopy.zoneTitle,
      ),
    for (final spot in eventLocations)
      PredictedBusyZone(
        location: spot,
        score: 0.8,
        label: PredictedActivityCopy.zoneTitle,
      ),
  ];

  if (zones.isEmpty) {
    final center = fallbackCenter ?? const LatLng(37.7749, -122.4194);
    zones.addAll(_timeOfDaySeeds(now, center));
  }

  return zones;
}

/// Prefer a zone on the way from [from] to [toward]; otherwise highest score.
LatLng? pickRoamAnchor({
  required List<PredictedBusyZone> zones,
  LatLng? from,
  LatLng? toward,
}) {
  if (zones.isEmpty) return null;

  LatLng? target;
  if (from != null && toward != null) {
    target = LatLng(
      (from.latitude + toward.latitude) / 2,
      (from.longitude + toward.longitude) / 2,
    );
  } else {
    target = from ?? toward;
  }

  if (target == null) {
    zones.sort((a, b) => b.score.compareTo(a.score));
    return zones.first.location;
  }

  PredictedBusyZone? best;
  var bestRank = double.infinity;
  for (final zone in zones) {
    final distance = HeatmapUtils.calculateDistance(target, zone.location);
    final rank = distance - (zone.score * 0.5);
    if (rank < bestRank) {
      bestRank = rank;
      best = zone;
    }
  }
  return best?.location;
}

bool _isPeakHour(int hour) =>
    (hour >= 7 && hour < 10) || (hour >= 16 && hour < 20);

List<PredictedBusyZone> _timeOfDaySeeds(DateTime now, LatLng center) {
  final hour = now.hour;
  if (hour >= 6 && hour < 10) {
    return [
      PredictedBusyZone(
        location: LatLng(center.latitude + 0.02, center.longitude + 0.01),
        score: 0.85,
        label: PredictedActivityCopy.zoneTitle,
      ),
      PredictedBusyZone(
        location: LatLng(center.latitude + 0.01, center.longitude - 0.015),
        score: 0.7,
        label: PredictedActivityCopy.zoneTitle,
      ),
    ];
  }
  if (hour >= 16 && hour < 20) {
    return [
      PredictedBusyZone(
        location: LatLng(center.latitude - 0.03, center.longitude + 0.02),
        score: 0.85,
        label: PredictedActivityCopy.zoneTitle,
      ),
      PredictedBusyZone(
        location: LatLng(center.latitude + 0.01, center.longitude + 0.01),
        score: 0.7,
        label: PredictedActivityCopy.zoneTitle,
      ),
    ];
  }
  return [
    PredictedBusyZone(
      location: LatLng(center.latitude + 0.008, center.longitude),
      score: 0.65,
      label: PredictedActivityCopy.zoneTitle,
    ),
  ];
}
