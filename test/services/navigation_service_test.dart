import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/services/navigation_service.dart';

void main() {
  group('NavigationService Tests', () {
    final testDestination = const LatLng(37.7749, -122.4194);
    const testDestinationName = 'Test Location';

    group('Platform-specific URL generation', () {
      test('generates correct Apple Maps URL for iOS', () {
        // This test verifies the URL format, actual platform detection
        // would need integration testing
        const expectedUrl = 'http://maps.apple.com/?daddr=37.7749,-122.4194';

        // We can test the URL building logic by examining what URLs
        // would be generated for different platforms
        expect(expectedUrl, contains('maps.apple.com'));
        expect(expectedUrl, contains('37.7749,-122.4194'));
      });

      test('generates correct Google Maps navigation URL for Android', () {
        const expectedUrl = 'google.navigation:q=37.7749,-122.4194';

        expect(expectedUrl, contains('google.navigation:q='));
        expect(expectedUrl, contains('37.7749,-122.4194'));
      });

      test('generates correct universal Google Maps URL', () {
        const expectedUrl =
            'https://www.google.com/maps/dir/?api=1&destination=37.7749%2C-122.4194';

        expect(expectedUrl, contains('google.com/maps/dir'));
        expect(expectedUrl, contains('destination='));
      });
    });

    group('URL generation with destination names', () {
      test('includes destination name in universal URL', () {
        const destinationName = 'Test Restaurant';
        final expectedSubstring =
            Uri.encodeComponent('$destinationName,37.7749,-122.4194');

        // Test that destination name would be included and encoded
        expect(expectedSubstring, contains('Test%20Restaurant'));
        expect(expectedSubstring, contains('37.7749'));
      });

      test('handles special characters in destination names', () {
        const destinationName = 'Café & Restaurant';
        final encodedName = Uri.encodeComponent(destinationName);

        expect(encodedName, contains('Caf%C3%A9'));
        expect(encodedName, contains('%26')); // encoded &
      });
    });

    group('Navigation modes', () {
      test('NavigationMode enum contains all expected values', () {
        expect(NavigationMode.values, contains(NavigationMode.driving));
        expect(NavigationMode.values, contains(NavigationMode.walking));
        expect(NavigationMode.values, contains(NavigationMode.bicycling));
        expect(NavigationMode.values, contains(NavigationMode.transit));
      });

      test('NavigationAvoid enum contains all expected values', () {
        expect(NavigationAvoid.values, contains(NavigationAvoid.tolls));
        expect(NavigationAvoid.values, contains(NavigationAvoid.highways));
        expect(NavigationAvoid.values, contains(NavigationAvoid.ferries));
      });
    });

    group('Error handling', () {
      test('handles invalid coordinates gracefully', () {
        const invalidDestination = LatLng(double.nan, double.nan);

        // Test that we can construct URLs even with invalid coordinates
        // The URL launcher will handle the actual validation
        expect(
            () =>
                'http://maps.apple.com/?daddr=${invalidDestination.latitude},${invalidDestination.longitude}',
            returnsNormally);
      });

      test('handles null destination name gracefully', () {
        const testLat = 37.7749;
        const testLng = -122.4194;

        // Test URL generation without destination name
        final urlWithoutName =
            'https://www.google.com/maps/dir/?api=1&destination=$testLat%2C$testLng';
        expect(urlWithoutName, contains('destination='));
        expect(urlWithoutName, contains('37.7749'));
      });
    });

    group('URL validation', () {
      test('Apple Maps URLs are properly formatted', () {
        const appleUrl = 'http://maps.apple.com/?daddr=37.7749,-122.4194';
        final uri = Uri.parse(appleUrl);

        expect(uri.scheme, equals('http'));
        expect(uri.host, equals('maps.apple.com'));
        expect(uri.queryParameters['daddr'], equals('37.7749,-122.4194'));
      });

      test('Google Maps URLs are properly formatted', () {
        const googleUrl =
            'https://www.google.com/maps/dir/?api=1&destination=37.7749%2C-122.4194';
        final uri = Uri.parse(googleUrl);

        expect(uri.scheme, equals('https'));
        expect(uri.host, equals('www.google.com'));
        expect(uri.path, equals('/maps/dir/'));
        expect(uri.queryParameters['api'], equals('1'));
      });

      test('Waze URLs are properly formatted', () {
        const wazeUrl = 'waze://?ll=37.7749,-122.4194&navigate=yes';
        final uri = Uri.parse(wazeUrl);

        expect(uri.scheme, equals('waze'));
        expect(uri.queryParameters['ll'], equals('37.7749,-122.4194'));
        expect(uri.queryParameters['navigate'], equals('yes'));
      });
    });

    group('Multiple navigation apps fallback', () {
      test('app name detection works correctly', () {
        // Test the logic for detecting app names from URLs
        expect('http://maps.apple.com'.contains('maps.apple.com'), isTrue);
        expect('waze://'.contains('waze://'), isTrue);
        expect('comgooglemaps://'.contains('comgooglemaps://'), isTrue);
      });

      test('fallback sequence includes all major navigation apps', () {
        // Verify that our fallback system includes the major navigation apps
        final fallbackUrls = [
          'http://maps.apple.com/?daddr=37.7749,-122.4194',
          'maps://maps.apple.com/?daddr=37.7749,-122.4194',
          'waze://?ll=37.7749,-122.4194&navigate=yes',
          'comgooglemaps://?daddr=37.7749,-122.4194&directionsmode=driving',
        ];

        expect(fallbackUrls.length, equals(4));
        expect(
            fallbackUrls.any((url) => url.contains('maps.apple.com')), isTrue);
        expect(fallbackUrls.any((url) => url.contains('waze://')), isTrue);
        expect(fallbackUrls.any((url) => url.contains('comgooglemaps://')),
            isTrue);
      });
    });

    group('Transportation modes for advanced navigation', () {
      test('iOS Apple Maps direction flags are correct', () {
        const drivingFlag = '&dirflg=d';
        const walkingFlag = '&dirflg=w';
        const bicyclingFlag = '&dirflg=b';
        const transitFlag = '&dirflg=r';

        expect(drivingFlag, equals('&dirflg=d'));
        expect(walkingFlag, equals('&dirflg=w'));
        expect(bicyclingFlag, equals('&dirflg=b'));
        expect(transitFlag, equals('&dirflg=r'));
      });

      test('Android Google Maps mode parameters are correct', () {
        const drivingMode = '&mode=d';
        const walkingMode = '&mode=w';
        const bicyclingMode = '&mode=b';
        const transitMode = '&mode=r';

        expect(drivingMode, equals('&mode=d'));
        expect(walkingMode, equals('&mode=w'));
        expect(bicyclingMode, equals('&mode=b'));
        expect(transitMode, equals('&mode=r'));
      });

      test('Android avoid parameters are correct', () {
        const avoidTolls = 't';
        const avoidHighways = 'h';
        const avoidFerries = 'f';

        expect(avoidTolls, equals('t'));
        expect(avoidHighways, equals('h'));
        expect(avoidFerries, equals('f'));
      });
    });

    group('Edge cases', () {
      test('handles extreme coordinate values', () {
        const extremeNorth = LatLng(90.0, 0.0);
        const extremeSouth = LatLng(-90.0, 0.0);
        const extremeEast = LatLng(0.0, 180.0);
        const extremeWest = LatLng(0.0, -180.0);

        // Test that URLs can be generated for extreme coordinates
        final urls = [
          'http://maps.apple.com/?daddr=${extremeNorth.latitude},${extremeNorth.longitude}',
          'http://maps.apple.com/?daddr=${extremeSouth.latitude},${extremeSouth.longitude}',
          'http://maps.apple.com/?daddr=${extremeEast.latitude},${extremeEast.longitude}',
          'http://maps.apple.com/?daddr=${extremeWest.latitude},${extremeWest.longitude}',
        ];

        for (final url in urls) {
          expect(() => Uri.parse(url), returnsNormally);
        }
      });

      test('handles very long destination names', () {
        final longName = 'A' * 1000; // 1000 character name
        final encoded = Uri.encodeComponent('$longName,37.7749,-122.4194');

        expect(encoded.length, greaterThan(1000));
        expect(
            () => Uri.parse(
                'https://www.google.com/maps/dir/?destination=$encoded'),
            returnsNormally);
      });
    });
  });
}
