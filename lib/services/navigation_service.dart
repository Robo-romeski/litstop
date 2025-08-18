import 'dart:io';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for launching navigation to POIs in external map applications
class NavigationService {
  /// Navigate to a POI using platform-specific map applications
  static Future<bool> navigateToPOI({
    required LatLng destination,
    String? destinationName,
  }) async {
    try {
      if (Platform.isIOS) {
        // iOS: Try multiple navigation options
        print('📱 iOS detected, trying multiple navigation apps...');
        final success = await _tryIOSNavigationOptions(
          destination: destination,
          destinationName: destinationName,
        );

        if (success) {
          return true;
        } else {
          // All iOS apps failed, try web fallback
          print('🔄 All iOS navigation apps failed, trying web fallback...');
          return await _launchFallbackNavigation(
            destination: destination,
            destinationName: destinationName,
          );
        }
      } else {
        // Android and other platforms: Use original logic
        final String navigationUrl = _buildNavigationUrl(
          destination: destination,
          destinationName: destinationName,
        );

        print('🗺️ Navigation URL: $navigationUrl');

        final Uri uri = Uri.parse(navigationUrl);

        if (await canLaunchUrl(uri)) {
          print('✅ URL can be launched, opening external app...');
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
          return true;
        } else {
          print('❌ Primary URL cannot be launched, trying fallback...');
          return await _launchFallbackNavigation(
            destination: destination,
            destinationName: destinationName,
          );
        }
      }
    } catch (e) {
      print('❌ Error launching navigation: $e');

      // Try fallback navigation
      return await _launchFallbackNavigation(
        destination: destination,
        destinationName: destinationName,
      );
    }
  }

  /// Build platform-specific navigation URL
  static String _buildNavigationUrl({
    required LatLng destination,
    String? destinationName,
  }) {
    if (Platform.isIOS) {
      // iOS: Use Apple Maps URL scheme
      // http://maps.apple.com/?daddr=latitude,longitude
      // Alternative: maps://maps.apple.com/?daddr=latitude,longitude
      return 'http://maps.apple.com/?daddr=${destination.latitude},${destination.longitude}';
    } else if (Platform.isAndroid) {
      // Android: Use Google Maps intent URI
      // google.navigation:q=latitude,longitude
      return 'google.navigation:q=${destination.latitude},${destination.longitude}';
    } else {
      // Other platforms: Use universal Google Maps URL
      return _buildUniversalMapsUrl(
        destination: destination,
        destinationName: destinationName,
      );
    }
  }

  /// Try multiple iOS navigation options before falling back to web
  static Future<bool> _tryIOSNavigationOptions({
    required LatLng destination,
    String? destinationName,
  }) async {
    // List of navigation options to try in order
    final List<String> navigationOptions = [
      // Apple Maps (standard HTTP URL)
      'http://maps.apple.com/?daddr=${destination.latitude},${destination.longitude}',
      // Apple Maps (app URL scheme)
      'maps://maps.apple.com/?daddr=${destination.latitude},${destination.longitude}',
      // Waze (if installed)
      'waze://?ll=${destination.latitude},${destination.longitude}&navigate=yes',
      // Google Maps iOS app (if installed)
      'comgooglemaps://?daddr=${destination.latitude},${destination.longitude}&directionsmode=driving',
    ];

    // Try each option
    for (int i = 0; i < navigationOptions.length; i++) {
      final String url = navigationOptions[i];
      final String appName = _getAppNameForUrl(url);

      try {
        print('🔍 Trying $appName: $url');
        final Uri uri = Uri.parse(url);

        if (await canLaunchUrl(uri)) {
          print('✅ $appName available, launching...');
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return true;
        } else {
          print('❌ $appName not available');
        }
      } catch (e) {
        print('❌ Error trying $appName: $e');
      }
    }

    print('🔄 All navigation apps failed, falling back to web...');
    return false;
  }

  /// Get app name for debugging purposes
  static String _getAppNameForUrl(String url) {
    if (url.contains('maps.apple.com')) return 'Apple Maps';
    if (url.contains('waze://')) return 'Waze';
    if (url.contains('comgooglemaps://')) return 'Google Maps';
    return 'Unknown App';
  }

