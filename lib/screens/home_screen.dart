import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../providers/location_provider.dart';
import '../providers/session_provider.dart';
import '../providers/forecast_provider.dart';
import '../providers/heatmap_provider.dart';
import '../providers/event_provider.dart';
import '../providers/poi_provider.dart';
import '../models/poi_filter.dart';
import '../models/point_of_interest.dart';
import '../widgets/demand_forecast_chart.dart';
import '../widgets/poi_filter_sheet.dart';
import '../utils/page_transitions.dart';
import '../utils/session_security.dart';
import 'login_screen.dart';
import 'forecasts_screen.dart';
import 'events_screen.dart';
import 'profile_screen.dart';
import '../providers/auth_provider.dart';
import '../widgets/route_planner_sheet.dart';
import '../widgets/poi_details_sheet.dart';
import '../services/navigation_service.dart';
import 'fatigue_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isMapCreated = false;
  String? _mapError;
  bool _isLoading = true;
  MapType _currentMapType = MapType.normal;

  // Session security manager instance
  SessionSecurityManager? _sessionSecurityManager;

  // User activity timer
  bool _activityTrackerInitialized = false;

  // Add Google Maps styles for night mode
  static const String _mapStyle = '''
  [
    {
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#242f3e"
        }
      ]
    },
    {
      "featureType": "administrative.locality",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#263c3f"
        }
      ]
    },
    {
      "featureType": "poi.park",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#6b9a76"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#38414e"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#212a37"
        }
      ]
    },
    {
      "featureType": "road",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#9ca5b3"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#746855"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "geometry.stroke",
      "stylers": [
        {
          "color": "#1f2835"
        }
      ]
    },
    {
      "featureType": "road.highway",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#f3d19c"
        }
      ]
    },
    {
      "featureType": "transit",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#2f3948"
        }
      ]
    },
    {
      "featureType": "transit.station",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#d59563"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "geometry",
      "stylers": [
        {
          "color": "#17263c"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.fill",
      "stylers": [
        {
          "color": "#515c6d"
        }
      ]
    },
    {
      "featureType": "water",
      "elementType": "labels.text.stroke",
      "stylers": [
        {
          "color": "#17263c"
        }
      ]
    }
  ]
  ''';

  bool _isDarkMode = false;
  bool _isTrafficEnabled = false;
  CameraPosition? _lastCameraPosition;
  bool _isPOILayerVisible = true;

  @override
  void initState() {
    super.initState();
    _initializeLocation();

    // Initialize event system
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().initialize();
      context.read<POIProvider>().setContext(context);
      _initializeSessionSecurity();
    });
  }

  // Initialize session security manager
  void _initializeSessionSecurity() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);

    // Initialize session security manager
    _sessionSecurityManager = SessionSecurityManager(
      authProvider: authProvider,
      sessionProvider: sessionProvider,
      onSessionExpired: _handleSessionExpired,
      onSessionWarning: _handleSessionWarning,
    );

    // Set the context for showing dialogs
    _sessionSecurityManager!.setContext(context);

    // Setup activity tracking
    if (!_activityTrackerInitialized) {
      _setupActivityTracking();
      _activityTrackerInitialized = true;
    }
  }

  // Setup activity tracking to record user interactions
  void _setupActivityTracking() {
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);

    // Record activity for initial load
    sessionProvider.recordUserActivity();
  }

  // Handle session expiration
  void _handleSessionExpired() {
    // This will be called by the session security manager
    // Navigation to login screen handled by the manager
  }

  // Handle session warning
  void _handleSessionWarning() {
    // This will be called by the session security manager
    // Warning dialog handled by the manager
  }

  Future<void> _initializeLocation() async {
    try {
      setState(() => _isLoading = true);
      await context.read<LocationProvider>().initializeLocation();

      // Initialize the heatmap after location is available
      final position = context.read<LocationProvider>().currentPosition;
      if (position != null) {
        await context.read<HeatmapProvider>().updateHeatmapForLocation(
              LatLng(position.latitude, position.longitude),
            );
      }

      _updateMapLocation();
    } catch (e) {
      setState(() {
        _mapError = 'Failed to initialize location: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapError!),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _initializeLocation,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateMapLocation() {
    final location = context.read<LocationProvider>().currentPosition;
    if (location != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(location.latitude, location.longitude),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final sessionProvider =
        Provider.of<SessionProvider>(context, listen: false);

    // First end any active session
    if (sessionProvider.isSessionActive) {
      await sessionProvider.endSession();
    }

    // Then sign out the user
    await authProvider.signOut();

    // Clear user data from session provider
    await sessionProvider.clearUser();

    // Navigate back to login screen
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _signOut,
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _handleMapTap(LatLng position) {
    final heatmapProvider = context.read<HeatmapProvider>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Hotspot'),
        content:
            const Text('Do you want to add a demand hotspot at this location?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              heatmapProvider.addHotspot(position);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Hotspot added'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _toggleTraffic() {
    setState(() {
      _isTrafficEnabled = !_isTrafficEnabled;
    });
  }

  void _toggleDarkMode() {
    setState(() {
      _isDarkMode = !_isDarkMode;
    });

    if (_mapController != null) {
      _mapController!.setMapStyle(_isDarkMode ? _mapStyle : null);
    }
  }

  void _zoomIn() {
    if (_mapController != null && _lastCameraPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.zoomTo((_lastCameraPosition!.zoom + 1).clamp(1.0, 20.0)),
      );
    }
  }

  void _zoomOut() {
    if (_mapController != null && _lastCameraPosition != null) {
      _mapController!.animateCamera(
        CameraUpdate.zoomTo((_lastCameraPosition!.zoom - 1).clamp(1.0, 20.0)),
      );
    }
  }

  void _centerOnLocation() {
    final location = context.read<LocationProvider>().currentPosition;
    if (location != null && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(location.latitude, location.longitude),
          15,
        ),
      );
    }
  }

  void _handleCameraMove(CameraPosition position) {
    _lastCameraPosition = position;
  }

  Widget _buildMapError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            _mapError ?? 'Failed to load map',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _initializeLocation,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading map...'),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    final locationProvider = context.watch<LocationProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final forecastProvider = context.watch<ForecastProvider>();
    final heatmapProvider = context.watch<HeatmapProvider>();
    final eventProvider = context.watch<EventProvider>();
    final poiProvider = context.watch<POIProvider>();

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(
              locationProvider.currentPosition?.latitude ?? 37.7749,
              locationProvider.currentPosition?.longitude ?? -122.4194,
            ),
            zoom: 15,
          ),
          onMapCreated: (controller) {
            setState(() {
              _mapController = controller;
              _isMapCreated = true;
            });
            _updateMapLocation();

            // Set the map ID for heatmap
            heatmapProvider.setMapId(controller.mapId.toString());

            // Apply night mode if enabled
            if (_isDarkMode) {
              controller.setMapStyle(_mapStyle);
            }

            // Update POIs for the current location
            if (locationProvider.currentPosition != null) {
              poiProvider.updateLocation(
                LatLng(
                  locationProvider.currentPosition!.latitude,
                  locationProvider.currentPosition!.longitude,
                ),
              );
            }
          },
          onTap: _handleMapTap,
          onCameraMove: _handleCameraMove,
          markers: {
            ..._markers,
            ...heatmapProvider.hotspotMarkers,
            ...poiProvider.allMarkers,
          },
          circles: heatmapProvider.heatmapCircles,
          myLocationEnabled: true,
          myLocationButtonEnabled: false, // We'll provide our own button
          compassEnabled: true,
          mapToolbarEnabled: true,
          zoomControlsEnabled: false, // We'll provide our own controls
          mapType: _currentMapType,
          trafficEnabled: _isTrafficEnabled,
        ),
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'toggleMapType',
                mini: true,
                onPressed: _toggleMapType,
                child: Icon(
                  _currentMapType == MapType.normal
                      ? Icons.satellite_alt
                      : Icons.map,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'toggleHeatmap',
                mini: true,
                onPressed: () {
                  heatmapProvider.toggleHeatmapVisibility();
                },
                child: Icon(
                  heatmapProvider.isHeatmapVisible
                      ? Icons.layers
                      : Icons.layers_clear,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'togglePOI',
                mini: true,
                onPressed: () {
                  setState(() {
                    _isPOILayerVisible = !_isPOILayerVisible;
                  });
                  poiProvider.toggleMarkerVisibility();
                },
                child: Icon(
                  _isPOILayerVisible ? Icons.location_on : Icons.location_off,
                  color: _isPOILayerVisible ? Colors.green : null,
                ),
                tooltip: 'Toggle POI Visibility',
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'toggleTraffic',
                mini: true,
                onPressed: _toggleTraffic,
                child: Icon(
                  _isTrafficEnabled ? Icons.traffic : Icons.traffic,
                  color: _isTrafficEnabled ? Colors.red : null,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'toggleDarkMode',
                mini: true,
                onPressed: _toggleDarkMode,
                child: Icon(
                  _isDarkMode ? Icons.wb_sunny : Icons.nightlight_round,
                ),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'refreshHeatmap',
                mini: true,
                onPressed: () {
                  final position = locationProvider.currentPosition;
                  if (position != null) {
                    heatmapProvider.updateHeatmapForLocation(
                      LatLng(position.latitude, position.longitude),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Heatmap updated'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                child: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                heroTag: 'zoomIn',
                mini: true,
                onPressed: _zoomIn,
                child: const Icon(Icons.add),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'zoomOut',
                mini: true,
                onPressed: _zoomOut,
                child: const Icon(Icons.remove),
              ),
              const SizedBox(height: 8),
              FloatingActionButton(
                heroTag: 'centerLocation',
                onPressed: _centerOnLocation,
                child: const Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 16,
          left: 16,
          child: Column(
            children: [
              Stack(
                children: [
                  FloatingActionButton(
                    heroTag: 'filterPOI',
                    mini: true,
                    onPressed: _showPOIFilter,
                    tooltip: 'Filter POIs',
                    child: const Icon(Icons.filter_alt),
                  ),
                  Consumer<POIProvider>(
                    builder: (context, poiProvider, child) {
                      // Check if a filter is active (not all POI types selected)
                      final isFilterActive =
                          poiProvider.activeFilter.includedTypes != null &&
                              poiProvider.activeFilter.includedTypes!.length <
                                  POIType.values.length -
                                      1; // Exclude 'other' type

                      if (isFilterActive) {
                        return Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'routePlanner',
                onPressed: _showRoutePlanner,
                icon: const Icon(Icons.route),
                label: const Text('Plan Route'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showRoutePlanner() {
    final poiProvider = context.read<POIProvider>();
    final locationProvider = context.read<LocationProvider>();

    // Use a dialog for full screen route planner instead of a bottom sheet
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Plan Your Route'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: RoutePlannerSheet(
              onRouteCalculated: (route) {
                // Draw the route on the map
                print('Route calculated with ${route.length} points');
                // Close the dialog after route is calculated
                Navigator.pop(context);
              },
              onPOIsFound: (pois) {
                // Show POIs on the map
                print('Found ${pois.length} POIs along route');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Found ${pois.length} points of interest'),
                    duration: const Duration(seconds: 3),
                  ),
                );
                // Close the dialog after POIs are found
                Navigator.pop(context);
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showPOIFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: POIFilterSheet(
          onFilterUpdated: () {
            // Show a confirmation message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('POI filters updated'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<LocationProvider>();
    final sessionProvider = context.watch<SessionProvider>();
    final forecastProvider = context.watch<ForecastProvider>();
    final heatmapProvider = context.watch<HeatmapProvider>();
    final eventProvider = context.watch<EventProvider>();

    // Record user activity on each build to keep session alive
    sessionProvider.recordUserActivity();

    return Scaffold(
      appBar: AppBar(
        title: const Text('LitStop'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.of(context).push(
                PageTransitions.slideRight(const ProfileScreen()),
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications),
                tooltip: 'Events',
                onPressed: () async {
                  final result = await Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const EventsScreen()),
                  );

                  // If we get back a LatLng, it means the user tapped on a location
                  // and we should add a hotspot there
                  if (result is LatLng) {
                    heatmapProvider.addHotspot(result);
                  }
                },
              ),
              if (eventProvider.hasUnreadEvents)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${eventProvider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Demand Forecasts',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const ForecastsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Test Fatigue System',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const FatigueTestScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: Navigate to session history
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? _buildLoadingIndicator()
                : _mapError != null
                    ? _buildMapError()
                    : _buildMapContent(),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        if (!sessionProvider.isSessionActive) {
                          sessionProvider.startSession();
                        } else {
                          sessionProvider.endSession();
                        }
                      },
                      icon: Icon(
                        !sessionProvider.isSessionActive
                            ? Icons.play_arrow
                            : Icons.stop,
                      ),
                      label: Text(
                        !sessionProvider.isSessionActive
                            ? 'Start Session'
                            : 'End Session',
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Rest mode functionality will be implemented later
                      },
                      icon: const Icon(Icons.bedtime),
                      label: const Text('Rest Mode'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'Session Duration: ${sessionProvider.formattedSessionTime}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Total Rides: ${sessionProvider.totalRides}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Estimated Earnings: \$${sessionProvider.totalEarnings.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove activity tracking listener
    GestureBinding.instance.pointerRouter
        .removeGlobalRoute((PointerEvent event) {});
    // Clean up the session security manager
    _sessionSecurityManager?.dispose();
    _mapController?.dispose();
    super.dispose();
  }
}
