import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Types of Points of Interest
enum POIType {
  /// Gas stations
  gasStation,

  /// Rest areas
  restArea,

  /// Cafes
  cafe,

  /// Restaurants
  restaurant,

  /// Convenience stores
  convenienceStore,

  /// Truck stops
  truckStop,

  /// EV charging stations
  evCharging,

  /// Hotels/Motels
  hotel,

  /// Parking areas
  parking,

  /// Other types
  other,
}

/// Model representing a Point of Interest (POI)
class PointOfInterest {
  /// Unique identifier for the POI
  final String id;

  /// Name of the POI
  final String name;

  /// Type of POI
  final POIType type;

  /// Location coordinates of the POI
  final LatLng location;

  /// Address of the POI
  final String address;

  /// Distance from user's current location in meters
  final double? distance;

  /// Estimated duration to reach this POI in seconds
  final double? duration;

  /// Additional POI categories/tags
  final List<String>? categories;

  /// Opening hours if available
  final Map<String, String>? hours;

  /// Whether this POI is currently open
  final bool? isOpen;

  /// Phone number if available
  final String? phone;

  /// Website if available
  final String? website;

  /// Average rating if available (1-5)
  final double? rating;

  /// Available amenities at this POI
  final List<String>? amenities;

  /// Constructor
  PointOfInterest({
    required this.id,
    required this.name,
    required this.type,
    required this.location,
    required this.address,
    this.distance,
    this.duration,
    this.categories,
    this.hours,
    this.isOpen,
    this.phone,
    this.website,
    this.rating,
    this.amenities,
  });

  /// Factory constructor to create a POI from OpenRouteService API
  factory PointOfInterest.fromOpenRouteService(Map<String, dynamic> json) {
    // Extract coordinates from GeoJSON format
    final coordinates = json['geometry']['coordinates'];
    final location =
        LatLng(coordinates[1], coordinates[0]); // Note: GeoJSON uses [lng, lat]

    final properties = json['properties'];

    // Determine POI type from categories
    POIType poiType = _determinePOIType(
        properties['categories'] as List<dynamic>? ?? [],
        properties['name'] as String? ?? '');

    // Extract amenities if available
    List<String>? amenities;
    if (properties['wheelchair'] == 'yes') {
      amenities = (amenities ?? [])..add('wheelchair_accessible');
    }
    if (properties['internet_access'] == 'yes' ||
        properties['internet_access'] == 'wlan') {
      amenities = (amenities ?? [])..add('wifi');
    }

    return PointOfInterest(
      id: properties['id'] ??
          json['id'] ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: properties['name'] ?? 'Unnamed Location',
      type: poiType,
      location: location,
      address: properties['label'] ??
          properties['address_line1'] ??
          'Unknown Address',
      distance: properties['distance'] != null
          ? (properties['distance'] as num).toDouble()
          : null,
      categories: properties['categories'] != null
          ? List<String>.from(properties['categories'])
          : null,
      phone: properties['phone'],
      website: properties['website'],
      amenities: amenities,
    );
  }

  /// Helper method to determine POI type from categories and name
  static POIType _determinePOIType(List<dynamic> categories, String name) {
    final categoryStrings =
        categories.map((c) => c.toString().toLowerCase()).toList();

    // Check for gas stations
    if (categoryStrings.any((c) =>
        c.contains('fuel') ||
        c.contains('gas_station') ||
        c.contains('petrol'))) {
      return POIType.gasStation;
    }

    // Check for rest areas
    if (categoryStrings.any((c) =>
        c.contains('rest_area') ||
        c.contains('picnic') ||
        c.contains('picnic_site'))) {
      return POIType.restArea;
    }

    // Check for cafes
    if (categoryStrings
        .any((c) => c.contains('cafe') || c.contains('coffee'))) {
      return POIType.cafe;
    }

    // Check for restaurants
    if (categoryStrings
        .any((c) => c.contains('restaurant') || c.contains('food'))) {
      return POIType.restaurant;
    }

    // Check for convenience stores
    if (categoryStrings
        .any((c) => c.contains('convenience') || c.contains('shop'))) {
      return POIType.convenienceStore;
    }

    // Check for truck stops
    if (categoryStrings
            .any((c) => c.contains('truck_stop') || c.contains('truck')) ||
        name.toLowerCase().contains('truck stop')) {
      return POIType.truckStop;
    }

    // Check for EV charging
    if (categoryStrings
        .any((c) => c.contains('charging') || c.contains('ev'))) {
      return POIType.evCharging;
    }

    // Check for hotels
    if (categoryStrings.any((c) =>
        c.contains('hotel') || c.contains('motel') || c.contains('lodging'))) {
      return POIType.hotel;
    }

    // Check for parking
    if (categoryStrings.any((c) => c.contains('parking'))) {
      return POIType.parking;
    }

    // Default to other
    return POIType.other;
  }

  /// Get icon name based on POI type
  String get iconName {
    switch (type) {
      case POIType.gasStation:
        return 'gas_station';
      case POIType.restArea:
        return 'rest_area';
      case POIType.cafe:
        return 'cafe';
      case POIType.restaurant:
        return 'restaurant';
      case POIType.convenienceStore:
        return 'store';
      case POIType.truckStop:
        return 'truck_stop';
      case POIType.evCharging:
        return 'ev_charging';
      case POIType.hotel:
        return 'hotel';
      case POIType.parking:
        return 'parking';
      case POIType.other:
        return 'location';
    }
  }

  /// Convert to a map for local storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString().split('.').last,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'address': address,
      'distance': distance,
      'duration': duration,
      'categories': categories,
      'hours': hours,
      'isOpen': isOpen,
      'phone': phone,
      'website': website,
      'rating': rating,
      'amenities': amenities,
    };
  }

  /// Create a POI from local storage
  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    return PointOfInterest(
      id: json['id'],
      name: json['name'],
      type: POIType.values.firstWhere(
        (e) => e.toString() == 'POIType.${json['type']}',
        orElse: () => POIType.other,
      ),
      location: LatLng(
        json['location']['lat'],
        json['location']['lng'],
      ),
      address: json['address'],
      distance: json['distance'],
      duration: json['duration'],
      categories: json['categories'] != null
          ? List<String>.from(json['categories'])
          : null,
      hours: json['hours'] != null
          ? Map<String, String>.from(json['hours'])
          : null,
      isOpen: json['isOpen'],
      phone: json['phone'],
      website: json['website'],
      rating: json['rating'],
      amenities: json['amenities'] != null
          ? List<String>.from(json['amenities'])
          : null,
    );
  }
}
