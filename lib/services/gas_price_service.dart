import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/gas_station.dart';
import 'api_service.dart';

/// Service for fetching gas prices from Zyla API
class GasPriceService extends ApiService {
  /// API base URL for Zyla API
  static const String _baseUrl = 'https://api.zyla.com/gas/v1';

  /// Constructor
  GasPriceService({String? apiKey})
      : super(
          baseUrl: _baseUrl,
          apiKey: apiKey,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        );

  /// The state for which to fetch prices (e.g., "New York", "California")
  String _currentState = 'California';

  /// Set current state for API queries
  void setCurrentState(String state) {
    _currentState = state;
  }

  /// Get gas prices for the current state
  Future<List<GasStation>> getGasPrices() async {
    try {
      final response = await get(
        '/latest-prices',
        queryParameters: {
          'state': _currentState,
        },
      );

      if (response['status'] == 200 && response['success'] == true) {
        final stateCode = response['state'] as String;
        final date = response['date'] as String;
        final prices = response['prices'] as Map<String, dynamic>;

        // Create a generic gas station for the state
        final stateGasStation = GasStation.fromZylaApi({
          'id': 'state-${stateCode.toLowerCase()}',
          'name': '$stateCode State Average',
          'address': '$stateCode State Average',
          'state': stateCode,
          'date': date,
          'prices': prices,
        }, stateCode: stateCode);

        return [stateGasStation];
      } else {
        throw ApiException(
            'Failed to fetch gas prices: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to fetch gas prices: $e');
      }
    }
  }

  /// Get gas prices for multiple states
  Future<List<GasStation>> getMultiStateGasPrices(List<String> states) async {
    final allStations = <GasStation>[];

    for (final state in states) {
      try {
        final previousState = _currentState;
        _currentState = state;
        final stateStations = await getGasPrices();
        allStations.addAll(stateStations);
        _currentState = previousState;
      } catch (e) {
        // Continue with other states if one fails
        print('Failed to fetch prices for $state: $e');
      }
    }

    return allStations;
  }

  /// Get gas prices for metro areas within the current state
  Future<List<GasStation>> getMetroAreaGasPrices() async {
    try {
      final response = await get(
        '/metro-area-averages',
        queryParameters: {
          'state': _currentState,
        },
      );

      if (response['status'] == 200 && response['success'] == true) {
        final stateCode = response['state'] as String;
        final date = response['date'] as String;
        final metroData = response['prices'] as Map<String, dynamic>;

        final stations = <GasStation>[];

        // Process each metro area
        metroData.forEach((metroName, data) {
          final todayAvg = (data as Map<String, dynamic>)['today_average'];

          final metroStation = GasStation.fromZylaApi({
            'id': 'metro-${metroName.toLowerCase().replaceAll(' ', '-')}',
            'name': '$metroName Area',
            'address': '$metroName, $stateCode',
            'city': metroName,
            'state': stateCode,
            'date': date,
            'prices': todayAvg,
          }, stateCode: stateCode);

          stations.add(metroStation);
        });

        return stations;
      } else {
        throw ApiException(
            'Failed to fetch metro area gas prices: ${response['message'] ?? 'Unknown error'}');
      }
    } catch (e) {
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException('Failed to fetch metro area gas prices: $e');
      }
    }
  }

  /// Convert address to state code
  static String? addressToStateCode(String address) {
    // This is a simplified version; in a real app, you might use geocoding
    final parts = address.split(',');
    if (parts.length < 2) return null;

    final stateWithZip = parts[parts.length - 2].trim();
    final stateParts = stateWithZip.split(' ');

    if (stateParts.length > 0) {
      return stateParts[0].trim();
    }

    return null;
  }

  /// Get gas prices near a location
  Future<List<GasStation>> getNearbyGasStations(
    LatLng location, {
    double radius = 5.0, // in kilometers
  }) async {
    // For testing, return dummy data
    await Future.delayed(const Duration(seconds: 1));
    return _generateDummyGasStations(location, radius);
  }

  /// Get details for a specific gas station
  Future<GasStation?> getGasStationDetails(String stationId) async {
    // For testing, return a dummy gas station
    await Future.delayed(const Duration(seconds: 1));

    final random = math.Random();

    return GasStation(
      id: stationId,
      name: 'Sample Gas Station',
      brand: 'BrandX',
      location: LatLng(37.7749, -122.4194), // Sample location
      address: '123 Sample St, City, State',
      state: 'California',
      prices: {
        FuelType.regular: 3.49 + (random.nextDouble() * 0.5),
        FuelType.midGrade: 3.79 + (random.nextDouble() * 0.5),
        FuelType.premium: 3.99 + (random.nextDouble() * 0.5),
        FuelType.diesel: 3.89 + (random.nextDouble() * 0.5),
      },
      lastUpdated: DateTime.now().subtract(const Duration(hours: 6)),
    );
  }

  /// Generate dummy gas stations for testing
  List<GasStation> _generateDummyGasStations(LatLng center, double radiusKm) {
    final stations = <GasStation>[];
    final random = math.Random();
    final now = DateTime.now();

    // Generate 6-10 random gas stations
    final stationCount = 6 + random.nextInt(5);

    for (var i = 0; i < stationCount; i++) {
      // Random position within radius
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = random.nextDouble() * radiusKm;

      // Convert to lat/lng (simplified)
      final lat = center.latitude + (distance * math.sin(angle) / 111.0);
      final lng = center.longitude +
          (distance *
              math.cos(angle) /
              (111.0 * math.cos(center.latitude * math.pi / 180)));

      // Random gas prices
      final basePrice = 3.0 + (random.nextDouble() * 1.5);

      // Random brand
      final brands = [
        'Shell',
        'Mobil',
        'Chevron',
        'BP',
        'ARCO',
        'Exxon',
        'Texaco',
        'Valero'
      ];
      final brand = brands[random.nextInt(brands.length)];

      // Random update time (0-24 hours ago)
      final hoursAgo = random.nextInt(25);
      final updateTime = now.subtract(Duration(hours: hoursAgo));

      // Create station
      stations.add(
        GasStation(
          id: 'station_$i',
          name: '$brand Gas Station #$i',
          brand: brand,
          location: LatLng(lat, lng),
          address: '${100 + i} Main St, Test City',
          state: 'California',
          prices: {
            FuelType.regular: basePrice,
            FuelType.midGrade: basePrice + 0.30,
            FuelType.premium: basePrice + 0.60,
            if (random.nextBool()) FuelType.diesel: basePrice + 0.20,
          },
          lastUpdated: updateTime,
          distance: distance, // Store the distance in km
        ),
      );
    }

    return stations;
  }

  /// Dispose the API service
  void dispose() {
    super.dispose();
  }
}
