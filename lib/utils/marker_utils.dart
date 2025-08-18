import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/point_of_interest.dart';
import '../models/gas_station.dart';

/// Utility class for creating custom map markers
class MarkerUtils {
  /// Asset paths for POI icons
  static const Map<POIType, String> _poiIcons = {
    POIType.gasStation: 'assets/images/gas_station.png',
    POIType.restArea: 'assets/images/rest_area.png',
    POIType.cafe: 'assets/images/cafe.png',
    POIType.restaurant: 'assets/images/restaurant.png',
    POIType.convenienceStore: 'assets/images/store.png',
    POIType.truckStop: 'assets/images/truck_stop.png',
    POIType.evCharging: 'assets/images/ev_charging.png',
    POIType.hotel: 'assets/images/hotel.png',
    POIType.parking: 'assets/images/parking.png',
    POIType.other: 'assets/images/location.png',
  };

  /// Map of POI types to their corresponding hue values (for default markers)
  static const Map<POIType, double> _poiHues = {
    POIType.gasStation: BitmapDescriptor.hueRed,
    POIType.restArea: BitmapDescriptor.hueBlue,
    POIType.cafe: BitmapDescriptor.hueViolet,
    POIType.restaurant: BitmapDescriptor.hueOrange,
    POIType.convenienceStore: BitmapDescriptor.hueRose,
    POIType.truckStop: BitmapDescriptor.hueBlue,
    POIType.evCharging: BitmapDescriptor.hueGreen,
    POIType.hotel: BitmapDescriptor.hueAzure,
    POIType.parking: BitmapDescriptor.hueCyan,
    POIType.other: BitmapDescriptor.hueYellow,
  };

  /// Map of POI types to their corresponding colors (for custom markers)
  static final Map<POIType, Color> _poiColors = {
    POIType.gasStation: Colors.red,
    POIType.restArea: Colors.blue,
    POIType.cafe: Colors.purple,
    POIType.restaurant: Colors.orange,
    POIType.convenienceStore: Colors.pink,
    POIType.truckStop: Colors.indigo,
    POIType.evCharging: Colors.green,
    POIType.hotel: Colors.lightBlue,
    POIType.parking: Colors.cyan,
    POIType.other: Colors.amber,
  };

  /// Map of POI types to their corresponding icons (for custom markers)
  static final Map<POIType, IconData> _poiIconData = {
    POIType.gasStation: Icons.local_gas_station,
    POIType.restArea: Icons.airline_seat_individual_suite,
    POIType.cafe: Icons.coffee,
    POIType.restaurant: Icons.restaurant,
    POIType.convenienceStore: Icons.store,
    POIType.truckStop: Icons.local_shipping,
    POIType.evCharging: Icons.electrical_services,
    POIType.hotel: Icons.hotel,
    POIType.parking: Icons.local_parking,
    POIType.other: Icons.location_on,
  };

  /// Cached BitmapDescriptors for POI types
  static final Map<POIType, BitmapDescriptor> _poiBitmapCache = {};

  /// Cached BitmapDescriptor for gas stations
  static BitmapDescriptor? _gasStationBitmap;

  /// Flag to use dynamically generated markers instead of assets
  static const bool _useDynamicMarkers = true;

  /// Create markers for a list of POIs
  static Future<Set<Marker>> createPOIMarkers(
    List<PointOfInterest> pois, {
    void Function(PointOfInterest)? onTap,
  }) async {
    final markers = <Marker>{};

    for (final poi in pois) {
      try {
        final marker = await createPOIMarker(poi, onTap: onTap);
        markers.add(marker);
      } catch (e) {
        print('Error creating marker for POI ${poi.id}: $e');
      }
    }

    return markers;
  }

  /// Create a marker for a single POI
  static Future<Marker> createPOIMarker(
    PointOfInterest poi, {
    void Function(PointOfInterest)? onTap,
  }) async {
    final icon = await _getPOIBitmapDescriptor(poi.type);

    return Marker(
      markerId: MarkerId('poi_${poi.id}'),
      position: poi.location,
      icon: icon,
      infoWindow: InfoWindow(
        title: poi.name,
        snippet: poi.address,
      ),
      onTap: onTap != null ? () => onTap(poi) : null,
    );
  }

  /// Create markers for a list of gas stations
  static Future<Set<Marker>> createGasStationMarkers(
    List<GasStation> stations, {
    void Function(GasStation)? onTap,
  }) async {
    final markers = <Marker>{};

    for (final station in stations) {
      try {
        final marker = await createGasStationMarker(station, onTap: onTap);
        markers.add(marker);
      } catch (e) {
        print('Error creating marker for gas station ${station.id}: $e');
      }
    }

    return markers;
  }

