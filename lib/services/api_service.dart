import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Exception thrown when API request fails
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() =>
      'ApiException: $message ${statusCode != null ? '(Status code: $statusCode)' : ''}';
}

/// Base class for API services
class ApiService {
  /// Base URL for the API
  final String baseUrl;

  /// API key for authentication
  final String? apiKey;

  /// Default headers to include in requests
  final Map<String, String> defaultHeaders;

  /// HTTP client for making requests
  final http.Client _client;

  /// Default timeout duration
  final Duration timeout;

  /// Constructor
  ApiService({
    required this.baseUrl,
    this.apiKey,
    Map<String, String>? headers,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  })  : _client = client ?? http.Client(),
        defaultHeaders = headers ?? {'Content-Type': 'application/json'};

  /// Add authentication to request headers
  Map<String, String> _addAuthHeaders(Map<String, String>? headers) {
    final authHeaders = Map<String, String>.from(defaultHeaders);

    // Add custom headers if provided
    if (headers != null) {
      authHeaders.addAll(headers);
    }

    // Add API key if available
    if (apiKey != null) {
      authHeaders['Authorization'] = 'Bearer $apiKey';
    }

    return authHeaders;
  }

  /// Make a GET request
  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParameters
            ?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
      );

      final response = await _client
          .get(uri, headers: _addAuthHeaders(headers))
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out');
    } catch (e) {
      throw ApiException('Failed to complete request: $e');
    }
  }

  /// Make a POST request
  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParameters
            ?.map((key, value) => MapEntry(key, value?.toString() ?? '')),
      );

      final response = await _client
          .post(
            uri,
            headers: _addAuthHeaders(headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException('No internet connection');
    } on TimeoutException {
      throw ApiException('Request timed out');
    } catch (e) {
      throw ApiException('Failed to complete request: $e');
    }
  }

  /// Handle response and convert to JSON
  Map<String, dynamic> _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final jsonBody = jsonDecode(response.body);
        if (jsonBody is Map<String, dynamic>) {
          return jsonBody;
        } else {
          throw ApiException(
            'Invalid response format: expected JSON object',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        throw ApiException(
          'Failed to parse response: $e',
          statusCode: response.statusCode,
        );
      }
    } else {
      String? errorMessage;
      try {
        final jsonBody = jsonDecode(response.body);
        errorMessage =
            jsonBody['message'] ?? jsonBody['error'] ?? 'Unknown error';
      } catch (_) {
        errorMessage = response.body;
      }

      throw ApiException(
        'Request failed: $errorMessage',
        statusCode: response.statusCode,
      );
    }
  }

  /// Close the HTTP client
  void dispose() {
    _client.close();
  }
}
