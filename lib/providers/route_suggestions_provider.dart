import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/heatmap_utils.dart';
import './heatmap_provider.dart';
import './location_provider.dart';

/// Represents a suggested route segment with metadata
class RouteSegment {
  final List<LatLng> points;
  final double demandScore; // 0.0 to 1.0, indicating predicted demand
  final double distance; // in kilometers
  final double estimatedDuration; // in minutes
  final String description;

  const RouteSegment({
    required this.points,
    required this.demandScore,
    required this.distance,
    required this.estimatedDuration,
    required this.description,
  });
}

/// Represents a complete route suggestion
class RouteSuggestion {
  final String id;
  final String name;
  final List<RouteSegment> segments;
  final double totalDistance;
  final double totalDuration;
  final double overallDemandScore;
  final LatLng startPoint;
  final LatLng endPoint;
  final DateTime generatedAt;

  RouteSuggestion({
    required this.id,
    required this.name,
    required this.segments,
    required this.startPoint,
    required this.endPoint,
    required this.generatedAt,
  })  : totalDistance =
            segments.fold(0.0, (sum, segment) => sum + segment.distance),
        totalDuration = segments.fold(
            0.0, (sum, segment) => sum + segment.estimatedDuration),
        overallDemandScore = segments.isEmpty
            ? 0.0
            : segments.fold(0.0, (sum, segment) => sum + segment.demandScore) /
                segments.length;
}

/// Algorithm strategy for route generation
enum RouteAlgorithm {
  // Greedy algorithm that chooses highest demand areas first
  demandGreedy,
  // Balanced approach considering both demand and distance
  balanced,
  // Optimize for shorter total distance
  distanceOptimized,
  // Random exploration of areas (useful for new drivers learning the area)
  explorationMode,
}

/// Provider that generates and manages smart route suggestions
class RouteSuggestionsProvider with ChangeNotifier {
  // Route suggestions
  List<RouteSuggestion> _suggestions = [];
  RouteSuggestion? _selectedSuggestion;
  bool _isSuggestionsVisible = true;
  bool _isLoading = false;
  String? _error;
  RouteAlgorithm _algorithm = RouteAlgorithm.balanced;

  // Reference to other providers
  final HeatmapProvider _heatmapProvider;
  final LocationProvider _locationProvider;

  // Route visualization on map
  Set<Polyline> _routePolylines = {};
  Set<Marker> _routeMarkers = {};

  // Voice guidance
  bool _isVoiceGuidanceEnabled = false;
  String? _lastAnnouncement;
  Timer? _refreshTimer;

  // Getters
  List<RouteSuggestion> get suggestions => _suggestions;
  RouteSuggestion? get selectedSuggestion => _selectedSuggestion;
  bool get isSuggestionsVisible => _isSuggestionsVisible;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RouteAlgorithm get algorithm => _algorithm;
  Set<Polyline> get routePolylines =>
      _isSuggestionsVisible ? _routePolylines : {};
  Set<Marker> get routeMarkers => _isSuggestionsVisible ? _routeMarkers : {};
  bool get isVoiceGuidanceEnabled => _isVoiceGuidanceEnabled;
  String? get lastAnnouncement => _lastAnnouncement;

  // Constructor
  RouteSuggestionsProvider({
    required HeatmapProvider heatmapProvider,
    required LocationProvider locationProvider,
  })  : _heatmapProvider = heatmapProvider,
        _locationProvider = locationProvider {
    // Refresh suggestions every 5 minutes
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        if (_locationProvider.currentPosition != null) {
          generateSuggestions();
        }
      },
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Toggle route suggestions visibility
  void toggleSuggestionsVisibility() {
    _isSuggestionsVisible = !_isSuggestionsVisible;
    notifyListeners();
  }

  /// Set the algorithm to use for route generation
  void setAlgorithm(RouteAlgorithm algorithm) {
    _algorithm = algorithm;
    notifyListeners();

    // Regenerate suggestions with new algorithm
    if (_locationProvider.currentPosition != null) {
      generateSuggestions();
    }
  }