  /// Create a marker for a single gas station
  static Future<Marker> createGasStationMarker(
    GasStation station, {
    void Function(GasStation)? onTap,
  }) async {
    // Default to gas station icon
    final icon = await _getGasStationBitmapDescriptor();

    // Format prices for info window
    final String priceInfo = station.regularPrice != null
        ? 'Regular: \$${station.regularPrice?.toStringAsFixed(2) ?? 'N/A'}'
        : 'Price data unavailable';

    return Marker(
      markerId: MarkerId('gas_${station.id}'),
      position: station.location,
      icon: icon,
      infoWindow: InfoWindow(
        title: station.name,
        snippet: '$priceInfo\n${station.address}',
      ),
      onTap: onTap != null ? () => onTap(station) : null,
    );
  }

  /// Get a BitmapDescriptor for a POI type, with caching
  static Future<BitmapDescriptor> _getPOIBitmapDescriptor(POIType type) async {
    // Return cached bitmap if available
    if (_poiBitmapCache.containsKey(type)) {
      return _poiBitmapCache[type]!;
    }

    // For dynamic marker generation (preferred for consistency)
    if (_useDynamicMarkers) {
      final Color markerColor = _poiColors[type] ?? Colors.amber;
      final IconData iconData = _poiIconData[type] ?? Icons.location_on;

      final BitmapDescriptor customIcon = await createCustomMarker(
        markerColor,
        iconData: iconData,
      );

      // Cache the bitmap
      _poiBitmapCache[type] = customIcon;
      return customIcon;
    }

    try {
      // Try to load custom marker from asset
      final String assetPath = _poiIcons[type] ?? _poiIcons[POIType.other]!;
      final ByteData assetData = await rootBundle.load(assetPath);

      // Check if asset is empty (file exists but has no content)
      if (assetData.lengthInBytes < 10) {
        throw Exception('Asset file is empty or too small');
      }

      final Uint8List byteData = assetData.buffer.asUint8List();

      // Create bitmap from asset data
      final BitmapDescriptor customIcon = BitmapDescriptor.fromBytes(byteData);

      // Cache the bitmap
      _poiBitmapCache[type] = customIcon;
      return customIcon;
    } catch (e) {
      print('Using fallback marker for $type: $e');
      return _getFallbackMarker(type);
    }
  }

  /// Create a fallback marker with a distinctive color based on POI type
  static BitmapDescriptor _getFallbackMarker(POIType type) {
    // Get the hue color value for the POI type, or default to yellow
    final hue = _poiHues[type] ?? BitmapDescriptor.hueYellow;

    // Create a colored default marker
    final fallbackIcon = BitmapDescriptor.defaultMarkerWithHue(hue);

    // Cache the fallback bitmap
    _poiBitmapCache[type] = fallbackIcon;
    return fallbackIcon;
  }

  /// Get a BitmapDescriptor for gas stations, with caching
  static Future<BitmapDescriptor> _getGasStationBitmapDescriptor() async {
    // Return cached bitmap if available
    if (_gasStationBitmap != null) {
      return _gasStationBitmap!;
    }

    // For dynamic marker generation (preferred for consistency)
    if (_useDynamicMarkers) {
      final customIcon = await createCustomMarker(
        Colors.red,
        iconData: Icons.local_gas_station,
      );

      // Cache the bitmap
      _gasStationBitmap = customIcon;
      return customIcon;
    }

    try {
      // Try to load custom gas station marker from asset
      final String assetPath = _poiIcons[POIType.gasStation]!;
      final ByteData assetData = await rootBundle.load(assetPath);

      // Check if asset is empty
      if (assetData.lengthInBytes < 10) {
        throw Exception('Gas station asset file is empty or too small');
      }

      final Uint8List byteData = assetData.buffer.asUint8List();

      // Create bitmap from asset data
      final BitmapDescriptor customIcon = BitmapDescriptor.fromBytes(byteData);

      // Cache the bitmap
      _gasStationBitmap = customIcon;
      return customIcon;
    } catch (e) {
      print('Using fallback gas station marker: $e');

      // Fallback to red default marker if asset loading fails
      _gasStationBitmap =
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      return _gasStationBitmap!;
    }
  }

  /// Helper method to generate custom colored circle markers with icons
  static Future<BitmapDescriptor> createCustomMarker(
    Color color, {
    IconData? iconData,
    double size = 120,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint circlePaint = Paint()..color = color;

    // Draw the main colored circle
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, circlePaint);

    // Add a white border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2 - 4, borderPaint);

    // Draw the icon if provided
    if (iconData != null) {
      final TextPainter textPainter =
          TextPainter(textDirection: TextDirection.ltr);
      textPainter.text = TextSpan(
        text: String.fromCharCode(iconData.codePoint),
        style: TextStyle(
          fontSize: size * 0.5,
          fontFamily: iconData.fontFamily,
          color: Colors.white,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          size / 2 - textPainter.width / 2,
          size / 2 - textPainter.height / 2,
        ),
      );
    }

    // Convert to image
    final img = await pictureRecorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    final ByteData? data = await img.toByteData(format: ui.ImageByteFormat.png);

    if (data == null) {
      throw Exception('Failed to create custom marker');
    }

    return BitmapDescriptor.fromBytes(data.buffer.asUint8List());
  }
}
