import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/heatmap_utils.dart';

/// Provider for managing heatmap data and state
class HeatmapProvider with ChangeNotifier {
  // Heatmap data
  List<HeatmapPoint> _heatmapPoints = [];
  Set<Circle> _heatmapCircles = {};
  bool _isHeatmapVisible = true;
  bool _isLoading = false;
  String? _error;
  Timer? _refreshTimer;

  // Hotspot locations (areas with high demand)
  List<LatLng> _hotspots = [];
  Set<Marker> _hotspotMarkers = {};

  // Current map ID
  String _mapId = 'default_map';

  // Getters
  List<HeatmapPoint> get heatmapPoints => _heatmapPoints;
  Set<Circle> get heatmapCircles => _isHeatmapVisible ? _heatmapCircles : {};
  bool get isHeatmapVisible => _isHeatmapVisible;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<LatLng> get hotspots => _hotspots;
  Set<Marker> get hotspotMarkers => _hotspotMarkers;

  // Constructor
  HeatmapProvider() {
    // Set a timer to refresh heatmap data periodically
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => refreshHeatmapData(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Set the Google Map ID for generating unique tile IDs
  void setMapId(String mapId) {
    _mapId = mapId;
  }

  /// Toggle heatmap visibility
  void toggleHeatmapVisibility() {
    _isHeatmapVisible = !_isHeatmapVisible;
    notifyListeners();
  }

  /// Set hotspot locations
  void setHotspots(List<LatLng> hotspots) {
    _hotspots = hotspots;
    _updateHotspotMarkers();
    notifyListeners();
  }

  /// Update the markers for hotspots
  void _updateHotspotMarkers() {
    final markers = <Marker>{};

    for (int i = 0; i < _hotspots.length; i++) {
      final hotspot = _hotspots[i];
      markers.add(
        Marker(
          markerId: MarkerId('hotspot_$i'),
          position: hotspot,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Demand Hotspot',
            snippet: 'High demand area',
          ),
        ),
      );
    }

    _hotspotMarkers = markers;
  }

  /// Generate and update heatmap data around a center point
  Future<void> updateHeatmapForLocation(
    LatLng center, {
    double radius = 1.0, // Radius in kilometers
    int pointCount = 300,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // In a real app, this would be an API call to fetch heatmap data
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate API delay

      // Generate mock heatmap data for now
      // In production, this would be replaced with real API data
      _heatmapPoints = HeatmapUtils.generateMockHeatmapData(
        center: center,
        radius: radius,
        pointCount: pointCount,
        hotspots: _hotspots,
      );

      // Convert points to Circle overlays
      _heatmapCircles = _generateHeatmapCircles();

      // Update hotspot markers
      _updateHotspotMarkers();
    } catch (e) {
      _error = 'Failed to update heatmap: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generate Circle overlays for the heatmap
  Set<Circle> _generateHeatmapCircles() {
    final circles = <Circle>{};

    for (int i = 0; i < _heatmapPoints.length; i++) {
      final point = _heatmapPoints[i];

      // Calculate circle properties based on intensity
      final radius = 50.0 + (point.intensity * 50.0); // 50-100m radius
      final alpha = 0.3 + (point.intensity * 0.5); // 0.3-0.8 opacity

      // Determine color based on intensity (green to red)
      final color = _getColorForIntensity(point.intensity);

      circles.add(
        Circle(
          circleId: CircleId('heatmap_$i'),
          center: point.position,
          radius: radius,
          fillColor: color.withOpacity(alpha),
          strokeWidth: 0,
        ),
      );
    }

    return circles;
  }

  /// Get color for intensity value (green -> yellow -> orange -> red)
  Color _getColorForIntensity(double intensity) {
    if (intensity < 0.25) {
      return Colors.green;
    } else if (intensity < 0.5) {
      return Colors.yellow;
    } else if (intensity < 0.75) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Refresh heatmap data
  Future<void> refreshHeatmapData() async {
    // This would typically refresh data based on current location
    // For now, we'll just simulate a refresh
    final random = Random();

    // Reset error state
    _error = null;

    // Update hotspots randomly (for demonstration)
    // In production, hotspots would come from the backend
    if (_hotspots.isNotEmpty) {
      final updatedHotspots = <LatLng>[];

      for (final hotspot in _hotspots) {
        // Slightly move the hotspot to simulate changing demand
        final latOffset = (random.nextDouble() - 0.5) * 0.001;
        final lngOffset = (random.nextDouble() - 0.5) * 0.001;

        updatedHotspots.add(LatLng(
          hotspot.latitude + latOffset,
          hotspot.longitude + lngOffset,
        ));
      }

      _hotspots = updatedHotspots;
    }

    // If we have a current location in points, use it as center
    // Otherwise, keep existing data
    if (_heatmapPoints.isNotEmpty) {
      final centerIndex = random.nextInt(_heatmapPoints.length);
      final center = _heatmapPoints[centerIndex].position;

      await updateHeatmapForLocation(center);
    }
  }

  /// Add a new hotspot at the given location
  void addHotspot(LatLng location) {
    _hotspots.add(location);
    _updateHotspotMarkers();
    notifyListeners();

    // Refresh heatmap to incorporate the new hotspot
    if (_heatmapPoints.isNotEmpty) {
      // Use the first point as center for simplicity
      // In a real app, you might use the current map center
      updateHeatmapForLocation(_heatmapPoints.first.position);
    } else {
      // If no points exist yet, use the hotspot location as center
      updateHeatmapForLocation(location);
    }
  }
}
