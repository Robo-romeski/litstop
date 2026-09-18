import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:litstop/services/routes_service.dart';

void main() {
  final origin = const LatLng(37.74, -122.48);
  final dest = const LatLng(37.62, -122.38);

  test('plan posts traffic-aware computeRoutes and decodes the polyline', () async {
    final client = http_testing.MockClient((request) async {
      expect(request.url.toString(),
          'https://routes.googleapis.com/directions/v2:computeRoutes');
      expect(request.headers['X-Goog-Api-Key'], 'test-key');
      expect(request.headers['X-Goog-FieldMask'], contains('encodedPolyline'));
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['travelMode'], 'DRIVE');
      expect(body['routingPreference'], 'TRAFFIC_AWARE');
      expect(body['optimizeWaypointOrder'], isNull);
      return http.Response(
        jsonEncode({
          'routes': [
            {
              'polyline': {'encodedPolyline': r'_p~iF~ps|U_ulLnnqC_mqNvxq`@'},
            }
          ]
        }),
        200,
      );
    });

    final svc = RoutesService(apiKey: 'test-key', client: client);
    final planned = await svc.plan(origin: origin, destination: dest);
    expect(planned.polyline, isNotEmpty);
    expect(planned.polyline.first.latitude, closeTo(38.5, 0.001));
    expect(planned.optimizedIntermediateIndex, isEmpty);
  });

  test('plan sends optimizeWaypointOrder when intermediates exist', () async {
    final client = http_testing.MockClient((request) async {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['optimizeWaypointOrder'], true);
      expect(body['intermediates'], hasLength(1));
      return http.Response(
        jsonEncode({
          'routes': [
            {
              'polyline': {'encodedPolyline': r'_p~iF~ps|U'},
              'optimizedIntermediateWaypointIndex': [0],
            }
          ]
        }),
        200,
      );
    });

    final svc = RoutesService(apiKey: 'test-key', client: client);
    final planned = await svc.plan(
      origin: origin,
      destination: dest,
      intermediates: const [LatLng(37.7, -122.4)],
    );
    expect(planned.optimizedIntermediateIndex, [0]);
  });

  test('plan throws when the API fails so callers can fall back', () async {
    final client = http_testing.MockClient(
      (_) async => http.Response('nope', 403),
    );
    final svc = RoutesService(apiKey: 'test-key', client: client);
    expect(
      () => svc.plan(origin: origin, destination: dest),
      throwsA(isA<Exception>()),
    );
  });

  test('plan throws when no API key is configured', () {
    final svc = RoutesService(apiKey: '');
    expect(svc.isEnabled, isFalse);
    expect(
      () => svc.plan(origin: origin, destination: dest),
      throwsA(isA<StateError>()),
    );
  });
}
