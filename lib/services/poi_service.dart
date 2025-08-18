import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/point_of_interest.dart';
import '../models/poi_filter.dart';
import 'api_service.dart';

/// Service for interacting with POI APIs
class POIService extends ApiService {
  /// Base URL for the OpenRouteService API
  final String _baseUrl = 'https://api.openrouteservice.org/v2';

  /// Constructor with API key
  POIService({String? apiKey})
      : super(
          baseUrl: 'https://api.openrouteservice.org/v2',
          apiKey: apiKey,
          headers: {
            'Accept': 'application/json, application/geo+json',
            'Content-Type': 'application/json',
          },
        );

  /// Fetch nearby POIs based on location and type
  Future<List<PointOfInterest>> fetchNearbyPOIs({
    required LatLng location,
    required List<POIType> poiTypes,
    int radius = 5000,
  }) async {
    // For testing, return dummy data
    await Future.delayed(const Duration(seconds: 1));
    return _generateDummyPOIs(location, poiTypes, radius);
  }

  /// Search POIs by query
  Future<List<PointOfInterest>> searchPOIs({
    required String query,
    required LatLng location,
    int radius = 5000,
  }) async {
    // For testing, return dummy data
    await Future.delayed(const Duration(seconds: 1));
    final types = <POIType>[
      POIType.cafe,
      POIType.restaurant,
      POIType.gasStation,
      POIType.restArea,
    ];
    return _generateDummyPOIs(location, types, radius, namePrefix: query);
  }

  /// Calculate a route between two points
  Future<List<LatLng>> calculateRoute({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
  }) async {
    // For testing, generate a simple route between points
    await Future.delayed(const Duration(seconds: 1));
    return _generateMockRoute(start, end);
  }

  /// Get POIs along a route
  Future<List<PointOfInterest>> getPOIsAlongRoute({
    required List<LatLng> routePoints,
    required List<POIType> poiTypes,
    int bufferDistance = 1000,
  }) async {
    // For testing, generate some POIs along the route
    await Future.delayed(const Duration(seconds: 1));

    // Get the midpoint of the route as a reference
    final midIdx = routePoints.length ~/ 2;
    final midPoint = routePoints[midIdx];

    return _generateDummyPOIs(midPoint, poiTypes, bufferDistance * 3);
  }

  /// Generate dummy POIs for testing
  List<PointOfInterest> _generateDummyPOIs(
    LatLng center,
    List<POIType> types,
    int radius, {
    String namePrefix = '',
  }) {
    final random = DateTime.now().millisecondsSinceEpoch;
    final pois = <PointOfInterest>[];

    // Generate 2-3 POIs for each type
    for (final type in types) {
      final count = 2 + (random % 2); // 2 or 3 POIs per type

      for (var i = 0; i < count; i++) {
        // Create random offset within the radius
        final latOffset = (random % (radius * 2) - radius) / 111111.0;
        final lngOffset = (random % (radius * 2) - radius) /
            (111111.0 * math.cos(center.latitude * 0.018));

        final location = LatLng(
          center.latitude + latOffset,
          center.longitude + lngOffset,
        );

        final name = namePrefix.isNotEmpty
            ? '$namePrefix ${_getNameForType(type)} #$i'
            : '${_getNameForType(type)} #$i';

        pois.add(PointOfInterest(
          id: 'poi_${type.toString()}_$i',
          name: name,
          type: type,
          location: location,
          address: '123 Test St, Testville',
          distance: _calculateDistance(center, location),
          categories: [_getCategoryForType(type)],
          amenities: _getAmenitiesForType(type),
        ));
      }
    }

    return pois;
  }

