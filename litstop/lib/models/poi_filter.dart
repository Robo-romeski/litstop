import 'point_of_interest.dart';

/// Class representing POI filtering criteria
class POIFilter {
  /// Types of POIs to include in results
  final List<POIType>? includedTypes;

  /// Maximum distance in meters
  final double? maxDistance;

  /// Minimum rating (1-5)
  final double? minRating;

  /// Required amenities that must be present
  final List<String>? requiredAmenities;

  /// Whether to show only open POIs
  final bool? onlyShowOpen;

  /// Constructor
  POIFilter({
    this.includedTypes,
    this.maxDistance,
    this.minRating,
    this.requiredAmenities,
    this.onlyShowOpen,
  });

  /// Apply this filter to a list of POIs
  List<PointOfInterest> apply(List<PointOfInterest> pois) {
    // Start with all POIs
    List<PointOfInterest> filteredList = List.from(pois);

    // Filter by POI type if specified
    if (includedTypes != null && includedTypes!.isNotEmpty) {
      filteredList = filteredList
          .where((poi) => includedTypes!.contains(poi.type))
          .toList();
    }

    // Filter by maximum distance if specified and distance is available
    if (maxDistance != null) {
      filteredList = filteredList
          .where((poi) => poi.distance == null || poi.distance! <= maxDistance!)
          .toList();
    }

    // Filter by minimum rating if specified and rating is available
    if (minRating != null) {
      filteredList = filteredList
          .where((poi) => poi.rating == null || poi.rating! >= minRating!)
          .toList();
    }

    // Filter by required amenities if specified
    if (requiredAmenities != null && requiredAmenities!.isNotEmpty) {
      filteredList = filteredList.where((poi) {
        // If POI has no amenities, it doesn't match
        if (poi.amenities == null || poi.amenities!.isEmpty) {
          return false;
        }

        // Check if all required amenities are present
        return requiredAmenities!
            .every((amenity) => poi.amenities!.contains(amenity));
      }).toList();
    }

    // Filter by open status if specified
    if (onlyShowOpen == true) {
      filteredList = filteredList.where((poi) => poi.isOpen == true).toList();
    }

    return filteredList;
  }

  /// Create a copy of this filter with some values changed
  POIFilter copyWith({
    List<POIType>? includedTypes,
    double? maxDistance,
    double? minRating,
    List<String>? requiredAmenities,
    bool? onlyShowOpen,
  }) {
    return POIFilter(
      includedTypes: includedTypes ?? this.includedTypes,
      maxDistance: maxDistance ?? this.maxDistance,
      minRating: minRating ?? this.minRating,
      requiredAmenities: requiredAmenities ?? this.requiredAmenities,
      onlyShowOpen: onlyShowOpen ?? this.onlyShowOpen,
    );
  }

  /// A preset filter for rest stops
  static POIFilter restStops() {
    return POIFilter(
      includedTypes: [POIType.restArea, POIType.truckStop],
    );
  }

  /// A preset filter for gas stations
  static POIFilter gasStations() {
    return POIFilter(
      includedTypes: [POIType.gasStation],
    );
  }

  /// A preset filter for food (restaurants and cafes)
  static POIFilter food() {
    return POIFilter(
      includedTypes: [POIType.restaurant, POIType.cafe],
    );
  }

  /// A preset filter for lodging
  static POIFilter lodging() {
    return POIFilter(
      includedTypes: [POIType.hotel],
    );
  }

  /// A preset filter for locations with WiFi
  static POIFilter withWifi() {
    return POIFilter(
      requiredAmenities: ['wifi'],
    );
  }

  /// Create a JSON representation of this filter
  Map<String, dynamic> toJson() {
    return {
      'includedTypes':
          includedTypes?.map((t) => t.toString().split('.').last).toList(),
      'maxDistance': maxDistance,
      'minRating': minRating,
      'requiredAmenities': requiredAmenities,
      'onlyShowOpen': onlyShowOpen,
    };
  }

  /// Create a filter from JSON
  factory POIFilter.fromJson(Map<String, dynamic> json) {
    // Convert type strings back to enum values
    List<POIType>? types;
    if (json['includedTypes'] != null) {
      types = (json['includedTypes'] as List).map((typeStr) {
        return POIType.values.firstWhere(
          (e) => e.toString() == 'POIType.$typeStr',
          orElse: () => POIType.other,
        );
      }).toList();
    }

    return POIFilter(
      includedTypes: types,
      maxDistance: json['maxDistance'],
      minRating: json['minRating'],
      requiredAmenities: json['requiredAmenities'] != null
          ? List<String>.from(json['requiredAmenities'])
          : null,
      onlyShowOpen: json['onlyShowOpen'],
    );
  }
}
