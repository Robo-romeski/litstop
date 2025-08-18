import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/point_of_interest.dart';

void main() {
  group('PointOfInterest Model Tests', () {
    group('POIType enum', () {
      test('contains all expected POI types', () {
        final expectedTypes = [
          POIType.gasStation,
          POIType.restArea,
          POIType.cafe,
          POIType.restaurant,
          POIType.convenienceStore,
          POIType.truckStop,
          POIType.evCharging,
          POIType.hotel,
          POIType.parking,
          POIType.other,
        ];

        for (final type in expectedTypes) {
          expect(POIType.values, contains(type));
        }
        expect(POIType.values.length, equals(expectedTypes.length));
      });
    });

    group('PointOfInterest construction', () {
      test('creates POI with all required fields', () {
        final poi = PointOfInterest(
          id: 'test_id',
          name: 'Test Location',
          type: POIType.restaurant,
          location: LatLng(37.7749, -122.4194),
          address: '123 Test Street, San Francisco, CA',
        );

        expect(poi.id, equals('test_id'));
        expect(poi.name, equals('Test Location'));
        expect(poi.type, equals(POIType.restaurant));
        expect(poi.location.latitude, equals(37.7749));
        expect(poi.location.longitude, equals(-122.4194));
        expect(poi.address, equals('123 Test Street, San Francisco, CA'));
      });

      test('creates POI with optional fields', () {
        final poi = PointOfInterest(
          id: 'test_id',
          name: 'Test Location',
          type: POIType.restaurant,
          location: LatLng(37.7749, -122.4194),
          address: '123 Test Street, San Francisco, CA',
          distance: 1.5,
          duration: 5,
          categories: ['restaurant', 'fast_food'],
          phone: '+1-555-123-4567',
          website: 'https://example.com',
          rating: 4.5,
          amenities: ['wifi', 'parking'],
        );

        expect(poi.distance, equals(1.5));
        expect(poi.duration, equals(5));
        expect(poi.categories, equals(['restaurant', 'fast_food']));
        expect(poi.phone, equals('+1-555-123-4567'));
        expect(poi.website, equals('https://example.com'));
        expect(poi.rating, equals(4.5));
        expect(poi.amenities, equals(['wifi', 'parking']));
      });
    });

    group('iconName getter', () {
      test('returns correct icon names for each POI type', () {
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.gasStation,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('gas_station'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.restArea,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('rest_area'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.cafe,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('cafe'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.restaurant,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('restaurant'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.convenienceStore,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('store'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.truckStop,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('truck_stop'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.evCharging,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('ev_charging'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.hotel,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('hotel'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.parking,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('parking'));
        expect(
            PointOfInterest(
                    id: 'test',
                    name: 'Test',
                    type: POIType.other,
                    location: LatLng(0, 0),
                    address: 'Test')
                .iconName,
            equals('location'));
      });
    });

    group('JSON serialization', () {
      test('toJson creates correct JSON structure', () {
        final poi = PointOfInterest(
          id: 'test_id',
          name: 'Test Restaurant',
          type: POIType.restaurant,
          location: LatLng(37.7749, -122.4194),
          address: '123 Test Street, San Francisco, CA',
          distance: 1.5,
          rating: 4.5,
          amenities: ['wifi', 'parking'],
        );

        final json = poi.toJson();

        expect(json['id'], equals('test_id'));
        expect(json['name'], equals('Test Restaurant'));
        expect(json['type'], equals('restaurant'));
        expect(json['location']['lat'], equals(37.7749));
        expect(json['location']['lng'], equals(-122.4194));
        expect(json['address'], equals('123 Test Street, San Francisco, CA'));
        expect(json['distance'], equals(1.5));
        expect(json['rating'], equals(4.5));
        expect(json['amenities'], equals(['wifi', 'parking']));
      });

      test('fromJson creates correct POI from JSON', () {
        final json = {
          'id': 'test_id',
          'name': 'Test Restaurant',
          'type': 'restaurant',
          'location': {
            'lat': 37.7749,
            'lng': -122.4194,
          },
          'address': '123 Test Street, San Francisco, CA',
          'distance': 1.5,
          'rating': 4.5,
          'amenities': ['wifi', 'parking'],
        };

        final poi = PointOfInterest.fromJson(json);

        expect(poi.id, equals('test_id'));
        expect(poi.name, equals('Test Restaurant'));
        expect(poi.type, equals(POIType.restaurant));
        expect(poi.location.latitude, equals(37.7749));
        expect(poi.location.longitude, equals(-122.4194));
        expect(poi.address, equals('123 Test Street, San Francisco, CA'));
        expect(poi.distance, equals(1.5));
        expect(poi.rating, equals(4.5));
        expect(poi.amenities, equals(['wifi', 'parking']));
      });

      test('fromJson handles missing optional fields', () {
        final json = {
          'id': 'test_id',
          'name': 'Test Location',
          'type': 'other',
          'location': {
            'lat': 37.7749,
            'lng': -122.4194,
          },
          'address': '123 Test Street',
        };

        final poi = PointOfInterest.fromJson(json);

        expect(poi.id, equals('test_id'));
        expect(poi.name, equals('Test Location'));
        expect(poi.type, equals(POIType.other));
        expect(poi.distance, isNull);
        expect(poi.rating, isNull);
        expect(poi.amenities, isNull);
        expect(poi.categories, isNull);
      });

      test('fromJson handles invalid POI type gracefully', () {
        final json = {
          'id': 'test_id',
          'name': 'Test Location',
          'type': 'invalid_type',
          'location': {
            'lat': 37.7749,
            'lng': -122.4194,
          },
          'address': '123 Test Street',
        };

        final poi = PointOfInterest.fromJson(json);

        expect(poi.type, equals(POIType.other));
      });
    });

    group('OpenRouteService JSON parsing', () {
      test('fromOpenRouteService creates POI from ORS response', () {
        final orsJson = {
          'id': 'ors_test_id',
          'geometry': {
            'coordinates': [-122.4194, 37.7749], // lng, lat order in GeoJSON
          },
          'properties': {
            'id': 'prop_id',
            'name': 'Test Restaurant',
            'categories': ['restaurant', 'food'],
            'label': '123 Test Street, San Francisco, CA',
            'distance': 1500.0,
            'phone': '+1-555-123-4567',
            'website': 'https://example.com',
            'wheelchair': 'yes',
            'internet_access': 'wlan',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(orsJson);

        expect(poi.name, equals('Test Restaurant'));
        expect(poi.location.latitude, equals(37.7749));
        expect(poi.location.longitude, equals(-122.4194));
        expect(poi.address, equals('123 Test Street, San Francisco, CA'));
        expect(poi.distance, equals(1500.0));
        expect(poi.phone, equals('+1-555-123-4567'));
        expect(poi.website, equals('https://example.com'));
        expect(poi.categories, equals(['restaurant', 'food']));
        expect(poi.amenities, contains('wheelchair_accessible'));
        expect(poi.amenities, contains('wifi'));
      });

      test('fromOpenRouteService handles missing properties', () {
        final orsJson = {
          'geometry': {
            'coordinates': [-122.4194, 37.7749],
          },
          'properties': {},
        };

        final poi = PointOfInterest.fromOpenRouteService(orsJson);

        expect(poi.name, equals('Unnamed Location'));
        expect(poi.type, equals(POIType.other));
        expect(poi.address, equals('Unknown Address'));
        expect(poi.location.latitude, equals(37.7749));
        expect(poi.location.longitude, equals(-122.4194));
      });
    });

    group('POI type determination', () {
      test('determines gas station type correctly', () {
        final gasStationCategories = ['fuel', 'gas_station', 'petrol'];
        for (final category in gasStationCategories) {
          final json = {
            'id': 'test',
            'geometry': {
              'coordinates': [0.0, 0.0]
            },
            'properties': {
              'name': 'Test Station',
              'categories': [category],
            },
          };
          final poi = PointOfInterest.fromOpenRouteService(json);
          expect(poi.type, equals(POIType.gasStation));
        }
      });

      test('determines restaurant type correctly', () {
        final restaurantCategories = ['restaurant', 'food', 'fast_food'];
        for (final category in restaurantCategories) {
          final json = {
            'id': 'test',
            'geometry': {
              'coordinates': [0.0, 0.0]
            },
            'properties': {
              'name': 'Test Restaurant',
              'categories': [category],
            },
          };
          final poi = PointOfInterest.fromOpenRouteService(json);
          expect(poi.type, equals(POIType.restaurant));
        }
      });

      test('determines cafe type correctly', () {
        final cafeCategories = ['cafe', 'coffee', 'coffee_shop'];
        for (final category in cafeCategories) {
          final json = {
            'id': 'test',
            'geometry': {
              'coordinates': [0.0, 0.0]
            },
            'properties': {
              'name': 'Test Cafe',
              'categories': [category],
            },
          };
          final poi = PointOfInterest.fromOpenRouteService(json);
          expect(poi.type, equals(POIType.cafe));
        }
      });
    });

    group('Edge cases and error handling', () {
      test('handles extreme coordinate values', () {
        final poi = PointOfInterest(
          id: 'test',
          name: 'Extreme Location',
          type: POIType.other,
          location: const LatLng(90.0, 180.0),
          address: 'North Pole',
        );

        expect(poi.location.latitude, equals(90.0));
        expect(poi.location.longitude, equals(-180.0));

        final json = poi.toJson();
        final recreated = PointOfInterest.fromJson(json);
        expect(recreated.location.latitude, equals(90.0));
        expect(recreated.location.longitude, equals(-180.0));
      });

      test('handles very long strings', () {
        final longName = 'A' * 1000;
        final longAddress = 'B' * 2000;

        final poi = PointOfInterest(
          id: 'test',
          name: longName,
          type: POIType.other,
          location: const LatLng(0.0, 0.0),
          address: longAddress,
        );

        expect(poi.name.length, equals(1000));
        expect(poi.address.length, equals(2000));

        final json = poi.toJson();
        expect(() => PointOfInterest.fromJson(json), returnsNormally);
      });

      test('handles empty and null categories and amenities', () {
        final poi1 = PointOfInterest(
          id: 'test1',
          name: 'Test',
          type: POIType.other,
          location: const LatLng(0.0, 0.0),
          address: 'Test',
          categories: [],
          amenities: [],
        );

        final poi2 = PointOfInterest(
          id: 'test2',
          name: 'Test',
          type: POIType.other,
          location: const LatLng(0.0, 0.0),
          address: 'Test',
          categories: null,
          amenities: null,
        );

        expect(poi1.categories, isEmpty);
        expect(poi1.amenities, isEmpty);
        expect(poi2.categories, isNull);
        expect(poi2.amenities, isNull);
      });
    });
  });
}