  /// Build universal Google Maps URL that works on all platforms
  static String _buildUniversalMapsUrl({
    required LatLng destination,
    String? destinationName,
  }) {
    // Create destination parameter
    String destinationParam;
    if (destinationName != null && destinationName.isNotEmpty) {
      // Use place name with coordinates for better accuracy
      destinationParam =
          '$destinationName,${destination.latitude},${destination.longitude}';
    } else {
      // Use just coordinates
      destinationParam = '${destination.latitude},${destination.longitude}';
    }

    // Encode the destination for URL
    final encodedDestination = Uri.encodeComponent(destinationParam);

    // Return Google Maps URL with directions
    return 'https://www.google.com/maps/dir/?api=1&destination=$encodedDestination';
  }

  /// Fallback navigation using universal maps URL
  static Future<bool> _launchFallbackNavigation({
    required LatLng destination,
    String? destinationName,
  }) async {
    try {
      final String fallbackUrl = _buildUniversalMapsUrl(
        destination: destination,
        destinationName: destinationName,
      );

      print('🔄 Fallback navigation URL: $fallbackUrl'); // Debug logging

      final Uri uri = Uri.parse(fallbackUrl);

      if (await canLaunchUrl(uri)) {
        print('✅ Fallback URL can be launched, opening browser/app...');
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        print('❌ Cannot launch navigation URL: $fallbackUrl');
        return false;
      }
    } catch (e) {
      print('❌ Error in fallback navigation: $e');
      return false;
    }
  }

  /// Navigate to a POI with additional options
  static Future<bool> navigateToPOIWithOptions({
    required LatLng destination,
    String? destinationName,
    NavigationMode mode = NavigationMode.driving,
    List<NavigationAvoid> avoid = const [],
  }) async {
    try {
      String navigationUrl;

      if (Platform.isIOS) {
        // iOS: Apple Maps with transportation mode
        String transportMode = '';
        switch (mode) {
          case NavigationMode.driving:
            transportMode = '&dirflg=d';
            break;
          case NavigationMode.walking:
            transportMode = '&dirflg=w';
            break;
          case NavigationMode.bicycling:
            transportMode = '&dirflg=b';
            break;
          case NavigationMode.transit:
            transportMode = '&dirflg=r';
            break;
        }

        navigationUrl =
            'http://maps.apple.com/?daddr=${destination.latitude},${destination.longitude}$transportMode';
      } else if (Platform.isAndroid) {
        // Android: Google Maps intent with mode and avoid options
        String modeParam = '';
        switch (mode) {
          case NavigationMode.driving:
            modeParam = '&mode=d';
            break;
          case NavigationMode.walking:
            modeParam = '&mode=w';
            break;
          case NavigationMode.bicycling:
            modeParam = '&mode=b';
            break;
          case NavigationMode.transit:
            modeParam = '&mode=r';
            break;
        }

        // Add avoid parameters
        String avoidParam = '';
        if (avoid.isNotEmpty) {
          final avoidStrings = avoid.map((a) {
            switch (a) {
              case NavigationAvoid.tolls:
                return 't';
              case NavigationAvoid.highways:
                return 'h';
              case NavigationAvoid.ferries:
                return 'f';
            }
          }).join('');
          avoidParam = '&avoid=$avoidStrings';
        }

        navigationUrl =
            'google.navigation:q=${destination.latitude},${destination.longitude}$modeParam$avoidParam';
      } else {
        // Fallback to universal URL
        return await _launchFallbackNavigation(
          destination: destination,
          destinationName: destinationName,
        );
      }

      final Uri uri = Uri.parse(navigationUrl);

      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        return true;
      } else {
        // Fallback to basic navigation
        return await navigateToPOI(
          destination: destination,
          destinationName: destinationName,
        );
      }
    } catch (e) {
      print('Error launching navigation with options: $e');

      // Fallback to basic navigation
      return await navigateToPOI(
        destination: destination,
        destinationName: destinationName,
      );
    }
  }
}

/// Navigation modes for transportation
enum NavigationMode {
  driving,
  walking,
  bicycling,
  transit,
}

/// Features to avoid during navigation
enum NavigationAvoid {
  tolls,
  highways,
  ferries,
}
