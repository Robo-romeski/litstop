import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../providers/location_provider.dart';
import '../providers/poi_provider.dart';
import '../models/point_of_interest.dart';
import '../services/place_service.dart';

/// A widget for planning routes and finding POIs along the way
class RoutePlannerSheet extends StatefulWidget {
  /// Callback when a route is calculated
  final Function(List<LatLng>)? onRouteCalculated;

  /// Callback when POIs are found along a route
  final Function(List<PointOfInterest>)? onPOIsFound;

  /// Constructor
  const RoutePlannerSheet({
    super.key,
    this.onRouteCalculated,
    this.onPOIsFound,
  });

  @override
  State<RoutePlannerSheet> createState() => _RoutePlannerSheetState();
}

class _RoutePlannerSheetState extends State<RoutePlannerSheet> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();
  final PlaceService _placeService = PlaceService();

  LatLng? _startLocation;
  LatLng? _endLocation;
  bool _useCurrentLocationAsStart = true;
  bool _isLoading = false;
  String? _error;
  String? _selectedPlaceId;

  List<POIType> _selectedPOITypes = [
    POIType.gasStation,
    POIType.restArea,
  ];

  @override
  void initState() {
    super.initState();

    // Initialize with current location
    final locationProvider = context.read<LocationProvider>();
    if (locationProvider.currentPosition != null) {
      _startLocation = LatLng(
        locationProvider.currentPosition!.latitude,
        locationProvider.currentPosition!.longitude,
      );
      _startController.text = 'Current Location';
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Remove container decoration since it will be in a full-screen dialog
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Remove the header row since it's handled by the dialog AppBar

        const SizedBox(height: 16),
        _buildLocationFields(),
        const SizedBox(height: 24),
        _buildPOITypeSelection(),
        const SizedBox(height: 24),
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50, // Taller button
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _findPOIs,
            icon: const Icon(Icons.search),
            label: _isLoading
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('Finding POIs...'),
                    ],
                  )
                : const Text('Find POIs Along Route'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Route Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Checkbox(
              value: _useCurrentLocationAsStart,
              onChanged: (value) {
                setState(() {
                  _useCurrentLocationAsStart = value ?? true;
                  if (_useCurrentLocationAsStart) {
                    final locationProvider = context.read<LocationProvider>();
                    if (locationProvider.currentPosition != null) {
                      _startLocation = LatLng(
                        locationProvider.currentPosition!.latitude,
                        locationProvider.currentPosition!.longitude,
                      );
                      _startController.text = 'Current Location';
                    }
                  } else {
                    _startController.clear();
                    _startLocation = null;
                  }
                });
              },
            ),
            const Text('Use current location as start'),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _startController,
          focusNode: _startFocusNode,
          decoration: InputDecoration(
            labelText: 'Start Location',
            hintText: 'Enter starting location',
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.location_on),
            enabled: !_useCurrentLocationAsStart,
            filled: true,
            fillColor: _useCurrentLocationAsStart
                ? Colors.grey.shade200
                : Theme.of(context).inputDecorationTheme.fillColor,
          ),
          enabled: !_useCurrentLocationAsStart,
        ),
        const SizedBox(height: 16),
        // Destination field with TypeAhead
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TypeAheadField<PlaceSuggestion>(
              textFieldConfiguration: TextFieldConfiguration(
                controller: _endController,
                focusNode: _endFocusNode,
                decoration: InputDecoration(
                  labelText: 'Destination',
                  hintText: 'Enter destination (city, address)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                  filled: true,
                  helperText: _endLocation != null
                      ? 'Location selected ✓'
                      : 'Type at least 1 character to search',
                  helperStyle: TextStyle(
                    color:
                        _endLocation != null ? Colors.green : Colors.grey[600],
                    fontWeight: _endLocation != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                onChanged: (value) {
                  // Clear the selected location if user changes the text
                  if (_endLocation != null && value != _endController.text) {
                    setState(() {
                      _endLocation = null;
                      _selectedPlaceId = null;
                    });
                  }
                },
              ),
              suggestionsCallback: (pattern) async {
                // Allow search with just 1 character
                if (pattern.isEmpty) {
                  return [];
                }
                try {
                  final suggestions =
                      await _placeService.getPlaceSuggestions(pattern);
                  print('Got ${suggestions.length} suggestions for "$pattern"');
                  return suggestions;
                } catch (e) {
                  print('Error getting suggestions: $e');
                  return [];
                }
              },
              itemBuilder: (context, suggestion) {
                return ListTile(
                  leading: const Icon(Icons.location_on),
                  title: Text(suggestion.description),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                );
              },
              onSuggestionSelected: (suggestion) async {
                print('Selected suggestion: ${suggestion.description}');
                setState(() {
                  _endController.text = suggestion.description;
                  _selectedPlaceId = suggestion.placeId;
                  _error = null;
                });

                // Visual feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected: ${suggestion.description}'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: Colors.green,
                  ),
                );

                // Show loading indicator
                setState(() {
                  _isLoading = true;
                });

                // Get place details to get the coordinates
                try {
                  final place =
                      await _placeService.getPlaceDetails(suggestion.placeId);

                  // Check if still mounted before updating state
                  if (!mounted) return;

                  setState(() {
                    _endLocation = place.location;
                    _error = null; // Clear any previous errors
                    _isLoading = false;
                  });
                  print(
                      'Location set: ${place.location.latitude}, ${place.location.longitude}');

                  // Show a confirmation dialog
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Location Selected'),
                        content: Text(
                            'Destination set to ${suggestion.description}.\n\nCoordinates: ${place.location.latitude.toStringAsFixed(4)}, ${place.location.longitude.toStringAsFixed(4)}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                } catch (e) {
                  print('Error getting place details: $e');
                  if (mounted) {
                    setState(() {
                      _error = 'Error getting location details: $e';
                      _isLoading = false;
                    });

                    // Show error dialog
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Error'),
                        content: Text('Failed to get location details: $e'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              suggestionsBoxDecoration: SuggestionsBoxDecoration(
                borderRadius: BorderRadius.circular(8),
                elevation: 8.0, // Increased elevation for better visibility
                color: Theme.of(context).cardColor,
                shadowColor: Colors.black54,
                constraints: const BoxConstraints(
                    maxHeight: 300), // Allow for more visible suggestions
              ),
              debounceDuration:
                  const Duration(milliseconds: 200), // Quicker response
              hideOnEmpty: false,
              hideOnLoading: false,
              hideOnError: false,
              keepSuggestionsOnLoading: true,
              animationDuration: const Duration(milliseconds: 300),
              noItemsFoundBuilder: (context) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No locations found',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try entering a city name like "New York" or "San Francisco"',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
              loadingBuilder: (context) => Container(
                height: 60,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Finding locations...'),
                  ],
                ),
              ),
              errorBuilder: (context, error) => Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error: $error',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
            if (_endLocation != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Card(
                  color: Colors.green[50],
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.green[300]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Destination coordinates: ${_endLocation!.latitude.toStringAsFixed(4)}, ${_endLocation!.longitude.toStringAsFixed(4)}',
                            style: TextStyle(
                              color: Colors.green[900],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPOITypeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What to find along the way:',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildPOITypeChip(POIType.gasStation, 'Gas Stations'),
            _buildPOITypeChip(POIType.restArea, 'Rest Areas'),
            _buildPOITypeChip(POIType.restaurant, 'Food'),
            _buildPOITypeChip(POIType.hotel, 'Lodging'),
            _buildPOITypeChip(POIType.cafe, 'Cafes'),
            _buildPOITypeChip(POIType.convenienceStore, 'Stores'),
          ],
        ),
      ],
    );
  }

  Widget _buildPOITypeChip(POIType type, String label) {
    final bool isSelected = _selectedPOITypes.contains(type);

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      avatar: Icon(
        _getIconForType(type),
        size: 18,
        color: isSelected ? Colors.white : null,
      ),
      selectedColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      labelStyle: TextStyle(
        color:
            isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
      ),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedPOITypes.add(type);
          } else {
            _selectedPOITypes.remove(type);
          }
        });
      },
    );
  }

  IconData _getIconForType(POIType type) {
    switch (type) {
      case POIType.gasStation:
        return Icons.local_gas_station;
      case POIType.restArea:
        return Icons.airline_seat_individual_suite;
      case POIType.cafe:
        return Icons.coffee;
      case POIType.restaurant:
        return Icons.restaurant;
      case POIType.convenienceStore:
        return Icons.store;
      case POIType.truckStop:
        return Icons.local_shipping;
      case POIType.evCharging:
        return Icons.electrical_services;
      case POIType.hotel:
        return Icons.hotel;
      case POIType.parking:
        return Icons.local_parking;
      case POIType.other:
        return Icons.location_on;
      default:
        return Icons.location_on;
    }
  }

  Future<void> _findPOIs() async {
    // Validate inputs
    if (_startLocation == null) {
      setState(() {
        _error = 'Please select a start location';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a start location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_endLocation == null) {
      setState(() {
        _error = 'Please enter a destination';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please enter and select a destination from the dropdown'),
          backgroundColor: Colors.red,
        ),
      );
      print(
          'End location is null. End controller text: ${_endController.text}, Selected place ID: $_selectedPlaceId');
      return;
    }

    if (_selectedPOITypes.isEmpty) {
      setState(() {
        _error = 'Please select at least one type of place to find';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one type of place to find'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check mounted before setState
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print(
          'Starting route calculation from ${_startLocation!.latitude},${_startLocation!.longitude} ' +
              'to ${_endLocation!.latitude},${_endLocation!.longitude}');

      final poiProvider = context.read<POIProvider>();

      // Calculate route
      final route = await poiProvider.calculateRoute(
        start: _startLocation!,
        end: _endLocation!,
      );

      // Check mounted before continuing after async operation
      if (!mounted) return;

      if (route.isEmpty) {
        setState(() {
          _error = 'Failed to calculate route';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to calculate route - please try different locations'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      print('Route calculated successfully with ${route.length} points');

      // Notify about the calculated route
      if (widget.onRouteCalculated != null) {
        widget.onRouteCalculated!(route);
      }

      // Check mounted before continuing after callback
      if (!mounted) return;

      print(
          'Finding POIs along route for types: ${_selectedPOITypes.map((t) => t.toString()).join(', ')}');

      // Find POIs along route
      final pois = await poiProvider.findPOIsAlongRoute(
        start: _startLocation!,
        end: _endLocation!,
        poiTypes: _selectedPOITypes,
      );

      // Check mounted before continuing after async operation
      if (!mounted) return;

      print('Found ${pois.length} POIs along route');

      if (pois.isEmpty) {
        setState(() {
          _error = 'No points of interest found along this route';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No points of interest found - try different POI types or a different route'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Notify about found POIs
      if (widget.onPOIsFound != null && mounted) {
        widget.onPOIsFound!(pois);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${pois.length} places along your route'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Don't close the sheet - this is now handled in the home_screen
    } catch (e) {
      print('Error in _findPOIs: $e');
      // Check mounted before setState
      if (!mounted) return;

      setState(() {
        _error = 'Error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error finding POIs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Check mounted before setState in finally block
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