  /// Calculate distance between two points in meters
  double _calculateDistance(LatLng point1, LatLng point2) {
    // Simplified distance calculation (not accounting for Earth's curvature)
    const earthRadius = 6371000.0; // Earth radius in meters
    final lat1 = point1.latitude * (math.pi / 180);
    final lat2 = point2.latitude * (math.pi / 180);
    final lon1 = point1.longitude * (math.pi / 180);
    final lon2 = point2.longitude * (math.pi / 180);

    final dLat = lat2 - lat1;
    final dLon = lon2 - lon1;

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Get a placeholder name for a POI type
  String _getNameForType(POIType type) {
    switch (type) {
      case POIType.gasStation:
        return 'Gas Station';
      case POIType.restArea:
        return 'Rest Area';
      case POIType.cafe:
        return 'Cafe';
      case POIType.restaurant:
        return 'Restaurant';
      case POIType.convenienceStore:
        return 'Convenience Store';
      case POIType.truckStop:
        return 'Truck Stop';
      case POIType.evCharging:
        return 'EV Charging';
      case POIType.hotel:
        return 'Hotel';
      case POIType.parking:
        return 'Parking';
      case POIType.other:
        return 'Location';
    }
  }

  /// Get a category for a POI type
  String _getCategoryForType(POIType type) {
    switch (type) {
      case POIType.gasStation:
        return 'fuel';
      case POIType.restArea:
        return 'rest';
      case POIType.cafe:
        return 'food';
      case POIType.restaurant:
        return 'food';
      case POIType.convenienceStore:
        return 'shop';
      case POIType.truckStop:
        return 'transport';
      case POIType.evCharging:
        return 'charging';
      case POIType.hotel:
        return 'accommodation';
      case POIType.parking:
        return 'parking';
      case POIType.other:
        return 'other';
    }
  }

  /// Get amenities for a POI type
  List<String> _getAmenitiesForType(POIType type) {
    switch (type) {
      case POIType.gasStation:
        return ['fuel', 'air_pump', 'convenience_store'];
      case POIType.restArea:
        return ['restrooms', 'picnic_tables', 'vending_machines'];
      case POIType.cafe:
        return ['wifi', 'restrooms', 'power_outlets'];
      case POIType.restaurant:
        return ['restrooms', 'takeout', 'credit_cards'];
      case POIType.convenienceStore:
        return ['atm', 'food', 'drinks'];
      case POIType.truckStop:
        return ['showers', 'restaurant', 'fuel'];
      case POIType.evCharging:
        return ['fast_charging', 'parking', 'restrooms'];
      case POIType.hotel:
        return ['wifi', 'parking', 'breakfast'];
      case POIType.parking:
        return ['paid', 'security', 'lighting'];
      case POIType.other:
        return ['wifi'];
    }
  }

  /// Generate a mock route between two points
  List<LatLng> _generateMockRoute(LatLng start, LatLng end) {
    final route = <LatLng>[];

    // Add starting point
    route.add(start);

    // Calculate how many points to generate (distance-based)
    final distance = _calculateDistance(start, end);
    final pointCount =
        (distance / 1000).clamp(5, 20).toInt(); // 1 point per km, min 5, max 20

    // Generate intermediate points
    for (var i = 1; i < pointCount; i++) {
      final fraction = i / pointCount;

      // Linear interpolation with some randomness
      final random = DateTime.now().millisecondsSinceEpoch % 1000 - 500;
      final randomOffset = random / 50000.0; // Small random offset

      final lat = start.latitude +
          (end.latitude - start.latitude) * fraction +
          randomOffset;
      final lng = start.longitude +
          (end.longitude - start.longitude) * fraction +
          randomOffset;

      route.add(LatLng(lat, lng));
    }

    // Add ending point
    route.add(end);

    return route;
  }

  /// Find rest areas along a route
  Future<List<PointOfInterest>> findRestAreasAlongRoute({
    required LatLng start,
    required LatLng end,
    int bufferDistance = 1000, // 1km from route
  }) async {
    // First calculate the route
    final route = await calculateRoute(start: start, end: end);

    // Then find rest areas along that route
    return getPOIsAlongRoute(
      routePoints: route,
      poiTypes: [POIType.restArea, POIType.truckStop],
      bufferDistance: bufferDistance,
    );
  }

  /// Find gas stations along a route
  Future<List<PointOfInterest>> findGasStationsAlongRoute({
    required LatLng start,
    required LatLng end,
    int bufferDistance = 1000, // 1km from route
  }) async {
    // First calculate the route
    final route = await calculateRoute(start: start, end: end);

    // Then find gas stations along that route
    return getPOIsAlongRoute(
      routePoints: route,
      poiTypes: [POIType.gasStation],
      bufferDistance: bufferDistance,
    );
  }

  /// Find food options (restaurants/cafes) along a route
  Future<List<PointOfInterest>> findFoodAlongRoute({
    required LatLng start,
    required LatLng end,
    int bufferDistance = 1000, // 1km from route
  }) async {
    // First calculate the route
    final route = await calculateRoute(start: start, end: end);

    // Then find food options along that route
    return getPOIsAlongRoute(
      routePoints: route,
      poiTypes: [POIType.restaurant, POIType.cafe],
      bufferDistance: bufferDistance,
    );
  }

  /// Apply a filter to a list of POIs
  List<PointOfInterest> applyFilter(
      List<PointOfInterest> pois, POIFilter filter) {
    return filter.apply(pois);
  }

  /// Dispose the API service
  void dispose() {
    super.dispose();
  }
}
