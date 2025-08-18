import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Types of ride events that can occur
enum RideEventType {
  /// A new ride request is available
  rideRequest,

  /// A nearby driver has accepted a ride
  rideAccepted,

  /// A ride has been completed
  rideCompleted,

  /// A ride has been cancelled by rider
  rideCancelled,

  /// A high demand area has been detected
  highDemandArea,

  /// System notification or alert
  notification,
}

/// Model representing a ride event notification
class RideEvent {
  /// Unique identifier for this event
  final String id;

  /// Type of event
  final RideEventType type;

  /// Title of the event notification
  final String title;

  /// Detailed description of the event
  final String description;

  /// When the event occurred
  final DateTime timestamp;

  /// Optional location associated with the event
  final LatLng? location;

  /// Optional estimated fare for ride requests
  final double? estimatedFare;

  /// Optional estimated distance in miles
  final double? estimatedDistance;

  /// Optional estimated duration in minutes
  final int? estimatedDuration;

  /// Whether the event has been read/viewed
  bool isRead;

  /// Constructor
  RideEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.location,
    this.estimatedFare,
    this.estimatedDistance,
    this.estimatedDuration,
    this.isRead = false,
  });

  /// Factory constructor to create a RideEvent from JSON data
  factory RideEvent.fromJson(Map<String, dynamic> json) {
    return RideEvent(
      id: json['id'] as String,
      type: RideEventType.values.firstWhere(
        (e) => e.toString() == 'RideEventType.${json['type']}',
        orElse: () => RideEventType.notification,
      ),
      title: json['title'] as String,
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      location: json['location'] != null
          ? LatLng(
              (json['location']['lat'] as num).toDouble(),
              (json['location']['lng'] as num).toDouble(),
            )
          : null,
      estimatedFare: json['estimatedFare'] != null
          ? (json['estimatedFare'] as num).toDouble()
          : null,
      estimatedDistance: json['estimatedDistance'] != null
          ? (json['estimatedDistance'] as num).toDouble()
          : null,
      estimatedDuration: json['estimatedDuration'] as int?,
      isRead: json['isRead'] as bool? ?? false,
    );
  }

  /// Convert to JSON object
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString().split('.').last,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'location': location != null
          ? {
              'lat': location!.latitude,
              'lng': location!.longitude,
            }
          : null,
      'estimatedFare': estimatedFare,
      'estimatedDistance': estimatedDistance,
      'estimatedDuration': estimatedDuration,
      'isRead': isRead,
    };
  }

  /// Get icon for this event type
  String get iconName {
    switch (type) {
      case RideEventType.rideRequest:
        return 'car_request';
      case RideEventType.rideAccepted:
        return 'car_accepted';
      case RideEventType.rideCompleted:
        return 'car_completed';
      case RideEventType.rideCancelled:
        return 'car_cancelled';
      case RideEventType.highDemandArea:
        return 'high_demand';
      case RideEventType.notification:
        return 'notification';
    }
  }

  /// Mark the event as read
  void markAsRead() {
    isRead = true;
  }
}
