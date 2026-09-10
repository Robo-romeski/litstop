import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'place_service.dart';

/// Resolves a stop title to a map coordinate.
abstract class StopLocator {
  Future<LatLng?> locate(String query);
}

/// Query variants to try against Places (full phrase, then aliases).
List<String> geocodeCandidates(String query) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final out = <String>[q];
  final lower = q.toLowerCase();
  if (lower.contains('sfo')) out.add('SFO');
  if (RegExp(r'\bschool\b').hasMatch(lower)) out.add('Lincoln High School');
  return out;
}

class PlaceStopLocator implements StopLocator {
  final PlaceService places;

  PlaceStopLocator({PlaceService? places}) : places = places ?? PlaceService();

  @override
  Future<LatLng?> locate(String query) async {
    for (final candidate in geocodeCandidates(query)) {
      final suggestions = await places.getPlaceSuggestions(candidate);
      if (suggestions.isEmpty) continue;
      final details = await places.getPlaceDetails(suggestions.first.placeId);
      return details.location;
    }
    return null;
  }
}
