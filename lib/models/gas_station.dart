import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Types of gas/fuel
enum FuelType {
  regular,
  midGrade,
  premium,
  diesel,
}

/// Model representing a gas station with pricing information
class GasStation {
  /// Unique identifier for the gas station
  final String id;

  /// Name of the gas station
  final String name;

  /// Location coordinates of the gas station
  final LatLng location;

  /// Address of the gas station
  final String address;

  /// The state where this gas station is located
  final String state;

  /// City or metro area where this gas station is located
  final String? city;

  /// Map of fuel types to their prices
  final Map<FuelType, double> prices;

  /// Distance from user's current location in miles
  final double? distance;

  /// When the price data was last updated
  final DateTime lastUpdated;

  /// Brand of the gas station (Shell, BP, etc.)
  final String? brand;

  /// Additional amenities available at this station (convenience store, car wash, etc.)
  final List<String>? amenities;

  /// Whether this station is currently open
  final bool? isOpen;

  /// Opening hours if available
  final Map<String, String>? hours;

  /// Constructor
  GasStation({
    required this.id,
    required this.name,
    required this.location,
    required this.address,
    required this.state,
    this.city,
    required this.prices,
    this.distance,
    required this.lastUpdated,
    this.brand,
    this.amenities,
    this.isOpen,
    this.hours,
  });

  /// Factory constructor to create a GasStation from Zyla API response
  factory GasStation.fromZylaApi(Map<String, dynamic> json,
      {String? stateCode}) {
    // Initialize prices map
    Map<FuelType, double> prices = {};

    // Parse price strings into doubles
    if (json['prices'] != null) {
      final priceData = json['prices'];
      if (priceData['regular'] != null) {
        prices[FuelType.regular] = _parsePriceString(priceData['regular']);
      }
      if (priceData['mid-grade'] != null) {
        prices[FuelType.midGrade] = _parsePriceString(priceData['mid-grade']);
      }
      if (priceData['premium'] != null) {
        prices[FuelType.premium] = _parsePriceString(priceData['premium']);
      }
      if (priceData['diesel'] != null) {
        prices[FuelType.diesel] = _parsePriceString(priceData['diesel']);
      }
    }

    return GasStation(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? 'Unknown Station',
      location: LatLng(
        (json['location']?['lat'] as num?)?.toDouble() ?? 0.0,
        (json['location']?['lng'] as num?)?.toDouble() ?? 0.0,
      ),
      address: json['address'] ?? 'Unknown Address',
      state: stateCode ?? json['state'] ?? 'Unknown',
      city: json['city'],
      prices: prices,
      lastUpdated:
          json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      brand: json['brand'],
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
    );
  }

  /// Helper method to parse price strings like "$3.45" into doubles
  static double _parsePriceString(String priceStr) {
    // Remove dollar sign and convert to double
    return double.parse(priceStr.replaceAll('\$', ''));
  }

  /// Get the price for a specific fuel type
  double? getPriceForType(FuelType type) {
    return prices[type];
  }

  /// Get the regular gas price (convenience method)
  double? get regularPrice => prices[FuelType.regular];

  /// Check if this station has a specific fuel type available
  bool hasFuelType(FuelType type) {
    return prices.containsKey(type) && prices[type] != null;
  }

  /// Convert to a map for local storage
  Map<String, dynamic> toJson() {
    Map<String, dynamic> pricesJson = {};
    prices.forEach((key, value) {
      pricesJson[key.toString().split('.').last] = value;
    });

    return {
      'id': id,
      'name': name,
      'location': {
        'lat': location.latitude,
        'lng': location.longitude,
      },
      'address': address,
      'state': state,
      'city': city,
      'prices': pricesJson,
      'lastUpdated': lastUpdated.toIso8601String(),
      'brand': brand,
      'distance': distance,
      'amenities': amenities,
      'isOpen': isOpen,
      'hours': hours,
    };
  }

  /// Create a gas station from local storage JSON
  factory GasStation.fromJson(Map<String, dynamic> json) {
    // Parse pricing data
    final pricesMap = <FuelType, double>{};
    if (json['prices'] != null) {
      final pricesJson = json['prices'] as Map<String, dynamic>;
      pricesJson.forEach((key, value) {
        final fuelType = FuelType.values.firstWhere(
          (type) => type.toString().split('.').last == key,
          orElse: () => FuelType.regular,
        );
        pricesMap[fuelType] = (value as num).toDouble();
      });
    }

    return GasStation(
      id: json['id'] as String,
      name: json['name'] as String,
      location: LatLng(
        (json['location']['lat'] as num).toDouble(),
        (json['location']['lng'] as num).toDouble(),
      ),
      address: json['address'] as String,
      state: json['state'] as String,
      city: json['city'] as String?,
      prices: pricesMap,
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      brand: json['brand'] as String?,
      amenities: json['amenities'] != null
          ? List<String>.from(json['amenities'])
          : null,
      isOpen: json['isOpen'] as bool?,
      hours: json['hours'] != null
          ? Map<String, String>.from(json['hours'])
          : null,
    );
  }
}
