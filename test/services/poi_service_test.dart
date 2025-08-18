import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:litstop/models/point_of_interest.dart';
import 'package:litstop/services/poi_service.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'poi_service_test.mocks.dart';

// Generate mocks
@GenerateMocks([http.Client])
void main() {
  group('POIService Tests', () {
    late POIService poiService;
    late MockClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockClient();
      poiService = POIService();
      // We would need to inject the mock client, but for now we'll test the parsing logic
    });

    group('POI data parsing', () {
      test('parses OpenRouteService response correctly', () {
        final mockResponse = {
          'features': [
            {
              'id': 'test_poi_1',
              'geometry': {
                'coordinates': [-122.4194, 37.7749], // lng, lat
              },
              'properties': {
                'id': 'prop_1',
                'name': 'Test Restaurant',
                'categories': ['restaurant', 'food'],
                'label': '123 Main St, San Francisco, CA',
                'distance': 1500.0,
                'phone': '+1-555-123-4567',
                'website': 'https://example.com',
                'wheelchair': 'yes',
                'internet_access': 'wlan',
              },
            },
            {
              'id': 'test_poi_2',
              'geometry': {
                'coordinates': [-122.4200, 37.7750],
              },
              'properties': {
                'id': 'prop_2',
                'name': 'Test Gas Station',
                'categories': ['fuel', 'gas_station'],
                'label': '456 Oak St, San Francisco, CA',
                'distance': 800.0,
              },
            },
          ],
        };

        // Test the parsing logic by creating POIs from the mock data
        final features = mockResponse['features'] as List;
        final pois = features
            .map((feature) => PointOfInterest.fromOpenRouteService(feature))
            .toList();

        expect(pois.length, equals(2));

        // Test first POI (restaurant)
        final restaurant = pois[0];
        expect(restaurant.name, equals('Test Restaurant'));
        expect(restaurant.type, equals(POIType.restaurant));
        expect(restaurant.location.latitude, equals(37.7749));
        expect(restaurant.location.longitude, equals(-122.4194));
        expect(restaurant.address, equals('123 Main St, San Francisco, CA'));
        expect(restaurant.distance, equals(1500.0));
        expect(restaurant.phone, equals('+1-555-123-4567'));
        expect(restaurant.website, equals('https://example.com'));
        expect(restaurant.amenities, contains('wheelchair_accessible'));
        expect(restaurant.amenities, contains('wifi'));

        // Test second POI (gas station)
        final gasStation = pois[1];
        expect(gasStation.name, equals('Test Gas Station'));
        expect(gasStation.type, equals(POIType.gasStation));
        expect(gasStation.location.latitude, equals(37.7750));
        expect(gasStation.location.longitude, equals(-122.4200));
        expect(gasStation.address, equals('456 Oak St, San Francisco, CA'));
        expect(gasStation.distance, equals(800.0));
      });

      test('handles empty response correctly', () {
        final mockResponse = {
          'features': [],
        };

        final features = mockResponse['features'] as List;
        final pois = features
            .map((feature) => PointOfInterest.fromOpenRouteService(feature))
            .toList();

        expect(pois, isEmpty);
      });

      test('handles malformed POI data gracefully', () {
        final mockResponse = {
          'features': [
            {
              'geometry': {
                'coordinates': [-122.4194, 37.7749],
              },
              'properties': {
                // Missing name and other properties
              },
            },
          ],
        };

        final features = mockResponse['features'] as List;
        final pois = features
            .map((feature) => PointOfInterest.fromOpenRouteService(feature))
            .toList();

        expect(pois.length, equals(1));
        final poi = pois[0];
        expect(poi.name, equals('Unnamed Location'));
        expect(poi.type, equals(POIType.other));
        expect(poi.address, equals('Unknown Address'));
      });
    });

    group('POI type categorization', () {
      test('categorizes gas stations correctly', () {
        final gasStationData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Shell Station',
            'categories': ['fuel', 'gas_station'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(gasStationData);
        expect(poi.type, equals(POIType.gasStation));
      });

      test('categorizes restaurants correctly', () {
        final restaurantData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Pizza Place',
            'categories': ['restaurant', 'food'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(restaurantData);
        expect(poi.type, equals(POIType.restaurant));
      });

      test('categorizes cafes correctly', () {
        final cafeData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Coffee Shop',
            'categories': ['cafe', 'coffee'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(cafeData);
        expect(poi.type, equals(POIType.cafe));
      });

      test('categorizes convenience stores correctly', () {
        final storeData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': '7-Eleven',
            'categories': ['convenience', 'shop'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(storeData);
        expect(poi.type, equals(POIType.convenienceStore));
      });

      test('categorizes truck stops correctly', () {
        final truckStopData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Flying J Travel Center',
            'categories': ['truck_stop'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(truckStopData);
        expect(poi.type, equals(POIType.truckStop));
      });

      test('categorizes EV charging stations correctly', () {
        final evData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Tesla Supercharger',
            'categories': ['charging', 'ev'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(evData);
        expect(poi.type, equals(POIType.evCharging));
      });

      test('categorizes hotels correctly', () {
        final hotelData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Holiday Inn',
            'categories': ['hotel', 'lodging'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(hotelData);
        expect(poi.type, equals(POIType.hotel));
      });

      test('categorizes parking correctly', () {
        final parkingData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Public Parking',
            'categories': ['parking'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(parkingData);
        expect(poi.type, equals(POIType.parking));
      });

      test('defaults to other for unknown categories', () {
        final unknownData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Unknown Place',
            'categories': ['unknown_category'],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(unknownData);
        expect(poi.type, equals(POIType.other));
      });
    });

    group('Amenity parsing', () {
      test('parses wheelchair accessibility correctly', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Accessible Place',
            'wheelchair': 'yes',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.amenities, contains('wheelchair_accessible'));
      });

      test('parses WiFi availability correctly', () {
        final wifiData = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'WiFi Place',
            'internet_access': 'wlan',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(wifiData);
        expect(poi.amenities, contains('wifi'));

        final wifiData2 = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'WiFi Place 2',
            'internet_access': 'yes',
          },
        };

        final poi2 = PointOfInterest.fromOpenRouteService(wifiData2);
        expect(poi2.amenities, contains('wifi'));
      });

      test('handles multiple amenities correctly', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Full Service Place',
            'wheelchair': 'yes',
            'internet_access': 'wlan',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.amenities, contains('wheelchair_accessible'));
        expect(poi.amenities, contains('wifi'));
        expect(poi.amenities?.length, equals(2));
      });

      test('handles no amenities correctly', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Basic Place',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.amenities, isNull);
      });
    });

    group('Distance and location handling', () {
      test('handles distance correctly', () {
        final data = {
          'geometry': {
            'coordinates': [-122.4194, 37.7749]
          },
          'properties': {
            'name': 'Test Place',
            'distance': 2500.5,
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.distance, equals(2500.5));
      });

      test('handles missing distance correctly', () {
        final data = {
          'geometry': {
            'coordinates': [-122.4194, 37.7749]
          },
          'properties': {
            'name': 'Test Place',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.distance, isNull);
      });

      test('handles coordinate parsing correctly', () {
        final data = {
          'geometry': {
            'coordinates': [-122.4194, 37.7749]
          },
          'properties': {
            'name': 'Test Place',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.location.latitude, equals(37.7749));
        expect(poi.location.longitude, equals(-122.4194));
      });

      test('handles extreme coordinates correctly', () {
        final data = {
          'geometry': {
            'coordinates': [180.0, 90.0]
          },
          'properties': {
            'name': 'Extreme Place',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.location.latitude, equals(90.0));
        expect(poi.location.longitude,
            equals(-180.0)); // LatLng normalizes 180 to -180
      });
    });

    group('Contact information parsing', () {
      test('parses phone numbers correctly', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Test Place',
            'phone': '+1-555-123-4567',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.phone, equals('+1-555-123-4567'));
      });

      test('parses websites correctly', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Test Place',
            'website': 'https://example.com',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.website, equals('https://example.com'));
      });

      test('handles missing contact information correctly', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Test Place',
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.phone, isNull);
        expect(poi.website, isNull);
      });
    });

    group('Edge cases and error handling', () {
      test('handles missing geometry gracefully', () {
        expect(() {
          final data = {
            'properties': {
              'name': 'Test Place',
            },
          };
          PointOfInterest.fromOpenRouteService(data);
        }, throwsA(isA<NoSuchMethodError>()));
      });

      test('handles missing coordinates gracefully', () {
        expect(() {
          final data = {
            'geometry': {},
            'properties': {
              'name': 'Test Place',
            },
          };
          PointOfInterest.fromOpenRouteService(data);
        }, throwsA(isA<NoSuchMethodError>()));
      });

      test('handles invalid coordinate format gracefully', () {
        expect(() {
          final data = {
            'geometry': {
              'coordinates': ['invalid', 'coordinates'],
            },
            'properties': {
              'name': 'Test Place',
            },
          };
          PointOfInterest.fromOpenRouteService(data);
        }, throwsA(isA<TypeError>()));
      });

      test('handles very long names and addresses', () {
        final longName = 'A' * 1000;
        final longAddress = 'B' * 2000;

        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': longName,
            'label': longAddress,
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.name.length, equals(1000));
        expect(poi.address.length, equals(2000));
      });

      test('handles null categories list', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Test Place',
            'categories': null,
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.type, equals(POIType.other));
        expect(poi.categories, isNull);
      });

      test('handles empty categories list', () {
        final data = {
          'geometry': {
            'coordinates': [0.0, 0.0]
          },
          'properties': {
            'name': 'Test Place',
            'categories': [],
          },
        };

        final poi = PointOfInterest.fromOpenRouteService(data);
        expect(poi.type, equals(POIType.other));
        expect(poi.categories, isEmpty);
      });
    });
  });
}
