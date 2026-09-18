import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'dart:convert';
import 'package:litstop/services/api_service.dart';

void main() {
  test('GET attaches Authorization and parses JSON', () async {
    final client = http_testing.MockClient((request) async {
      expect(request.url, Uri.parse('https://api.example.com/foo'));
      expect(request.headers['Authorization'], 'Bearer key');
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final svc = ApiService(
      baseUrl: 'https://api.example.com',
      apiKey: 'key',
      client: client,
    );

    final res = await svc.get('/foo');
    expect(res['ok'], true);
  });
}