  /// Toggle voice guidance
  void toggleVoiceGuidance() {
    _isVoiceGuidanceEnabled = !_isVoiceGuidanceEnabled;

    if (_isVoiceGuidanceEnabled) {
      _lastAnnouncement = "Voice guidance enabled";
    } else {
      _lastAnnouncement = "Voice guidance disabled";
    }

    notifyListeners();
  }

  /// Generate route suggestions based on current location and demand data
  Future<void> generateSuggestions() async {
    if (_isLoading) return;

    final currentPosition = _locationProvider.currentPosition;
    if (currentPosition == null) {
      _error = "Cannot generate suggestions: Current location unknown";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Convert current position to LatLng
      final currentLatLng = LatLng(
        currentPosition.latitude,
        currentPosition.longitude,
      );

      // Get hotspots from heatmap provider
      final hotspots = _heatmapProvider.hotspots;

      // Generate suggestions based on algorithm
      final suggestions = await _generateRouteSuggestions(
        currentLatLng: currentLatLng,
        hotspots: hotspots,
        algorithm: _algorithm,
      );

      _suggestions = suggestions;

      // If we have suggestions, select the first one by default
      if (_suggestions.isNotEmpty) {
        selectSuggestion(_suggestions.first.id);
      } else {
        _selectedSuggestion = null;
        _routePolylines = {};
        _routeMarkers = {};
      }

      if (_isVoiceGuidanceEnabled) {
        _lastAnnouncement = "New route suggestions available";
      }
    } catch (e) {
      _error = "Failed to generate suggestions: ${e.toString()}";
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select a suggestion by ID and visualize it on the map
  void selectSuggestion(String suggestionId) {
    final suggestion = _suggestions.firstWhere(
      (s) => s.id == suggestionId,
      orElse: () => throw Exception("Suggestion not found: $suggestionId"),
    );

    _selectedSuggestion = suggestion;
    _visualizeRoute(suggestion);

    if (_isVoiceGuidanceEnabled) {
      _lastAnnouncement = "Selected route: ${suggestion.name}";
    }

    notifyListeners();
  }

  /// Visualize a route on the map with polylines and markers
  void _visualizeRoute(RouteSuggestion suggestion) {
    // Create polylines for each segment
    final polylines = <Polyline>{};
    final markers = <Marker>{};

    // Add start marker
    markers.add(
      Marker(
        markerId: MarkerId('route_start_${suggestion.id}'),
        position: suggestion.startPoint,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: 'Start',
          snippet: 'Starting point',
        ),
      ),
    );

    // Add end marker
    markers.add(
      Marker(
        markerId: MarkerId('route_end_${suggestion.id}'),
        position: suggestion.endPoint,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'End',
          snippet: 'Ending point',
        ),
      ),
    );

    // Add segment polylines with colors based on demand
    for (int i = 0; i < suggestion.segments.length; i++) {
      final segment = suggestion.segments[i];

      // Color based on demand score (green -> yellow -> orange -> red)
      final color = _getColorForDemandScore(segment.demandScore);

      polylines.add(
        Polyline(
          polylineId: PolylineId('route_segment_${suggestion.id}_$i'),
          points: segment.points,
          color: color,
          width: 5,
          patterns: [PatternItem.dash(10), PatternItem.gap(5)],
        ),
      );

      // Add segment info marker at midpoint
      if (segment.points.length > 1) {
        final midPointIndex = segment.points.length ~/ 2;
        markers.add(
          Marker(
            markerId: MarkerId('segment_info_$i'),
            position: segment.points[midPointIndex],
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueViolet),
            infoWindow: InfoWindow(
              title: 'Segment ${i + 1}',
              snippet:
                  '${segment.description} (${segment.distance.toStringAsFixed(1)}km)',
            ),
          ),
        );
      }
    }

