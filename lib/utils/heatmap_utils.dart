import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a single heatmap data point with intensity
class HeatmapPoint {
  final LatLng position;
  final double intensity; // 0.0 to 1.0

  const HeatmapPoint({
    required this.position,
    required this.intensity,
  });
}

/// Utility class for managing heatmap data and visualization
class HeatmapUtils {
  /// Generates a set of TileOverlays for heatmap visualization
  ///
  /// Takes a list of HeatmapPoint and generates TileOverlay objects
  /// that can be added to a GoogleMap widget
  static Set<TileOverlay> generateHeatmapTiles({
    required List<HeatmapPoint> points,
    required String mapId,
    Color gradientStartColor = Colors.blue,
    Color gradientEndColor = Colors.red,
    int zoom = 13,
  }) {
    if (points.isEmpty) {
      return {};
    }

    // Create a unique tile provider id
    final String tileProviderId =
        '${mapId}_heatmap_${DateTime.now().millisecondsSinceEpoch}';

    return {
      TileOverlay(
        tileOverlayId: TileOverlayId(tileProviderId),
        tileProvider: _HeatmapTileProvider(
          points: points,
          gradientStartColor: gradientStartColor,
          gradientEndColor: gradientEndColor,
          zoom: zoom,
        ),
        transparency: 0.3,
        zIndex: 1,
      ),
    };
  }

  /// Generate simulated heatmap data for a given region
  ///
  /// This is a helper method for generating test data
  /// Replace with real API data in production
  static List<HeatmapPoint> generateMockHeatmapData({
    required LatLng center,
    required double radius,
    required int pointCount,
    List<LatLng> hotspots = const [],
  }) {
    final random = Random();
    final points = <HeatmapPoint>[];

    // Generate random points with random intensities
    for (int i = 0; i < pointCount; i++) {
      // Random angle and distance from center
      final angle = random.nextDouble() * 2 * pi;
      final distance = random.nextDouble() * radius;

      // Calculate position
      final lat = center.latitude + (distance * cos(angle) / 111.32);
      final lng = center.longitude +
          (distance *
              sin(angle) /
              (111.32 * cos(center.latitude * (pi / 180))));

      // Basic intensity (higher near center)
      double intensity = 1.0 - (distance / radius);

      // Factor in hotspots for higher intensity areas
      for (final hotspot in hotspots) {
        final hotspotDistance = calculateDistance(
          LatLng(lat, lng),
          hotspot,
        );

        // Higher intensity near hotspots
        if (hotspotDistance < radius * 0.3) {
          intensity = max(intensity, 1.0 - (hotspotDistance / (radius * 0.3)));
        }
      }

      // Add some randomness
      intensity = (intensity * 0.7) + (random.nextDouble() * 0.3);

      points.add(HeatmapPoint(
        position: LatLng(lat, lng),
        intensity: intensity.clamp(0.0, 1.0),
      ));
    }

    return points;
  }

  /// Calculate distance between two LatLng points in kilometers
  static double calculateDistance(LatLng pos1, LatLng pos2) {
    const p = 0.017453292519943295; // Math.PI / 180
    final lat1 = pos1.latitude;
    final lon1 = pos1.longitude;
    final lat2 = pos2.latitude;
    final lon2 = pos2.longitude;

    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }
}

/// Custom TileProvider for rendering heatmap tiles
///
/// This is a simple implementation that renders points as
/// circles with varying colors based on intensity
class _HeatmapTileProvider implements TileProvider {
  final List<HeatmapPoint> points;
  final Color gradientStartColor;
  final Color gradientEndColor;
  final int zoom;

  _HeatmapTileProvider({
    required this.points,
    required this.gradientStartColor,
    required this.gradientEndColor,
    required this.zoom,
  });

  @override
  Future<Tile> getTile(int x, int y, int? zoom) async {
    // For a real implementation, you would render a custom tile here
    // by filtering points that fall within this tile's bounds
    // and rendering them to a bitmap

    // For now, we'll return a placeholder tile
    // This needs to be replaced with actual tile rendering logic
    return Tile(256, 256, Uint8List(0));
  }
}
