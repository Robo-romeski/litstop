import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poi_filter.dart';
import '../models/point_of_interest.dart';
import '../providers/poi_provider.dart';

/// A bottom sheet for filtering POIs on the map
class POIFilterSheet extends StatefulWidget {
  /// Callback when filter is updated
  final VoidCallback? onFilterUpdated;

  /// Constructor
  const POIFilterSheet({super.key, this.onFilterUpdated});

  @override
  State<POIFilterSheet> createState() => _POIFilterSheetState();
}

class _POIFilterSheetState extends State<POIFilterSheet> {
  // Selected POI types
  final Map<POIType, bool> _selectedTypes = {
    POIType.gasStation: true,
    POIType.restArea: true,
    POIType.cafe: true,
    POIType.restaurant: true,
    POIType.hotel: true,
    POIType.truckStop: true,
    POIType.evCharging: true,
    POIType.convenienceStore: true,
    POIType.parking: true,
  };

  // Current distance radius in km
  double _currentDistanceRadius = 5.0; // Default 5km

  // Maximum distance for the slider in km
  static const double _maxDistance = 50.0; // 50km max

  @override
  void initState() {
    super.initState();
    _loadCurrentFilter();
  }

  // Load the current filter from the provider
  void _loadCurrentFilter() {
    final poiProvider = Provider.of<POIProvider>(context, listen: false);
    final currentFilter = poiProvider.activeFilter;

    // If there are included types, update our selections
    if (currentFilter.includedTypes != null &&
        currentFilter.includedTypes!.isNotEmpty) {
      // Reset all to false first
      _selectedTypes.updateAll((key, value) => false);

      // Set selected types to true
      for (final type in currentFilter.includedTypes!) {
        _selectedTypes[type] = true;
      }
    }

    // Set distance if it exists
    if (currentFilter.maxDistance != null) {
      _currentDistanceRadius =
          currentFilter.maxDistance! / 1000; // Convert to km
    }
  }

  // Apply the current filter
  void _applyFilter() {
    final poiProvider = Provider.of<POIProvider>(context, listen: false);

    // Get selected types
    final List<POIType> selectedTypes = _selectedTypes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    // Create the filter
    final filter = POIFilter(
      includedTypes: selectedTypes,
      maxDistance: _currentDistanceRadius * 1000, // Convert km to meters
    );

    // Apply the filter
    poiProvider.activeFilter = filter;
    poiProvider.searchRadius =
        (_currentDistanceRadius * 1000).toInt(); // Convert to meters

    // Call the callback if provided
    if (widget.onFilterUpdated != null) {
      widget.onFilterUpdated!();
    }

    // Close the bottom sheet
    Navigator.of(context).pop();
  }

  // Reset to default filter (all types, 5km radius)
  void _resetFilter() {
    setState(() {
      _selectedTypes.updateAll((key, value) => true);
      _currentDistanceRadius = 5.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter POIs',
                style: theme.textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),

          // POI Type Selection
          Text(
            'POI Types',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Filter chips for POI types
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedTypes.entries.map((entry) {
              return FilterChip(
                label: Text(_getPoiTypeLabel(entry.key)),
                selected: entry.value,
                onSelected: (selected) {
                  setState(() {
                    _selectedTypes[entry.key] = selected;
                  });
                },
                avatar: Icon(_getPoiTypeIcon(entry.key)),
                showCheckmark: false,
                selectedColor: _getPoiTypeColor(entry.key).withOpacity(0.7),
                backgroundColor: theme.cardColor,
                side: BorderSide(
                  color: entry.value
                      ? _getPoiTypeColor(entry.key)
                      : theme.dividerColor,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Distance Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Maximum Distance',
                style: theme.textTheme.titleMedium,
              ),
              Text(
                '${_currentDistanceRadius.toStringAsFixed(0)} km',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
          Slider(
            value: _currentDistanceRadius,
            min: 1.0,
            max: _maxDistance,
            divisions: _maxDistance.toInt() - 1,
            label: '${_currentDistanceRadius.toStringAsFixed(0)} km',
            onChanged: (value) {
              setState(() {
                _currentDistanceRadius = value;
              });
            },
          ),

          const SizedBox(height: 16),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
                onPressed: _resetFilter,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Apply'),
                onPressed: _applyFilter,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Get a human-readable label for POI type
  String _getPoiTypeLabel(POIType type) {
    switch (type) {
      case POIType.gasStation:
        return 'Gas';
      case POIType.restArea:
        return 'Rest Area';
      case POIType.cafe:
        return 'Café';
      case POIType.restaurant:
        return 'Restaurant';
      case POIType.convenienceStore:
        return 'Store';
      case POIType.truckStop:
        return 'Truck Stop';
      case POIType.evCharging:
        return 'EV Charging';
      case POIType.hotel:
        return 'Hotel';
      case POIType.parking:
        return 'Parking';
      case POIType.other:
        return 'Other';
      default:
        return 'Unknown';
    }
  }

  // Get an icon for POI type
  IconData _getPoiTypeIcon(POIType type) {
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
        return Icons.help;
    }
  }

  // Get a color for POI type
  Color _getPoiTypeColor(POIType type) {
    switch (type) {
      case POIType.gasStation:
        return Colors.red;
      case POIType.restArea:
        return Colors.blue;
      case POIType.cafe:
        return Colors.purple;
      case POIType.restaurant:
        return Colors.orange;
      case POIType.convenienceStore:
        return Colors.pink;
      case POIType.truckStop:
        return Colors.indigo;
      case POIType.evCharging:
        return Colors.green;
      case POIType.hotel:
        return Colors.lightBlue;
      case POIType.parking:
        return Colors.cyan;
      case POIType.other:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
