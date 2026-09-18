import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/gas_station.dart';
import '../models/journey.dart';
import '../models/point_of_interest.dart';
import '../utils/heatmap_utils.dart';

class ConstraintCandidate {
  final String title;
  final LatLng location;

  const ConstraintCandidate({
    required this.title,
    required this.location,
  });
}

typedef ConstraintFinder = Future<ConstraintCandidate?> Function(
  JourneyStopKind kind,
  LatLng from,
);

typedef ConstraintSignal = bool Function();

ConstraintCandidate? pickConstraintPoi({
  required JourneyStopKind kind,
  required LatLng from,
  List<PointOfInterest> pois = const [],
  List<GasStation> stations = const [],
}) {
  final candidates = <ConstraintCandidate>[];
  if (kind == JourneyStopKind.fuel) {
    for (final station in stations) {
      candidates.add(
        ConstraintCandidate(title: station.name, location: station.location),
      );
    }
    for (final poi in pois) {
      if (poi.type == POIType.gasStation) {
        candidates.add(
          ConstraintCandidate(title: poi.name, location: poi.location),
        );
      }
    }
  } else if (kind == JourneyStopKind.rest) {
    const restTypes = {
      POIType.restArea,
      POIType.truckStop,
      POIType.hotel,
    };
    for (final poi in pois) {
      if (restTypes.contains(poi.type)) {
        candidates.add(
          ConstraintCandidate(title: poi.name, location: poi.location),
        );
      }
    }
  }
  if (candidates.isEmpty) return null;

  ConstraintCandidate? best;
  var bestDistance = double.infinity;
  for (final candidate in candidates) {
    final distance = HeatmapUtils.calculateDistance(from, candidate.location);
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}