    _routePolylines = polylines;
    _routeMarkers = markers;
  }

  /// Get color for demand score (green -> yellow -> orange -> red)
  Color _getColorForDemandScore(double score) {
    if (score < 0.25) {
      return Colors.green;
    } else if (score < 0.5) {
      return Colors.yellow;
    } else if (score < 0.75) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Generate route suggestions based on current location, hotspots, and algorithm
  Future<List<RouteSuggestion>> _generateRouteSuggestions({
    required LatLng currentLatLng,
    required List<LatLng> hotspots,
    required RouteAlgorithm algorithm,
  }) async {
    // For demo purposes we'll generate 3 route suggestions
    // In a real app, this would involve more complex routing algorithms
    final suggestions = <RouteSuggestion>[];
    final random = Random();

    if (hotspots.isEmpty) {
      // If no hotspots, generate random explorations
      return _generateExplorationRoutes(currentLatLng);
    }

    // Choose hotspots based on algorithm
    List<LatLng> prioritizedHotspots = [];

    switch (algorithm) {
      case RouteAlgorithm.demandGreedy:
        // In a real app, hotspots would have demand scores
        // For now, just use the existing list assuming they're already sorted
        prioritizedHotspots = List.from(hotspots);
        break;

      case RouteAlgorithm.balanced:
        // Sort hotspots by a balance of distance and assumed demand
        final sortedBalancedHotspots = hotspots.map((hotspot) {
          final distance =
              HeatmapUtils.calculateDistance(currentLatLng, hotspot);
          // Simulate demand score (would come from API in real app)
          final demand = 1.0 - (distance / 10).clamp(0.0, 1.0);
          // Balance score: higher is better
          final balanceScore = demand / (sqrt(distance) + 0.1);
          return {
            'hotspot': hotspot,
            'distance': distance,
            'balanceScore': balanceScore,
          };
        }).toList()
          ..sort((a, b) => (b['balanceScore'] as double)
              .compareTo(a['balanceScore'] as double));

        prioritizedHotspots = sortedBalancedHotspots
            .map((item) => item['hotspot'] as LatLng)
            .toList();
        break;

      case RouteAlgorithm.distanceOptimized:
        // Sort hotspots by distance (closest first)
        final sortedDistanceHotspots = hotspots.map((hotspot) {
          final distance =
              HeatmapUtils.calculateDistance(currentLatLng, hotspot);
          return {
            'hotspot': hotspot,
            'distance': distance,
          };
        }).toList()
          ..sort((a, b) =>
              (a['distance'] as double).compareTo(b['distance'] as double));

        prioritizedHotspots = sortedDistanceHotspots
            .map((item) => item['hotspot'] as LatLng)
            .toList();
        break;

      case RouteAlgorithm.explorationMode:
        // Random order with more diversity
        prioritizedHotspots = List.from(hotspots)..shuffle(random);
        break;
    }

    // Generate 3 route suggestions
    for (int i = 0; i < 3 && i < prioritizedHotspots.length; i++) {
      // For each suggestion, pick a different subset of hotspots
      final targetHotspots = <LatLng>[];

      // Maximum 5 hotspots per route
      final maxHotspots = min(5, prioritizedHotspots.length);

      // Pick a different starting point in the list for each suggestion
      final startIndex = i * 2 % prioritizedHotspots.length;

      for (int j = 0; j < maxHotspots; j++) {
        final index = (startIndex + j) % prioritizedHotspots.length;
        targetHotspots.add(prioritizedHotspots[index]);
      }

      // Sort by optimized route (simple version - in real app use TSP algorithm)
      final sortedHotspots =
          _sortPointsByNearestNeighbor(currentLatLng, targetHotspots);

      // Generate segments between points
      final segments = <RouteSegment>[];
      LatLng previousPoint = currentLatLng;

      for (int j = 0; j < sortedHotspots.length; j++) {
        final targetPoint = sortedHotspots[j];
        // Create route segment between points (in real app, use actual routing API)
        final segmentPoints =
            _generateRouteBetweenPoints(previousPoint, targetPoint);

        // Calculate segment properties
        final distance =
            HeatmapUtils.calculateDistance(previousPoint, targetPoint);
        final demandScore =
            0.5 + (random.nextDouble() * 0.5); // Simulated demand
        final duration = distance * 2 +
            (random.nextDouble() * 5); // Rough estimate: 2 min per km + random

        segments.add(RouteSegment(
          points: segmentPoints,
          demandScore: demandScore,
          distance: distance,
          estimatedDuration: duration,
          description: 'Drive through high demand area',
        ));

        previousPoint = targetPoint;
      }

      // Add segment back to start for a loop (optional)
      if (sortedHotspots.isNotEmpty &&
          algorithm != RouteAlgorithm.distanceOptimized) {
        final lastPoint = sortedHotspots.last;
        final segmentPoints =
            _generateRouteBetweenPoints(lastPoint, currentLatLng);

        final distance =
            HeatmapUtils.calculateDistance(lastPoint, currentLatLng);
        final demandScore =
            0.2 + (random.nextDouble() * 0.3); // Lower demand for return
        final duration = distance * 2; // Rough estimate: 2 min per km

        segments.add(RouteSegment(
          points: segmentPoints,
          demandScore: demandScore,
          distance: distance,
          estimatedDuration: duration,
          description: 'Return to starting point',
        ));
      }

      // Create full route suggestion
      final routeName = _generateRouteName(algorithm, i);
      suggestions.add(RouteSuggestion(
        id: 'route_${algorithm.name}_$i',
        name: routeName,
        segments: segments,
        startPoint: currentLatLng,
        endPoint: segments.isEmpty ? currentLatLng : segments.last.points.last,
        generatedAt: DateTime.now(),
      ));
    }

    return suggestions;
  }

  /// Generate exploration routes when no hotspots are available
  List<RouteSuggestion> _generateExplorationRoutes(LatLng currentLatLng) {
    final suggestions = <RouteSuggestion>[];
    final random = Random();

    // Generate 3 random exploration routes in different directions
    final directions = [
      'North',
      'East',
      'South',
      'West',
      'Northeast',
      'Southeast',
      'Southwest',
      'Northwest'
    ];
    directions.shuffle();

    for (int i = 0; i < 3; i++) {
      final direction = directions[i % directions.length];

      // Generate 3-5 random points in roughly the given direction
      final points = <LatLng>[];
      LatLng previousPoint = currentLatLng;

      // Direction modifier
      double baseBearing;
      switch (direction) {
        case 'North':
          baseBearing = 0;
          break;
        case 'East':
          baseBearing = 90;
          break;
        case 'South':
          baseBearing = 180;
          break;
        case 'West':
          baseBearing = 270;
          break;
        case 'Northeast':
          baseBearing = 45;
          break;
        case 'Southeast':
          baseBearing = 135;
          break;
        case 'Southwest':
          baseBearing = 225;
          break;
        case 'Northwest':
          baseBearing = 315;
          break;
        default:
          baseBearing = random.nextDouble() * 360;
      }

      final segments = <RouteSegment>[];
      final numSegments = 2 + random.nextInt(3); // 2-4 segments

      for (int j = 0; j < numSegments; j++) {
        // Vary bearing around the base direction
        final bearing = baseBearing + (random.nextDouble() * 60 - 30);
        final distance = 1 + random.nextDouble() * 3; // 1-4 km

        // Calculate new point based on bearing and distance
        final newPoint =
            _calculateDestination(previousPoint, bearing, distance);
        final routePoints =
            _generateRouteBetweenPoints(previousPoint, newPoint);

        // Simulate demand score for exploration route (lower than hotspot routes)
        final demandScore = 0.2 + (random.nextDouble() * 0.4);
        final duration = distance * 2 + (random.nextDouble() * 3);

        segments.add(RouteSegment(
          points: routePoints,
          demandScore: demandScore,
          distance: distance,
          estimatedDuration: duration,
          description: 'Explore $direction area',
        ));

        previousPoint = newPoint;
      }

      // Create full route suggestion
      suggestions.add(RouteSuggestion(
        id: 'exploration_${direction.toLowerCase()}_$i',
        name: 'Exploration: $direction',
        segments: segments,
        startPoint: currentLatLng,
        endPoint: segments.isEmpty ? currentLatLng : segments.last.points.last,
        generatedAt: DateTime.now(),
      ));
    }

    return suggestions;
  }

  /// Calculate destination point given distance and bearing from start point
  LatLng _calculateDestination(
      LatLng start, double bearing, double distanceKm) {
    const R = 6371; // Earth radius in km
    final d = distanceKm / R;
    final bearingRad = bearing * pi / 180;

    final lat1 = start.latitude * pi / 180;
    final lon1 = start.longitude * pi / 180;

    final lat2 =
        asin(sin(lat1) * cos(d) + cos(lat1) * sin(d) * cos(bearingRad));
    final lon2 = lon1 +
        atan2(
          sin(bearingRad) * sin(d) * cos(lat1),
          cos(d) - sin(lat1) * sin(lat2),
        );

    return LatLng(
      lat2 * 180 / pi,
      lon2 * 180 / pi,
    );
  }

  /// Generate a descriptive route name based on algorithm and index
  String _generateRouteName(RouteAlgorithm algorithm, int index) {
    final titles = <RouteAlgorithm, List<String>>{
      RouteAlgorithm.demandGreedy: [
        'High Demand Route',
        'Peak Earnings Path',
        'Prime Time Circuit'
      ],
      RouteAlgorithm.balanced: [
        'Balanced Route',
        'Efficient Circuit',
        'Smart Path'
      ],
      RouteAlgorithm.distanceOptimized: [
        'Shortest Path',
        'Fuel Efficient Route',
        'Quick Circuit'
      ],
      RouteAlgorithm.explorationMode: [
        'Discovery Route',
        'Exploration Path',
        'New Territory'
      ],
    };

    final options = titles[algorithm] ?? ['Route ${index + 1}'];
    return index < options.length ? options[index] : options[0];
  }

  /// Sort points using Nearest Neighbor algorithm (for simple route optimization)
  List<LatLng> _sortPointsByNearestNeighbor(LatLng start, List<LatLng> points) {
    if (points.isEmpty) return [];

    final result = <LatLng>[];
    final unvisited = List<LatLng>.from(points);
    LatLng current = start;

    while (unvisited.isNotEmpty) {
      // Find nearest unvisited point
      unvisited.sort((a, b) {
        final distA = HeatmapUtils.calculateDistance(current, a);
        final distB = HeatmapUtils.calculateDistance(current, b);
        return distA.compareTo(distB);
      });

      // Add nearest point to result
      final nearest = unvisited.removeAt(0);
      result.add(nearest);
      current = nearest;
    }

    return result;
  }

  /// Generate a simulated route between two points
  /// In a real app, this would use a routing API (Google Directions, MapBox, etc.)
  List<LatLng> _generateRouteBetweenPoints(LatLng start, LatLng end) {
    // For demo, create a slightly curved path between points
    final result = <LatLng>[];
    result.add(start);

    // Calculate midpoint and add some randomness
    final midLat = (start.latitude + end.latitude) / 2;
    final midLng = (start.longitude + end.longitude) / 2;

    // Add a slight curve by offsetting the midpoint
    final random = Random();
    final latOffset =
        (random.nextDouble() - 0.5) * 0.005; // small random offset
    final lngOffset = (random.nextDouble() - 0.5) * 0.005;

    final midpoint = LatLng(midLat + latOffset, midLng + lngOffset);

    // Add some intermediate points to make a smoother curve
    final quarter1 = LatLng(
      (start.latitude * 0.75) + (midpoint.latitude * 0.25),
      (start.longitude * 0.75) + (midpoint.longitude * 0.25),
    );

    final quarter3 = LatLng(
      (midpoint.latitude * 0.75) + (end.latitude * 0.25),
      (midpoint.longitude * 0.75) + (end.longitude * 0.25),
    );

    result.add(quarter1);
    result.add(midpoint);
    result.add(quarter3);
    result.add(end);

    return result;
  }
}
