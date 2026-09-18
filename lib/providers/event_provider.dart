import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/ride_event.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Provider for managing real-time ride events
class EventProvider with ChangeNotifier {
  final List<RideEvent> _events = [];
  bool _isInitialized = false;
  final Random _random = Random();
  Timer? _mockEventTimer;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _areNotificationsInitialized = false;

  /// Get all events
  List<RideEvent> get events => _events;

  /// Get unread events count
  int get unreadCount => _events.where((event) => !event.isRead).length;

  /// Check if there are any unread events
  bool get hasUnreadEvents => unreadCount > 0;

  /// Constructor
  EventProvider() {
    _initializeNotifications();
  }

  /// Initialize the notifications plugin
  Future<void> _initializeNotifications() async {
    if (_areNotificationsInitialized) return;

    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    _areNotificationsInitialized = true;
  }

  /// Initialize the event system
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Load events from local storage in a real app
    _loadMockEvents();

    // Start generating mock events in background for demo
    _startMockEventGenerator();

    _isInitialized = true;
    notifyListeners();
  }

  /// Load initial mock events
  void _loadMockEvents() {
    // Add some initial events for demo purposes
    final now = DateTime.now();

    _events.addAll([
      RideEvent(
        id: '1',
        type: RideEventType.notification,
        title: 'Welcome to LitStop',
        description: 'Your real-time ride dashboard is now active.',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
      RideEvent(
        id: '2',
        type: RideEventType.highDemandArea,
        title: 'Predicted busy area',
        description: 'More activity than usual downtown.',
        timestamp: now.subtract(const Duration(minutes: 15)),
        location: const LatLng(37.7749, -122.4194),
      ),
    ]);
  }

  /// Start generating mock events for demo purposes
  void _startMockEventGenerator() {
    // Cancel existing timer if any
    _mockEventTimer?.cancel();

    // Create a new timer to generate random events every 20-60 seconds
    _mockEventTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _generateMockEvent(),
    );
  }

  /// Generate a random mock event
  void _generateMockEvent() {
    // Skip sometimes to make events feel more random
    if (_random.nextDouble() > 0.7) return;

    // Generate a random event type
    final eventTypeIndex = _random.nextInt(RideEventType.values.length);
    final eventType = RideEventType.values[eventTypeIndex];

    // Create event based on type
    RideEvent event;
    final eventId = DateTime.now().millisecondsSinceEpoch.toString();

    switch (eventType) {
      case RideEventType.rideRequest:
        // Random location around San Francisco for demo
        final location = LatLng(
          37.7749 + ((_random.nextDouble() - 0.5) * 0.05),
          -122.4194 + ((_random.nextDouble() - 0.5) * 0.05),
        );

        final fare = 15 + (_random.nextDouble() * 30);
        final distance = 1 + (_random.nextDouble() * 10);
        final duration = 5 + (_random.nextInt(25));

        event = RideEvent(
          id: eventId,
          type: eventType,
          title: 'New Ride Request',
          description:
              'A passenger is requesting a ride ${distance.toStringAsFixed(1)} miles away.',
          timestamp: DateTime.now(),
          location: location,
          estimatedFare: fare,
          estimatedDistance: distance,
          estimatedDuration: duration,
        );
        break;

      case RideEventType.highDemandArea:
        final location = LatLng(
          37.7749 + ((_random.nextDouble() - 0.5) * 0.07),
          -122.4194 + ((_random.nextDouble() - 0.5) * 0.07),
        );

        event = RideEvent(
          id: eventId,
          type: eventType,
          title: 'Predicted busy area',
          description: 'More activity expected near ${_getRandomArea()}.',
          timestamp: DateTime.now(),
          location: location,
        );
        break;

      default:
        // Generic notification
        event = RideEvent(
          id: eventId,
          type: eventType,
          title: _getTitleForEventType(eventType),
          description: _getDescriptionForEventType(eventType),
          timestamp: DateTime.now(),
        );
    }

    // Add event to list
    _addEvent(event);

    // Trigger local notification
    _showEventNotification(event);
  }

  /// Get random area name for high demand notifications
  String _getRandomArea() {
    final areas = [
      'Downtown',
      'Financial District',
      'Mission District',
      'SoMa',
      'Marina District',
      'North Beach',
      'Chinatown',
      'Sunset District',
    ];

    return areas[_random.nextInt(areas.length)];
  }

  /// Get title based on event type
  String _getTitleForEventType(RideEventType type) {
    switch (type) {
      case RideEventType.rideRequest:
        return 'New Ride Request';
      case RideEventType.rideAccepted:
        return 'Ride Accepted';
      case RideEventType.rideCompleted:
        return 'Ride Completed';
      case RideEventType.rideCancelled:
        return 'Ride Cancelled';
      case RideEventType.highDemandArea:
        return 'Predicted busy area';
      case RideEventType.notification:
        return 'LitStop Update';
    }
  }

  /// Get description based on event type
  String _getDescriptionForEventType(RideEventType type) {
    switch (type) {
      case RideEventType.rideRequest:
        return 'A passenger is requesting a ride nearby.';
      case RideEventType.rideAccepted:
        return 'Another driver has accepted a nearby ride.';
      case RideEventType.rideCompleted:
        return 'Your ride has been completed successfully.';
      case RideEventType.rideCancelled:
        return 'A ride request has been cancelled by the passenger.';
      case RideEventType.highDemandArea:
        return 'More activity expected in your area.';
      case RideEventType.notification:
        final notifications = [
          'New promotions available in your area.',
          'Weather alert: Light rain expected in your area.',
          'Weekly earnings summary is now available.',
          'Rate adjustment: Fares have increased by 10%.',
          'App update available with new features.',
          'Maintenance reminder: Schedule service soon.',
        ];
        return notifications[_random.nextInt(notifications.length)];
    }
  }

  /// Add a new event to the events list
  void _addEvent(RideEvent event) {
    _events.insert(0, event);

    // Limit the number of events to keep
    if (_events.length > 50) {
      _events.removeLast();
    }

    notifyListeners();
  }

  /// Show a notification for a new event
  Future<void> _showEventNotification(RideEvent event) async {
    if (!_areNotificationsInitialized) await _initializeNotifications();

    const androidDetails = AndroidNotificationDetails(
      'ride_events',
      'Ride Events',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      event.id.hashCode,
      event.title,
      event.description,
      notificationDetails,
      payload: event.id,
    );
  }

  /// Mark an event as read by ID
  void markEventAsRead(String eventId) {
    final event = _events.firstWhere((e) => e.id == eventId);
    event.markAsRead();
    notifyListeners();
  }

  /// Mark all events as read
  void markAllEventsAsRead() {
    for (final event in _events) {
      event.isRead = true;
    }
    notifyListeners();
  }

  /// Delete an event by ID
  void deleteEvent(String eventId) {
    _events.removeWhere((e) => e.id == eventId);
    notifyListeners();
  }

  /// Clear all events
  void clearAllEvents() {
    _events.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _mockEventTimer?.cancel();
    super.dispose();
  }
}
