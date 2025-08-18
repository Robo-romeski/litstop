import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/poi_filter.dart';
import 'package:litstop/models/point_of_interest.dart';

void main() {
  group('POIFilter Model Tests', () {
    group('POIFilter construction', () {
      test('creates filter with default values', () {
        final filter = POIFilter();

        expect(filter.includedTypes, isNull);
        expect(filter.maxDistance, isNull);
        expect(filter.minRating, isNull);
        expect(filter.requiredAmenities, isNull);
        expect(filter.onlyShowOpen, isNull);
      });

      test('creates filter with custom values', () {
        final filter = POIFilter(
          includedTypes: [POIType.gasStation, POIType.restaurant],
          maxDistance: 25000.0, // 25km in meters
          minRating: 4.0,
          requiredAmenities: ['wifi', 'parking'],
          onlyShowOpen: true,
        );

        expect(filter.includedTypes,
            equals([POIType.gasStation, POIType.restaurant]));
        expect(filter.maxDistance, equals(25000.0));
        expect(filter.minRating, equals(4.0));
        expect(filter.requiredAmenities, equals(['wifi', 'parking']));
        expect(filter.onlyShowOpen, isTrue);
      });
    });

    group('POI filtering logic', () {
      late PointOfInterest testPOI;
      late PointOfInterest gasStation;
      late PointOfInterest restaurant;
      late PointOfInterest cafe;

      setUp(() {
        testPOI = PointOfInterest(
          id: 'test_poi',
          name: 'Test POI',
          type: POIType.restaurant,
          location: const LatLng(37.7749, -122.4194),
          address: 'Test Address',
          distance: 15000.0, // 15km in meters
          rating: 4.5,
          amenities: ['wifi', 'parking'],
          isOpen: true,
        );

        gasStation = PointOfInterest(
          id: 'gas_station',
          name: 'Test Gas Station',
          type: POIType.gasStation,
          location: const LatLng(37.7750, -122.4195),
          address: 'Gas Station Address',
          distance: 5000.0, // 5km in meters
          rating: 3.8,
          amenities: ['restroom'],
          isOpen: false,
        );

        restaurant = PointOfInterest(
          id: 'restaurant',
          name: 'Test Restaurant',
          type: POIType.restaurant,
          location: const LatLng(37.7751, -122.4196),
          address: 'Restaurant Address',
          distance: 30000.0, // 30km in meters
          rating: 4.2,
          amenities: ['wifi', 'parking', 'wheelchair_accessible'],
          isOpen: true,
        );

        cafe = PointOfInterest(
          id: 'cafe',
          name: 'Test Cafe',
          type: POIType.cafe,
          location: const LatLng(37.7752, -122.4197),
          address: 'Cafe Address',
          distance: 8000.0, // 8km in meters
          rating: null,
          amenities: ['wifi'],
          isOpen: null,
        );
      });

      test('filters by POI type correctly', () {
        final filter = POIFilter(includedTypes: [POIType.restaurant]);
        final pois = [testPOI, gasStation, restaurant, cafe];

        final filtered = filter.apply(pois);

        expect(filtered.length, equals(2));
        expect(filtered, contains(testPOI));
        expect(filtered, contains(restaurant));
        expect(filtered, isNot(contains(gasStation)));
        expect(filtered, isNot(contains(cafe)));
      });

      test('filters by distance correctly', () {
        final filter = POIFilter(maxDistance: 10000.0); // 10km in meters
        final pois = [testPOI, gasStation, restaurant, cafe];

        final filtered = filter.apply(pois);

        expect(filtered.length, equals(2));
        expect(filtered, contains(gasStation)); // 5km
        expect(filtered, contains(cafe)); // 8km
        expect(filtered, isNot(contains(testPOI))); // 15km
        expect(filtered, isNot(contains(restaurant))); // 30km
      });

      test('filters by minimum rating correctly', () {
        final filter = POIFilter(minRating: 4.0);
        final pois = [testPOI, gasStation, restaurant, cafe];

        final filtered = filter.apply(pois);

        expect(filtered.length, equals(3)); // includes null rating POI
        expect(filtered, contains(testPOI)); // 4.5 rating
        expect(filtered, contains(restaurant)); // 4.2 rating
        expect(filtered, contains(cafe)); // null rating (passes filter)
        expect(filtered, isNot(contains(gasStation))); // 3.8 rating
      });

      test('filters by required amenities correctly', () {
        final filter = POIFilter(requiredAmenities: ['wifi', 'parking']);
        final pois = [testPOI, gasStation, restaurant, cafe];

        final filtered = filter.apply(pois);

        expect(filtered.length, equals(2));
        expect(filtered, contains(testPOI)); // has wifi and parking
        expect(
            filtered,
            contains(
                restaurant)); // has wifi, parking, and wheelchair_accessible
        expect(filtered, isNot(contains(gasStation))); // only has restroom
        expect(filtered, isNot(contains(cafe))); // only has wifi
      });

      test('filters by open status correctly', () {
        final filter = POIFilter(onlyShowOpen: true);
        final pois = [testPOI, gasStation, restaurant, cafe];

        final filtered = filter.apply(pois);

        expect(filtered.length, equals(2));
        expect(filtered, contains(testPOI)); // isOpen: true
        expect(filtered, contains(restaurant)); // isOpen: true
        expect(filtered, isNot(contains(gasStation))); // isOpen: false
        expect(filtered, isNot(contains(cafe))); // isOpen: null
      });

      test('applies multiple filters correctly', () {
        final filter = POIFilter(
          includedTypes: [POIType.restaurant, POIType.cafe],
          maxDistance: 20000.0, // 20km in meters
          minRating: 4.0,
          requiredAmenities: ['wifi'],
          onlyShowOpen: true,
        );
        final pois = [testPOI, gasStation, restaurant, cafe];

        final filtered = filter.apply(pois);

        expect(filtered.length, equals(1));
        expect(filtered, contains(testPOI));
        // testPOI: restaurant type ✓, 15km distance ✓, 4.5 rating ✓, has wifi ✓, isOpen: true ✓
        // gasStation: wrong type ✗
        // restaurant: restaurant type ✓, 30km distance ✗
        // cafe: cafe type ✓, 8km distance ✓, null rating ✓, has wifi ✓, isOpen: null ✗
      });

      test('handles POI with null distance', () {
        final poiWithoutDistance = PointOfInterest(
          id: 'no_distance',
          name: 'No Distance POI',
          type: POIType.other,
          location: const LatLng(37.7753, -122.4198),
          address: 'No Distance Address',
          distance: null,
        );

        final filter = POIFilter(maxDistance: 10000.0);
        final filtered = filter.apply([poiWithoutDistance]);
        expect(filtered,
            contains(poiWithoutDistance)); // null distance passes filter
      });

      test('handles POI with null rating', () {
        final poiWithoutRating = PointOfInterest(
          id: 'no_rating',
          name: 'No Rating POI',
          type: POIType.other,
          location: const LatLng(37.7754, -122.4199),
          address: 'No Rating Address',
          rating: null,
        );

        final filter = POIFilter(minRating: 3.0);
        final filtered = filter.apply([poiWithoutRating]);
        expect(
            filtered, contains(poiWithoutRating)); // null rating passes filter
      });

      test('handles POI with null amenities', () {
        final poiWithoutAmenities = PointOfInterest(
          id: 'no_amenities',
          name: 'No Amenities POI',
          type: POIType.other,
          location: const LatLng(37.7755, -122.4200),
          address: 'No Amenities Address',
          amenities: null,
        );

        final filter = POIFilter(requiredAmenities: ['wifi']);
        final filtered = filter.apply([poiWithoutAmenities]);
        expect(filtered, isEmpty); // null amenities fails amenity filter
      });
    });

    group('Preset filters', () {
      test('restStops filter works correctly', () {
        final filter = POIFilter.restStops();
        expect(filter.includedTypes,
            equals([POIType.restArea, POIType.truckStop]));
      });

      test('gasStations filter works correctly', () {
        final filter = POIFilter.gasStations();
        expect(filter.includedTypes, equals([POIType.gasStation]));
      });

      test('food filter works correctly', () {
        final filter = POIFilter.food();
        expect(
            filter.includedTypes, equals([POIType.restaurant, POIType.cafe]));
      });

      test('lodging filter works correctly', () {
        final filter = POIFilter.lodging();
        expect(filter.includedTypes, equals([POIType.hotel]));
      });

      test('withWifi filter works correctly', () {
        final filter = POIFilter.withWifi();
        expect(filter.requiredAmenities, equals(['wifi']));
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct JSON structure', () {
        final filter = POIFilter(
          includedTypes: [POIType.gasStation, POIType.restaurant],
          maxDistance: 25000.0,
          minRating: 4.0,
          requiredAmenities: ['wifi', 'parking'],
          onlyShowOpen: true,
        );

        final json = filter.toJson();

        expect(json['includedTypes'], equals(['gasStation', 'restaurant']));
        expect(json['maxDistance'], equals(25000.0));
        expect(json['minRating'], equals(4.0));
        expect(json['requiredAmenities'], equals(['wifi', 'parking']));
        expect(json['onlyShowOpen'], isTrue);
      });

      test('fromJson creates correct filter from JSON', () {
        final json = {
          'includedTypes': ['gasStation', 'restaurant'],
          'maxDistance': 25000.0,
          'minRating': 4.0,
          'requiredAmenities': ['wifi', 'parking'],
          'onlyShowOpen': true,
        };

        final filter = POIFilter.fromJson(json);

        expect(filter.includedTypes,
            equals([POIType.gasStation, POIType.restaurant]));
        expect(filter.maxDistance, equals(25000.0));
        expect(filter.minRating, equals(4.0));
        expect(filter.requiredAmenities, equals(['wifi', 'parking']));
        expect(filter.onlyShowOpen, isTrue);
      });

      test('fromJson handles missing optional fields', () {
        final json = <String, dynamic>{};

        final filter = POIFilter.fromJson(json);

        expect(filter.includedTypes, isNull);
        expect(filter.maxDistance, isNull);
        expect(filter.minRating, isNull);
        expect(filter.requiredAmenities, isNull);
        expect(filter.onlyShowOpen, isNull);
      });

      test('fromJson handles null values', () {
        final json = {
          'includedTypes': null,
          'maxDistance': null,
          'minRating': null,
          'requiredAmenities': null,
          'onlyShowOpen': null,
        };

        final filter = POIFilter.fromJson(json);

        expect(filter.includedTypes, isNull);
        expect(filter.maxDistance, isNull);
        expect(filter.minRating, isNull);
        expect(filter.requiredAmenities, isNull);
        expect(filter.onlyShowOpen, isNull);
      });
    });

    group('copyWith method', () {
      test('creates copy with updated values', () {
        final original = POIFilter(
          includedTypes: [POIType.gasStation],
          maxDistance: 25000.0,
          minRating: 3.0,
          requiredAmenities: ['wifi'],
          onlyShowOpen: false,
        );

        final updated = original.copyWith(
          includedTypes: [POIType.restaurant],
          maxDistance: 15000.0,
        );

        expect(updated.includedTypes, equals([POIType.restaurant]));
        expect(updated.maxDistance, equals(15000.0));
        expect(updated.minRating, equals(3.0)); // unchanged
        expect(updated.requiredAmenities, equals(['wifi'])); // unchanged
        expect(updated.onlyShowOpen, isFalse); // unchanged
      });

      test('creates copy with cleared values', () {
        final original = POIFilter(
          includedTypes: [POIType.gasStation],
          maxDistance: 25000.0,
          minRating: 3.0,
          requiredAmenities: ['wifi'],
          onlyShowOpen: true,
        );

        // Note: copyWith uses ?? operator, so passing null keeps original values
        // This test demonstrates the current behavior, not necessarily ideal behavior
        final cleared = original.copyWith(
          includedTypes: [], // empty list instead of null
          minRating: null,
          requiredAmenities: [],
        );

        expect(cleared.includedTypes, isEmpty);
        expect(cleared.maxDistance, equals(25000.0)); // unchanged
        expect(cleared.minRating, equals(3.0)); // unchanged because ?? operator
        expect(cleared.requiredAmenities, isEmpty);
        expect(cleared.onlyShowOpen, isTrue); // unchanged
      });
    });

    group('Edge cases', () {
      test('handles empty POI type list', () {
        final filter = POIFilter(includedTypes: []);
        final poi = PointOfInterest(
          id: 'test',
          name: 'Test',
          type: POIType.restaurant,
          location: const LatLng(0, 0),
          address: 'Test',
        );

        final filtered = filter.apply([poi]);
        // Empty list means no type filtering is applied (all POIs pass)
        expect(filtered, contains(poi));
      });

      test('handles empty amenities list', () {
        final filter = POIFilter(requiredAmenities: []);
        final poi = PointOfInterest(
          id: 'test',
          name: 'Test',
          type: POIType.restaurant,
          location: const LatLng(0, 0),
          address: 'Test',
          amenities: ['wifi'],
        );

        final filtered = filter.apply([poi]);
        expect(
            filtered, contains(poi)); // empty list means no amenity filtering
      });

      test('handles extreme distance values', () {
        final filter = POIFilter(maxDistance: 0.0);
        final poi = PointOfInterest(
          id: 'test',
          name: 'Test',
          type: POIType.restaurant,
          location: const LatLng(0, 0),
          address: 'Test',
          distance: 0.1,
        );

        final filtered = filter.apply([poi]);
        expect(filtered, isEmpty);
      });

      test('handles extreme rating values', () {
        final filter = POIFilter(minRating: 5.0);
        final poi = PointOfInterest(
          id: 'test',
          name: 'Test',
          type: POIType.restaurant,
          location: const LatLng(0, 0),
          address: 'Test',
          rating: 4.9,
        );

        final filtered = filter.apply([poi]);
        expect(filtered, isEmpty);
      });
    });
  });
}
