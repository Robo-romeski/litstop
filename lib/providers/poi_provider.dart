import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/gas_station.dart';
import '../models/point_of_interest.dart';
import '../models/poi_filter.dart';
import '../services/gas_price_service.dart';
import '../services/poi_service.dart';
import '../services/navigation_service.dart';
import '../utils/marker_utils.dart';
import '../widgets/poi_details_sheet.dart';

/// Provider for managing Points of Interest (POIs)
class POIProvider extends ChangeNotifier {
  /// Service for fetching POIs
  final POIService _poiService;

  /// Service for fetching gas prices
  final GasPriceService _gasPriceService;

  /// All POIs currently loaded
  final List<PointOfInterest> _pois = [];

  /// All gas stations currently loaded
  final List<GasStation> _gasStations = [];

  /// Currently active filter
  POIFilter _activeFilter = POIFilter();

  /// Cache expiration time (default: 30 minutes)
  final Duration _cacheExpiration = const Duration(minutes: 30);

  /// Last time data was fetched
  DateTime? _lastFetchTime;

  /// Whether data is currently being loaded
  bool _isLoading = false;

  /// Current search radius in meters
  int _searchRadius = 5000; // 5km

  /// Error message if any
  String? _errorMessage;

  /// POI markers for the map
  final Set<Marker> _poiMarkers = {};

  /// Gas station markers for the map
  final Set<Marker> _gasStationMarkers = {};

  /// Whether markers are currently visible
  bool _areMarkersVisible = true;

  /// Current BuildContext for showing UI components
  BuildContext? _currentContext;

  /// Default constructor
  POIProvider({String? apiKeyPOI, String? apiKeyGas})
      : _poiService = POIService(apiKey: apiKeyPOI),
        _gasPriceService = GasPriceService(apiKey: apiKeyGas);

  /// Get all POIs (unmodifiable)
  UnmodifiableListView<PointOfInterest> get pois => UnmodifiableListView(_pois);

  /// Get filtered POIs based on active filter
  List<PointOfInterest> get filteredPOIs => _activeFilter.apply(_pois);

  /// Get all gas stations (unmodifiable)
  UnmodifiableListView<GasStation> get gasStations =>
      UnmodifiableListView(_gasStations);

  /// Get filtered gas stations based on distance
  List<GasStation> get filteredGasStations => _gasStations
      .where((station) =>
              station.distance == null ||
              station.distance! <= (_searchRadius / 1000) // Convert m to km
          )
      .toList();

  /// Get active filter
  POIFilter get activeFilter => _activeFilter;

  /// Whether data is being loaded
  bool get isLoading => _isLoading;

  /// Get current search radius in meters
  int get searchRadius => _searchRadius;

  /// Get error message
  String? get errorMessage => _errorMessage;

  /// Get POI markers for display on the map
  Set<Marker> get poiMarkers => _areMarkersVisible ? _poiMarkers : {};

  /// Get gas station markers for display on the map
  Set<Marker> get gasStationMarkers =>
      _areMarkersVisible ? _gasStationMarkers : {};

  /// Get all markers combined
  Set<Marker> get allMarkers {
    if (!_areMarkersVisible) return {};
    return {..._poiMarkers, ..._gasStationMarkers};
  }

  /// Set active filter and notify listeners
  set activeFilter(POIFilter filter) {
    _activeFilter = filter;
    _updateMarkers(); // Refresh markers based on new filter
    notifyListeners();
  }

  /// Set search radius and notify listeners
  set searchRadius(int radius) {
    _searchRadius = radius;
    _updateMarkers(); // Refresh markers based on new radius
    notifyListeners();
  }

  /// Toggle marker visibility
  void toggleMarkerVisibility() {
    _areMarkersVisible = !_areMarkersVisible;
    notifyListeners();
  }

  /// Check if cache is expired
  bool get _isCacheExpired {
    if (_lastFetchTime == null) return true;

    final now = DateTime.now();
    return now.difference(_lastFetchTime!) > _cacheExpiration;
  }

