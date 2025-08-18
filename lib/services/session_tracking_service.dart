import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../providers/session_provider.dart';
import '../providers/location_provider.dart';
import '../providers/fatigue_monitoring_provider.dart';

/// Service that coordinates session tracking between multiple providers
class SessionTrackingService {
  final SessionProvider _sessionProvider;
  final LocationProvider _locationProvider;
  final FatigueMonitoringProvider _fatigueProvider;

  StreamSubscription<Position>? _locationSubscription;
  Timer? _sessionUpdateTimer;

  bool _isTracking = false;

  SessionTrackingService({
    required SessionProvider sessionProvider,
    required LocationProvider locationProvider,
    required FatigueMonitoringProvider fatigueProvider,
  })  : _sessionProvider = sessionProvider,
        _locationProvider = locationProvider,
        _fatigueProvider = fatigueProvider;

  /// Whether session tracking is currently active
  bool get isTracking => _isTracking;

  /// Start comprehensive session tracking
  Future<void> startSessionTracking() async {
    if (_isTracking) return;

    try {
      // Initialize location services
      await _locationProvider.initializeLocation();

      // Start session tracking
      await _sessionProvider.startSession();

      // Start fatigue monitoring
      await _fatigueProvider.startMonitoring();

      // Start location tracking
      _locationProvider.startTracking();

      // Subscribe to location updates
      _startLocationTracking();

      // Start periodic session updates
      _startSessionUpdateTimer();

      _isTracking = true;

      debugPrint('📊 Session tracking started successfully');
    } catch (e) {
      debugPrint('❌ Error starting session tracking: $e');
      rethrow;
    }
  }

  /// Stop comprehensive session tracking
  Future<void> stopSessionTracking() async {
    if (!_isTracking) return;

    try {
      // Stop location tracking
      _stopLocationTracking();
      _locationProvider.stopTracking();

      // Stop fatigue monitoring
      await _fatigueProvider.stopMonitoring();

      // End session
      await _sessionProvider.endSession();

      // Stop timers
      _stopSessionUpdateTimer();

      _isTracking = false;

      debugPrint('🛑 Session tracking stopped successfully');
    } catch (e) {
      debugPrint('❌ Error stopping session tracking: $e');
      rethrow;
    }
  }

  /// Start location tracking and updates
  void _startLocationTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Update every 10 meters
    );

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) {
        // Update location provider
        _locationProvider.updatePosition(position);

        // Update fatigue monitoring with location
        _fatigueProvider.updateLocation(position);

        // Record user activity for session timeout
        _sessionProvider.recordUserActivity();
      },
      onError: (error) {
        debugPrint('❌ Location tracking error: $error');
      },
    );
  }

  /// Stop location tracking
  void _stopLocationTracking() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Start periodic session updates
  void _startSessionUpdateTimer() {
    _stopSessionUpdateTimer();

    // Update session metrics every 30 seconds
    _sessionUpdateTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        _updateSessionMetrics();
      },
    );
  }

  /// Stop session update timer
  void _stopSessionUpdateTimer() {
    _sessionUpdateTimer?.cancel();
    _sessionUpdateTimer = null;
  }

  /// Update session metrics based on tracking data
  void _updateSessionMetrics() {
    if (!_isTracking) return;

    try {
      // Calculate distance traveled since last update
      final trackingHistory = _locationProvider.trackingHistory;
      if (trackingHistory.length >= 2) {
        final lastPosition = trackingHistory[trackingHistory.length - 2];
        final currentPosition = trackingHistory.last;

        final distance = Geolocator.distanceBetween(
          lastPosition.latitude,
          lastPosition.longitude,
          currentPosition.latitude,
          currentPosition.longitude,
        );

        // Convert meters to miles and update session
        final distanceInMiles = distance * 0.000621371;
        _sessionProvider.updateMetrics(distance: distanceInMiles);
      }

      // Record activity to prevent session timeout
      _sessionProvider.recordUserActivity();
    } catch (e) {
      debugPrint('❌ Error updating session metrics: $e');
    }
  }

  /// Manually start a break (affects both session and fatigue monitoring)
  Future<void> startBreak() async {
    if (!_isTracking) return;

    try {
      await _fatigueProvider.startBreak();
      debugPrint('☕ Break started via session tracking service');
    } catch (e) {
      debugPrint('❌ Error starting break: $e');
    }
  }

  /// Manually end a break
  Future<void> endBreak() async {
    if (!_isTracking) return;

    try {
      await _fatigueProvider.endBreak();
      debugPrint('✅ Break ended via session tracking service');
    } catch (e) {
      debugPrint('❌ Error ending break: $e');
    }
  }

  /// Get comprehensive session status
  Map<String, dynamic> getSessionStatus() {
    return {
      'isTracking': _isTracking,
      'sessionActive': _sessionProvider.isSessionActive,
      'fatigueMonitoring': _fatigueProvider.isMonitoring,
      'locationTracking': _locationProvider.isTracking,
      'sessionDuration': _sessionProvider.formattedSessionTime,
      'continuousDriving': _fatigueProvider.formattedContinuousDrivingTime,
      'isOnBreak': _fatigueProvider.isCurrentlyOnBreak,
      'shouldTakeBreak': _fatigueProvider.shouldTakeBreak,
      'totalDistance': _sessionProvider.totalDistance,
      'currentPosition': _locationProvider.currentPosition,
    };
  }

  /// Check if session has timed out
  bool isSessionTimedOut() {
    return _sessionProvider.isSessionTimedOut();
  }

  /// Handle session timeout
  Future<void> handleSessionTimeout() async {
    if (_isTracking && isSessionTimedOut()) {
      debugPrint('⏰ Session timed out, stopping tracking');
      await stopSessionTracking();
    }
  }

  /// Dispose of resources
  void dispose() {
    _stopLocationTracking();
    _stopSessionUpdateTimer();
  }
}
