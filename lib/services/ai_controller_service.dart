import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/route_suggestions_provider.dart';
import '../providers/location_provider.dart';
import '../providers/poi_provider.dart';
import '../services/place_service.dart';
import '../models/point_of_interest.dart';
import 'safety_recorder_service.dart';

/// Simple intent-based AI controller to route ASK/DO commands to app features
class AIControllerService {
  final BuildContext context;

  AIControllerService({required this.context});

  Future<String> handleAsk(String prompt) async {
    final routeProvider = context.read<RouteSuggestionsProvider>();
    final locationProvider = context.read<LocationProvider>();

    final normalized = prompt.toLowerCase().trim();

    // Where is my route?
    if (normalized.contains('where is my route')) {
      final sel = routeProvider.selectedSuggestion;
      if (sel == null) {
        return 'No active route. You can ask me to create one.';
      }
      return 'Your current route "${sel.name}" starts at '
          '${sel.startPoint.latitude.toStringAsFixed(4)}, '
          '${sel.startPoint.longitude.toStringAsFixed(4)} and ends at '
          '${sel.endPoint.latitude.toStringAsFixed(4)}, '
          '${sel.endPoint.longitude.toStringAsFixed(4)}.';
    }

    // How long ... (estimate)
    if (normalized.startsWith('how long')) {
      final sel = routeProvider.selectedSuggestion;
      if (sel == null) return 'No active route to estimate duration.';
      return 'Estimated duration for "${sel.name}": '
          '${sel.totalDuration.toStringAsFixed(0)} minutes.';
    }

    // What's the best route ...
    if (normalized.contains("what's the best route") ||
        normalized.contains('what is the best route')) {
      final pos = locationProvider.currentPosition;
      if (pos == null) return 'I do not have your current location yet.';
      // Suggest using current algorithm
      final algo = context.read<RouteSuggestionsProvider>().algorithm;
      return 'Using the current strategy (${algo.name}), '
          'the highest-demand option is the selected suggestion (if any). '
          'You can also ask me to generate new suggestions.';
    }

    return 'I can help with: "Where is my route?", "How long ...?", '
        'and "What\'s the best route ...?"';
  }

  Future<String> handleDo(String prompt) async {
    final poiProvider = context.read<POIProvider>();
    final locationProvider = context.read<LocationProvider>();
    final normalized = prompt.toLowerCase().trim();

    // Safety recording
    if (normalized.contains('record mode') || normalized.contains('start recording')) {
      final safeWord = _extractSafeWord(normalized) ?? 'pineapple';
      SafetyRecorderService.instance.startRecording(safeWord: safeWord);
      return 'Safety recording started. Say "$safeWord" to stop.';
    }
    if (normalized.contains('stop recording')) {
      SafetyRecorderService.instance.stopRecording();
      return 'Safety recording stopped.';
    }

    // Turn off lyft/uber (placeholder)
    if (normalized.contains('turn off lyft') || normalized.contains('go offline lyft') || normalized.contains('go offline uber') || normalized.contains('turn off uber')) {
      return 'Provider status control is not yet connected. I can add this once provider APIs are wired.';
    }

    // Make a route from here to <destination> stopping for ice cream
    if (normalized.contains('make a route') || normalized.startsWith('route to') || normalized.startsWith('navigate to')) {
      final current = locationProvider.currentPosition;
      if (current == null) return 'I do not have your current location yet.';

      // Extract destination (simple heuristic after "to")
      final destName = _extractAfterWord(normalized, 'to') ?? '';
      if (destName.isEmpty) {
        return 'Please specify a destination after "to".';
      }

      final placeService = PlaceService();
      try {
        final suggestions = await placeService.getPlaceSuggestions(destName);
        if (suggestions.isEmpty) {
          return 'I could not find "$destName".';
        }
        final details = await placeService.getPlaceDetails(suggestions.first.placeId);
        final start = LatLng(current.latitude, current.longitude);
        final end = details.location;

        final route = await poiProvider.calculateRoute(start: start, end: end);
        if (route.isEmpty) {
          return 'I could not create a route to $destName.';
        }

        // Optional stop (ice cream)
        List<PointOfInterest> pois = [];
        if (normalized.contains('ice cream') || normalized.contains('icecream')) {
          pois = await poiProvider.findPOIsAlongRoute(
            start: start,
            end: end,
            poiTypes: const [POIType.cafe],
          );
        }

        // Notify user via UI
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          SnackBar(content: Text('Route ready to ${details.name}${pois.isNotEmpty ? ' with ${pois.length} stops' : ''}')),
        );

        return 'Planned a route to ${details.name}. '
            '${route.length} points${pois.isNotEmpty ? ', ${pois.length} nearby cafes' : ''}.';
      } catch (e) {
        return 'Failed to plan the route: $e';
      }
    }

    return 'I can do: create a route (e.g., "Make a route from here to <place> stopping for ice cream"), '
        'start/stop safety recording, and (soon) toggle provider status.';
  }

  String? _extractAfterWord(String text, String word) {
    final idx = text.indexOf(' $word ');
    if (idx == -1) return null;
    final after = text.substring(idx + word.length + 2).trim();
    if (after.isEmpty) return null;
    return after;
  }

  String? _extractSafeWord(String text) {
    // e.g., "record mode with safeword banana"
    final match = RegExp(r'safe\s*word\s*(\w+)').firstMatch(text);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    return null;
  }
}


