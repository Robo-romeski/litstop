import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/point_of_interest.dart';
import '../models/gas_station.dart';

/// A bottom sheet that displays details about a POI or gas station
class POIDetailsSheet extends StatelessWidget {
  /// The POI to display, if any
  final PointOfInterest? poi;

  /// The gas station to display, if any
  final GasStation? gasStation;

  /// Callback when the user wants to navigate to this location
  final Function(LatLng)? onNavigate;

  /// Constructor for POI details
  const POIDetailsSheet.fromPOI({
    super.key,
    required PointOfInterest this.poi,
    this.gasStation,
    this.onNavigate,
  });

  /// Constructor for gas station details
  const POIDetailsSheet.fromGasStation({
    super.key,
    required GasStation this.gasStation,
    this.poi,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGasStation = gasStation != null;
    final String title = isGasStation ? gasStation!.name : poi!.name;
    final LatLng location = isGasStation ? gasStation!.location : poi!.location;
    final String address = isGasStation ? gasStation!.address : poi!.address;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isGasStation ? Icons.local_gas_station : _getIconForPOI(),
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                isGasStation ? 'Gas Station' : _getTypeLabel(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  address,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (isGasStation) _buildGasStationDetails(context),
          if (!isGasStation && poi != null) _buildPOIDetails(context),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (onNavigate != null) {
                    onNavigate!(location);
                  }
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.directions),
                label: const Text('Navigate'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  // TODO: Implement save to favorites
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Saved to favorites'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.favorite_border),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.secondary,
                  foregroundColor: Theme.of(context).colorScheme.onSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGasStationDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Fuel Prices',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (gasStation!.prices.isEmpty)
          const Text('Price information not available'),
        if (gasStation!.hasFuelType(FuelType.regular))
          _buildPriceRow('Regular', gasStation!.prices[FuelType.regular]!),
        if (gasStation!.hasFuelType(FuelType.midGrade))
          _buildPriceRow('Mid-Grade', gasStation!.prices[FuelType.midGrade]!),
        if (gasStation!.hasFuelType(FuelType.premium))
          _buildPriceRow('Premium', gasStation!.prices[FuelType.premium]!),
        if (gasStation!.hasFuelType(FuelType.diesel))
          _buildPriceRow('Diesel', gasStation!.prices[FuelType.diesel]!),
        const SizedBox(height: 8),
        Text(
          'Last Updated: ${_formatDate(gasStation!.lastUpdated)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (gasStation!.brand != null) ...[
          const SizedBox(height: 8),
          Text('Brand: ${gasStation!.brand!}'),
        ],
        if (gasStation!.distance != null) ...[
          const SizedBox(height: 4),
          Text('Distance: ${gasStation!.distance!.toStringAsFixed(1)} miles'),
        ],
      ],
    );
  }

  Widget _buildPOIDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        if (poi!.categories != null && poi!.categories!.isNotEmpty) ...[
          const Text(
            'Categories',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: poi!.categories!
                .map((cat) => Chip(
                      label: Text(cat),
                      padding: const EdgeInsets.all(4),
                      labelStyle: const TextStyle(fontSize: 12),
                    ))
                .toList(),
          ),
        ],
        if (poi!.distance != null) ...[
          const SizedBox(height: 8),
          Text('Distance: ${(poi!.distance! / 1000).toStringAsFixed(1)} km'),
        ],
        if (poi!.amenities != null && poi!.amenities!.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'Amenities',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          ...poi!.amenities!.map((amenity) => Row(
                children: [
                  const Icon(Icons.check, size: 16),
                  const SizedBox(width: 4),
                  Text(_formatAmenity(amenity)),
                ],
              )),
        ],
        if (poi!.phone != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone, size: 16),
              const SizedBox(width: 4),
              Text(poi!.phone!),
            ],
          ),
        ],
        if (poi!.website != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.language, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  poi!.website!,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPriceRow(String label, double price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '\$${price.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inMinutes} minutes ago';
    }
  }

  String _formatAmenity(String amenity) {
    // Convert snake_case to Title Case
    return amenity
        .split('_')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1)}'
            : '')
        .join(' ');
  }

  IconData _getIconForPOI() {
    if (poi == null) return Icons.location_on;

    switch (poi!.type) {
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

  String _getTypeLabel() {
    if (poi == null) return 'Location';

    switch (poi!.type) {
      case POIType.gasStation:
        return 'Gas Station';
      case POIType.restArea:
        return 'Rest Area';
      case POIType.cafe:
        return 'Café';
      case POIType.restaurant:
        return 'Restaurant';
      case POIType.convenienceStore:
        return 'Convenience Store';
      case POIType.truckStop:
        return 'Truck Stop';
      case POIType.evCharging:
        return 'EV Charging Station';
      case POIType.hotel:
        return 'Hotel/Motel';
      case POIType.parking:
        return 'Parking Area';
      case POIType.other:
        return 'Point of Interest';
      default:
        return 'Location';
    }
  }
}
