import 'dart:convert';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../config/maps_config.dart';
import 'encoded_polyline.dart';

class PlannedRoute {
  final List<LatLng> polyline;
  final List<int> optimizedIntermediateIndex;

  const PlannedRoute({
    required this.polyline,
    this.optimizedIntermediateIndex = const [],
  });
}

abstract class RoutePlanner {
  Future<PlannedRoute> plan({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> intermediates = const [],
  });
}

class RoutesService implements RoutePlanner {
  static const maxIntermediates = 8;
  static const _endpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  final String apiKey;
  final http.Client _client;

  RoutesService({
    String? apiKey,
    http.Client? client,
  })  : apiKey = apiKey ?? MapsConfig.apiKey,
        _client = client ?? http.Client();

  bool get isEnabled => apiKey.isNotEmpty;

  @override
  Future<PlannedRoute> plan({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> intermediates = const [],
  }) async {
    if (!isEnabled) {
      throw StateError('GOOGLE_MAPS_API_KEY is not set');
    }

    final mids = intermediates.take(maxIntermediates).toList();
    final body = <String, dynamic>{
      'origin': _point(origin),
      'destination': _point(destination),
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
      'polylineQuality': 'OVERVIEW',
    };
    if (mids.isNotEmpty) {
      body['intermediates'] = mids.map(_point).toList();
      body['optimizeWaypointOrder'] = true;
    }

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': apiKey,
        'X-Goog-FieldMask':
            'routes.polyline.encodedPolyline,routes.optimizedIntermediateWaypointIndex',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Routes API ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw Exception('Routes API returned no routes');
    }
    final route = routes.first as Map<String, dynamic>;
    final encoded =
        (route['polyline'] as Map<String, dynamic>?)?['encodedPolyline']
            as String?;
    if (encoded == null || encoded.isEmpty) {
      throw Exception('Routes API returned no polyline');
    }

    final optimized = <int>[];
    final rawIndex = route['optimizedIntermediateWaypointIndex'];
    if (rawIndex is List) {
      for (final value in rawIndex) {
        if (value is num) optimized.add(value.toInt());
      }
    }

    return PlannedRoute(
      polyline: decodeEncodedPolyline(encoded),
      optimizedIntermediateIndex: optimized,
    );
  }

  Map<String, dynamic> _point(LatLng latLng) => {
        'location': {
          'latLng': {
            'latitude': latLng.latitude,
            'longitude': latLng.longitude,
          },
        },
      };
}
