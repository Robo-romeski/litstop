import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:litstop/services/place_service.dart';

void main() {
  test('uses mock data when no API key is set', () async {
    final svc = PlaceService(apiKey: '');
    final suggestions = await svc.getPlaceSuggestions('SFO');
    expect(suggestions, isNotEmpty);
    expect(suggestions.first.placeId, 'mock_sfo_airport');
  });

  test('calls Places autocomplete with the key when mock is off', () async {
    final client = http_testing.MockClient((request) async {
      expect(request.url.host, 'maps.googleapis.com');
      expect(request.url.path, '/maps/api/place/autocomplete/json');
      expect(request.url.queryParameters['input'], 'SFO');
      expect(request.url.queryParameters['key'], 'live-key');
      return http.Response(
        jsonEncode({
          'status': 'OK',
          'predictions': [
            {'place_id': 'abc', 'description': 'SFO Airport'},
          ],
        }),
        200,
      );
    });

    final svc = PlaceService(
      apiKey: 'live-key',
      useMockData: false,
      client: client,
    );
    final suggestions = await svc.getPlaceSuggestions('SFO');
    expect(suggestions.single.placeId, 'abc');
  });
}