  /// Fetch nearby POIs based on location and types
  Future<void> fetchNearbyPOIs({
    required LatLng location,
    required List<POIType> poiTypes,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Skip if cache is valid and not forcing refresh
      if (!forceRefresh && !_isCacheExpired && _pois.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final pois = await _poiService.fetchNearbyPOIs(
        location: location,
        poiTypes: poiTypes,
        radius: _searchRadius,
      );

      _pois.clear();
      _pois.addAll(pois);
      _lastFetchTime = DateTime.now();

      // Update markers
      await _updatePOIMarkers();

      // Save to cache
      await _savePOIsToCache();
    } catch (e) {
      _errorMessage = 'Failed to fetch nearby POIs: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Search POIs by query
  Future<void> searchPOIs({
    required String query,
    required LatLng location,
  }) async {
    if (_isLoading || query.isEmpty) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final pois = await _poiService.searchPOIs(
        query: query,
        location: location,
        radius: _searchRadius,
      );

      _pois.clear();
      _pois.addAll(pois);

      // Update markers
      await _updatePOIMarkers();
    } catch (e) {
      _errorMessage = 'Failed to search POIs: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch nearby gas stations
  Future<void> fetchNearbyGasStations({
    required LatLng location,
    bool forceRefresh = false,
  }) async {
    if (_isLoading) return;

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Skip if cache is valid and not forcing refresh
      if (!forceRefresh && !_isCacheExpired && _gasStations.isNotEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      final stations = await _gasPriceService.getNearbyGasStations(
        location,
        radius: _searchRadius / 1000, // Convert meters to km
      );

      _gasStations.clear();
      _gasStations.addAll(stations);
      _lastFetchTime = DateTime.now();

      // Update markers
      await _updateGasStationMarkers();

      // Save to cache
      await _saveGasStationsToCache();
    } catch (e) {
      _errorMessage = 'Failed to fetch nearby gas stations: $e';
      print(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Find POIs along a route
  Future<List<PointOfInterest>> findPOIsAlongRoute({
    required LatLng start,
    required LatLng end,
    required List<POIType> poiTypes,
    int bufferDistance = 1000, // 1km from route
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Calculate route
      final route = await _poiService.calculateRoute(
        start: start,
        end: end,
      );

      // Find POIs along route
      final pois = await _poiService.getPOIsAlongRoute(
        routePoints: route,
        poiTypes: poiTypes,
        bufferDistance: bufferDistance,
      );

      return pois;
    } catch (e) {
      _errorMessage = 'Failed to find POIs along route: $e';
      print(_errorMessage);
      return [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Find rest areas along a route
  Future<List<PointOfInterest>> findRestAreasAlongRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    return findPOIsAlongRoute(
      start: start,
      end: end,
      poiTypes: [POIType.restArea, POIType.truckStop],
    );
  }

  /// Find gas stations along a route
  Future<List<PointOfInterest>> findGasStationsAlongRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    return findPOIsAlongRoute(
      start: start,
      end: end,
      poiTypes: [POIType.gasStation],
    );
  }

  /// Find food options along a route
  Future<List<PointOfInterest>> findFoodAlongRoute({
    required LatLng start,
    required LatLng end,
  }) async {
    return findPOIsAlongRoute(
      start: start,
      end: end,
      poiTypes: [POIType.restaurant, POIType.cafe],
    );
  }

  /// Handle tap on a POI marker
  void _handlePOITap(PointOfInterest poi) {
    // Find the current BuildContext
    if (_currentContext != null) {
      showModalBottomSheet(
        context: _currentContext!,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => POIDetailsSheet.fromPOI(
          poi: poi,
          onNavigate: (location) async {
            // Navigate to POI using NavigationService
            final success = await NavigationService.navigateToPOI(
              destination: location,
              destinationName: poi.name,
            );

            if (!success) {
              // Show error message if navigation failed
              if (_currentContext != null && _currentContext!.mounted) {
                ScaffoldMessenger.of(_currentContext!).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to open navigation app'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );
    }
  }

  /// Handle tap on a gas station marker
  void _handleGasStationTap(GasStation station) {
    // Find the current BuildContext
    if (_currentContext != null) {
      showModalBottomSheet(
        context: _currentContext!,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => POIDetailsSheet.fromGasStation(
          gasStation: station,
          onNavigate: (location) async {
            // Navigate to gas station using NavigationService
            final success = await NavigationService.navigateToPOI(
              destination: location,
              destinationName: station.name,
            );

            if (!success) {
              // Show error message if navigation failed
              if (_currentContext != null && _currentContext!.mounted) {
                ScaffoldMessenger.of(_currentContext!).showSnackBar(
                  const SnackBar(
                    content: Text('Unable to open navigation app'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
        ),
      );
    }
  }

  /// Update all markers based on current data
  Future<void> _updateMarkers() async {
    await _updatePOIMarkers();
    await _updateGasStationMarkers();
  }

  /// Update POI markers
  Future<void> _updatePOIMarkers() async {
    // Apply filter to get the POIs we want to show
    final poisToShow = _activeFilter.apply(_pois);

    // Create markers
    _poiMarkers.clear();
    final markers = await MarkerUtils.createPOIMarkers(
      poisToShow,
      onTap: _handlePOITap,
    );
    _poiMarkers.addAll(markers);

    notifyListeners();
  }

  /// Update gas station markers
  Future<void> _updateGasStationMarkers() async {
    // Filter gas stations by distance
    final stationsToShow = filteredGasStations;

    // Create markers
    _gasStationMarkers.clear();
    final markers = await MarkerUtils.createGasStationMarkers(
      stationsToShow,
      onTap: _handleGasStationTap,
    );
    _gasStationMarkers.addAll(markers);

    notifyListeners();
  }

  /// Load cached POIs
  Future<void> loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached POIs
      final poiJsonList = prefs.getStringList('cached_pois');
      if (poiJsonList != null && poiJsonList.isNotEmpty) {
        final pois = poiJsonList
            .map((json) => PointOfInterest.fromJson(Map<String, dynamic>.from(
                Map<String, dynamic>.from(jsonParseWithStatus(json)!))))
            .toList();

        _pois.clear();
        _pois.addAll(pois);
      }

      // Load cached gas stations
      final gasJsonList = prefs.getStringList('cached_gas_stations');
      if (gasJsonList != null && gasJsonList.isNotEmpty) {
        final stations = gasJsonList
            .map((json) => GasStation.fromJson(Map<String, dynamic>.from(
                Map<String, dynamic>.from(jsonParseWithStatus(json)!))))
            .toList();

        _gasStations.clear();
        _gasStations.addAll(stations);
      }

      // Load last fetch time
      final lastFetchStr = prefs.getString('last_poi_fetch_time');
      if (lastFetchStr != null) {
        _lastFetchTime = DateTime.parse(lastFetchStr);
      }

      // Update markers with loaded data
      await _updateMarkers();

      notifyListeners();
    } catch (e) {
      print('Failed to load POIs from cache: $e');
    }
  }

  /// Save POIs to cache
  Future<void> _savePOIsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save POIs
      final poiJsonList =
          _pois.map((poi) => jsonEncodeWithStatus(poi.toJson())).toList();

      await prefs.setStringList('cached_pois', poiJsonList);

      // Save last fetch time
      await prefs.setString(
          'last_poi_fetch_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Failed to save POIs to cache: $e');
    }
  }

  /// Save gas stations to cache
  Future<void> _saveGasStationsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save gas stations
      final gasJsonList = _gasStations
          .map((station) => jsonEncodeWithStatus(station.toJson()))
          .toList();

      await prefs.setStringList('cached_gas_stations', gasJsonList);

      // Save last fetch time
      await prefs.setString(
          'last_poi_fetch_time', DateTime.now().toIso8601String());
    } catch (e) {
      print('Failed to save gas stations to cache: $e');
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_pois');
      await prefs.remove('cached_gas_stations');
      await prefs.remove('last_poi_fetch_time');

      _pois.clear();
      _gasStations.clear();
      _lastFetchTime = null;

      // Clear markers
      _poiMarkers.clear();
      _gasStationMarkers.clear();

      notifyListeners();
    } catch (e) {
      print('Failed to clear POI cache: $e');
    }
  }

  /// Calculate route between two points
  Future<List<LatLng>> calculateRoute({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
  }) async {
    try {
      return await _poiService.calculateRoute(
        start: start,
        end: end,
        waypoints: waypoints,
      );
    } catch (e) {
      _errorMessage = 'Failed to calculate route: $e';
      print(_errorMessage);
      return [];
    }
  }

  /// Helper function to encode JSON with error status handling
  static String jsonEncodeWithStatus(Map<String, dynamic> json) {
    try {
      return jsonEncode(json);
    } catch (e) {
      print('JSON encode error: $e');
      return '{}';
    }
  }

  /// Helper function to parse JSON with error status handling
  static Map<String, dynamic>? jsonParseWithStatus(String jsonStr) {
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('JSON parse error: $e');
      return null;
    }
  }

  /// Update current location and refresh nearby POIs and gas stations
  Future<void> updateLocation(LatLng location,
      {bool forceRefresh = false}) async {
    // Only refresh if location has changed significantly or forcing refresh
    if (forceRefresh || _shouldRefreshData(location)) {
      await Future.wait([
        fetchNearbyPOIs(
          location: location,
          poiTypes: [
            POIType.restArea,
            POIType.cafe,
            POIType.restaurant,
            POIType.truckStop,
            POIType.gasStation,
            POIType.hotel,
          ],
          forceRefresh: forceRefresh,
        ),
        fetchNearbyGasStations(
          location: location,
          forceRefresh: forceRefresh,
        ),
      ]);
    }
  }

  /// Determine if data should be refreshed based on location change
  bool _shouldRefreshData(LatLng newLocation) {
    // If no POIs or gas stations, definitely refresh
    if (_pois.isEmpty && _gasStations.isEmpty) return true;

    // If cache is expired, refresh
    if (_isCacheExpired) return true;

    // Otherwise, don't refresh
    return false;
  }

  /// Initialize the provider by loading from cache
  Future<void> initialize() async {
    await loadFromCache();
  }

  /// Clean up resources
  @override
  void dispose() {
    _poiService.dispose();
    _gasPriceService.dispose();
    super.dispose();
  }

  /// Set the current context for UI operations
  void setContext(BuildContext context) {
    _currentContext = context;
  }
}

// Helper methods for JSON operations - using dart:convert
