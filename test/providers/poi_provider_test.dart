import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/gas_station.dart';
import 'package:litstop/models/point_of_interest.dart';
import 'package:litstop/models/poi_filter.dart';
import 'package:litstop/providers/poi_provider.dart';
import 'package:litstop/services/gas_price_service.dart';
import 'package:litstop/services/poi_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'poi_provider_test.mocks.dart';

// Generate mocks
@GenerateMocks([POIService, GasPriceService])
void main() {
  group('POIProvider Tests', () {
    late POIProvider poiProvider;
    late MockPOIService mockPOIService;
    late MockGasPriceService mockGasPriceService;

    setUp(() {
      mockPOIService = MockPOIService();
      mockGasPriceService = MockGasPriceService();

      // Create provider with mock services
      poiProvider = POIProvider();

      // Note: In a real implementation, we would need dependency injection
      // to properly inject the mock services. For now, we'll test the
      // state management and filtering logic.
    });

    group('Initial state', () {
      test('starts with empty POI list', () {
        expect(poiProvider.pois, isEmpty);
        expect(poiProvider.filteredPOIs, isEmpty);
      });

      test('starts with empty gas station list', () {
        expect(poiProvider.gasStations, isEmpty);
        expect(poiProvider.filteredGasStations, isEmpty);
      });

      test('starts with default filter', () {
        expect(poiProvider.activeFilter.includedTypes, isNull);
        expect(poiProvider.activeFilter.maxDistance, isNull);
        expect(poiProvider.activeFilter.minRating, isNull);
      });

      test('starts with default search radius', () {
        expect(poiProvider.searchRadius, equals(5000)); // 5km in meters
      });

      test('starts with no loading state', () {
        expect(poiProvider.isLoading, isFalse);
      });

      test('starts with no error message', () {
        expect(poiProvider.errorMessage, isNull);
      });

      test('starts with empty marker sets', () {
        expect(poiProvider.poiMarkers, isEmpty);
        expect(poiProvider.gasStationMarkers, isEmpty);
        expect(poiProvider.allMarkers, isEmpty);
      });
    });

    group('Filter management', () {
      test('updates active filter and notifies listeners', () {
        var notificationCount = 0;
        poiProvider.addListener(() => notificationCount++);

        final newFilter = POIFilter(
          includedTypes: [POIType.restaurant],
          maxDistance: 10000.0,
        );

        poiProvider.activeFilter = newFilter;

        expect(poiProvider.activeFilter.includedTypes,
            equals([POIType.restaurant]));
        expect(poiProvider.activeFilter.maxDistance, equals(10000.0));
        expect(notificationCount, equals(1));
      });

      test('filters POIs correctly based on active filter', () {
        // Since we cannot modify the internal lists directly from tests,
        // we need to test the filtering logic by creating test POIs
        // and using the filter's apply method directly
        final restaurant = PointOfInterest(
          id: 'restaurant_1',
          name: 'Test Restaurant',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          distance: 5000.0,
        );

        final gasStation = PointOfInterest(
          id: 'gas_1',
          name: 'Test Gas Station',
          type: POIType.gasStation,
          location: const LatLng(37.7750, -122.4195),
          address: 'Gas Address',
          distance: 3000.0,
        );

        final testPOIs = [restaurant, gasStation];

        // Set filter for restaurants only
        final filter = POIFilter(includedTypes: [POIType.restaurant]);
        final filtered = filter.apply(testPOIs);

        expect(filtered.length, equals(1));
        expect(filtered.first.type, equals(POIType.restaurant));
      });
    });

    group('Search radius management', () {
      test('updates search radius and notifies listeners', () {
        var notificationCount = 0;
        poiProvider.addListener(() => notificationCount++);

        poiProvider.searchRadius = 10000; // 10km

        expect(poiProvider.searchRadius, equals(10000));
        expect(notificationCount, equals(1));
      });

      test('filters gas stations by search radius logic', () {
        // Test the filtering logic that would be applied
        final nearStation = GasStation(
          id: 'near_1',
          name: 'Near Station',
          location: const LatLng(37.7749, -122.4194),
          address: 'Near Address',
          state: 'CA',
          prices: {FuelType.regular: 3.50},
          lastUpdated: DateTime.now(),
          distance: 3.0, // 3km
        );

        final farStation = GasStation(
          id: 'far_1',
          name: 'Far Station',
          location: const LatLng(37.8000, -122.4500),
          address: 'Far Address',
          state: 'CA',
          prices: {FuelType.regular: 3.60},
          lastUpdated: DateTime.now(),
          distance: 8.0, // 8km
        );

        final testStations = [nearStation, farStation];
        final searchRadiusKm = 5; // 5km

        // Apply the same filtering logic as the provider
        final filtered = testStations
            .where((station) =>
                station.distance == null || station.distance! <= searchRadiusKm)
            .toList();

        expect(filtered.length, equals(1));
        expect(filtered.first.name, equals('Near Station'));
      });
    });

    group('Marker visibility', () {
      test('toggles marker visibility and notifies listeners', () {
        var notificationCount = 0;
        poiProvider.addListener(() => notificationCount++);

        // Initially markers should be visible
        expect(poiProvider.poiMarkers, isNotNull);
        expect(poiProvider.gasStationMarkers, isNotNull);

        poiProvider.toggleMarkerVisibility();

        expect(poiProvider.poiMarkers, isEmpty);
        expect(poiProvider.gasStationMarkers, isEmpty);
        expect(poiProvider.allMarkers, isEmpty);
        expect(notificationCount, equals(1));

        // Toggle back
        poiProvider.toggleMarkerVisibility();
        expect(notificationCount, equals(2));
      });
    });

    group('POI data management', () {
      test('provides unmodifiable view of POIs', () {
        expect(poiProvider.pois, isA<UnmodifiableListView<PointOfInterest>>());
      });

      test('provides unmodifiable view of gas stations', () {
        expect(
            poiProvider.gasStations, isA<UnmodifiableListView<GasStation>>());
      });

      test('handles empty POI list correctly', () {
        expect(poiProvider.pois, isEmpty);
        expect(poiProvider.filteredPOIs, isEmpty);
      });

      test('handles empty gas station list correctly', () {
        expect(poiProvider.gasStations, isEmpty);
        expect(poiProvider.filteredGasStations, isEmpty);
      });
    });

    group('Filter presets', () {
      test('applies restaurant filter correctly', () {
        final restaurantFilter = POIFilter.food();
        poiProvider.activeFilter = restaurantFilter;

        expect(poiProvider.activeFilter.includedTypes,
            equals([POIType.restaurant, POIType.cafe]));
      });

      test('applies gas station filter correctly', () {
        final gasFilter = POIFilter.gasStations();
        poiProvider.activeFilter = gasFilter;

        expect(poiProvider.activeFilter.includedTypes,
            equals([POIType.gasStation]));
      });

      test('applies rest stop filter correctly', () {
        final restFilter = POIFilter.restStops();
        poiProvider.activeFilter = restFilter;

        expect(poiProvider.activeFilter.includedTypes,
            equals([POIType.restArea, POIType.truckStop]));
      });

      test('applies WiFi filter correctly', () {
        final wifiFilter = POIFilter.withWifi();
        poiProvider.activeFilter = wifiFilter;

        expect(poiProvider.activeFilter.requiredAmenities, equals(['wifi']));
      });
    });

    group('Distance filtering logic', () {
      test('filters POIs by distance correctly', () {
        // Test the filtering logic directly using POIFilter
        final nearPOI = PointOfInterest(
          id: 'near_poi',
          name: 'Near POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Near Address',
          distance: 2000.0, // 2km
        );

        final farPOI = PointOfInterest(
          id: 'far_poi',
          name: 'Far POI',
          type: POIType.restaurant,
          location: const LatLng(37.8000, -122.4500),
          address: 'Far Address',
          distance: 8000.0, // 8km
        );

        final testPOIs = [nearPOI, farPOI];

        // Apply distance filter (5km max)
        final filter = POIFilter(maxDistance: 5000.0);
        final filtered = filter.apply(testPOIs);

        expect(filtered.length, equals(1));
        expect(filtered.first.name, equals('Near POI'));
      });

      test('handles POIs with null distance', () {
        final poiWithoutDistance = PointOfInterest(
          id: 'no_distance',
          name: 'No Distance POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          distance: null,
        );

        final testPOIs = [poiWithoutDistance];

        // Apply distance filter
        final filter = POIFilter(maxDistance: 5000.0);
        final filtered = filter.apply(testPOIs);

        expect(filtered.length, equals(1)); // null distance passes filter
      });
    });

    group('Rating filtering logic', () {
      test('filters POIs by minimum rating correctly', () {
        final highRatedPOI = PointOfInterest(
          id: 'high_rated',
          name: 'High Rated POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          rating: 4.5,
        );

        final lowRatedPOI = PointOfInterest(
          id: 'low_rated',
          name: 'Low Rated POI',
          type: POIType.restaurant,
          location: const LatLng(37.7750, -122.4195),
          address: 'Test Address',
          rating: 2.5,
        );

        final testPOIs = [highRatedPOI, lowRatedPOI];

        // Apply rating filter (4.0 minimum)
        final filter = POIFilter(minRating: 4.0);
        final filtered = filter.apply(testPOIs);

        expect(filtered.length, equals(1));
        expect(filtered.first.rating, equals(4.5));
      });

      test('handles POIs with null rating', () {
        final poiWithoutRating = PointOfInterest(
          id: 'no_rating',
          name: 'No Rating POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          rating: null,
        );

        final testPOIs = [poiWithoutRating];

        // Apply rating filter
        final filter = POIFilter(minRating: 4.0);
        final filtered = filter.apply(testPOIs);

        expect(filtered.length, equals(1)); // null rating passes filter
      });
    });

    group('Amenity filtering logic', () {
      test('filters POIs by required amenities correctly', () {
        final wifiPOI = PointOfInterest(
          id: 'wifi_poi',
          name: 'WiFi POI',
          type: POIType.cafe,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          amenities: ['wifi', 'parking'],
        );

        final noWifiPOI = PointOfInterest(
          id: 'no_wifi_poi',
          name: 'No WiFi POI',
          type: POIType.cafe,
          location: const LatLng(37.7750, -122.4195),
          address: 'Test Address',
          amenities: ['parking'],
        );

        final testPOIs = [wifiPOI, noWifiPOI];

        // Apply amenity filter (WiFi required)
        final filter = POIFilter(requiredAmenities: ['wifi']);
        final filtered = filter.apply(testPOIs);

        expect(filtered.length, equals(1));
        expect(filtered.first.name, equals('WiFi POI'));
      });

      test('handles POIs with null amenities', () {
        final poiWithoutAmenities = PointOfInterest(
          id: 'no_amenities',
          name: 'No Amenities POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          amenities: null,
        );

        final testPOIs = [poiWithoutAmenities];

        // Apply amenity filter
        final filter = POIFilter(requiredAmenities: ['wifi']);
        final filtered = filter.apply(testPOIs);

        expect(filtered, isEmpty); // null amenities fail amenity filter
      });
    });

    group('Complex filtering scenarios', () {
      test('applies multiple filters simultaneously', () {
        final perfectPOI = PointOfInterest(
          id: 'perfect',
          name: 'Perfect POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          distance: 2000.0,
          rating: 4.5,
          amenities: ['wifi', 'parking'],
        );

        final imperfectPOI = PointOfInterest(
          id: 'imperfect',
          name: 'Imperfect POI',
          type: POIType.gasStation, // Wrong type
          location: const LatLng(37.7750, -122.4195),
          address: 'Test Address',
          distance: 1000.0,
          rating: 4.8,
          amenities: ['wifi', 'parking'],
        );

        final testPOIs = [perfectPOI, imperfectPOI];

        // Apply complex filter
        final filter = POIFilter(
          includedTypes: [POIType.restaurant],
          maxDistance: 5000.0,
          minRating: 4.0,
          requiredAmenities: ['wifi'],
        );
        final filtered = filter.apply(testPOIs);

        expect(filtered.length, equals(1));
        expect(filtered.first.name, equals('Perfect POI'));
      });

      test('handles empty filter results', () {
        final poi = PointOfInterest(
          id: 'test',
          name: 'Test POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          distance: 10000.0, // Too far
        );

        final testPOIs = [poi];

        // Apply restrictive filter
        final filter = POIFilter(maxDistance: 1000.0);
        final filtered = filter.apply(testPOIs);

        expect(filtered, isEmpty);
      });
    });

    group('State management', () {
      test('notifies listeners when filter changes', () {
        var notificationCount = 0;
        poiProvider.addListener(() => notificationCount++);

        poiProvider.activeFilter =
            POIFilter(includedTypes: [POIType.restaurant]);
        expect(notificationCount, equals(1));

        poiProvider.activeFilter = POIFilter(maxDistance: 5000.0);
        expect(notificationCount, equals(2));
      });

      test('notifies listeners when search radius changes', () {
        var notificationCount = 0;
        poiProvider.addListener(() => notificationCount++);

        poiProvider.searchRadius = 10000;
        expect(notificationCount, equals(1));

        poiProvider.searchRadius = 15000;
        expect(notificationCount, equals(2));
      });

      test('notifies listeners when marker visibility toggles', () {
        var notificationCount = 0;
        poiProvider.addListener(() => notificationCount++);

        poiProvider.toggleMarkerVisibility();
        expect(notificationCount, equals(1));

        poiProvider.toggleMarkerVisibility();
        expect(notificationCount, equals(2));
      });
    });

    group('Edge cases', () {
      test('handles very large search radius', () {
        poiProvider.searchRadius = 1000000; // 1000km
        expect(poiProvider.searchRadius, equals(1000000));
      });

      test('handles zero search radius', () {
        poiProvider.searchRadius = 0;
        expect(poiProvider.searchRadius, equals(0));
      });

      test('handles filter with empty type list', () {
        poiProvider.activeFilter = POIFilter(includedTypes: []);
        expect(poiProvider.activeFilter.includedTypes, isEmpty);
      });

      test('handles filter with empty amenities list', () {
        poiProvider.activeFilter = POIFilter(requiredAmenities: []);
        expect(poiProvider.activeFilter.requiredAmenities, isEmpty);
      });
    });
  });
}
