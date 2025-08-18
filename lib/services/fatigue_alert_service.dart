import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/fatigue_alert_settings.dart';

/// Types of fatigue alerts
enum FatigueAlertType {
  reminder1,
  reminder2,
  finalAlert,
  breakStarted,
  breakEnded,
  automaticBreakDetected,
}

/// Severity levels for alerts
enum FatigueAlertSeverity {
  info,
  warning,
  critical,
}

/// Data class for fatigue alert information
class FatigueAlertData {
  final FatigueAlertType type;
  final FatigueAlertSeverity severity;
  final String title;
  final String message;
  final String voiceMessage;
  final String actionText;
  final VoidCallback? action;
  final DateTime timestamp;
  final Duration? drivingTime;
  final Duration? breakTime;

  const FatigueAlertData({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.voiceMessage,
    this.actionText = 'Take Break',
    this.action,
    required this.timestamp,
    this.drivingTime,
    this.breakTime,
  });
}

/// Service for managing fatigue alerts across different UI components
class FatigueAlertService {
  static final FatigueAlertService _instance = FatigueAlertService._internal();
  factory FatigueAlertService() => _instance;
  FatigueAlertService._internal();

  // Notification plugin
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Current settings
  FatigueAlertSettings _settings = const FatigueAlertSettings();

  // Stream controllers for different alert channels
  final StreamController<FatigueAlertData> _inAppAlertController =
      StreamController<FatigueAlertData>.broadcast();
  final StreamController<FatigueAlertData> _bannerAlertController =
      StreamController<FatigueAlertData>.broadcast();
  final StreamController<FatigueAlertData> _voiceAlertController =
      StreamController<FatigueAlertData>.broadcast();

  // Getters for streams
  Stream<FatigueAlertData> get inAppAlerts => _inAppAlertController.stream;
  Stream<FatigueAlertData> get bannerAlerts => _bannerAlertController.stream;
  Stream<FatigueAlertData> get voiceAlerts => _voiceAlertController.stream;

  // Alert state tracking
  final Set<FatigueAlertType> _activeAlerts = {};
  FatigueAlertData? _currentBannerAlert;

  /// Initialize the alert service
  Future<void> initialize({FatigueAlertSettings? settings}) async {
    if (_isInitialized) return;

    if (settings != null) {
      _settings = settings;
    }

    await _initializeNotifications();
    _isInitialized = true;
  }

  /// Initialize local notifications
  Future<void> _initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request notification permissions
    await _requestPermissions();
  }

  /// Request necessary permissions
  Future<void> _requestPermissions() async {
    await Permission.notification.request();

    // Request additional permissions for iOS
    if (await Permission.notification.isGranted) {
      // Permissions already granted
    } else {
      debugPrint('Notification permissions not granted');
    }
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('Fatigue notification tapped: ${response.payload}');
    // Handle navigation or actions based on payload
  }

  /// Update settings
  void updateSettings(FatigueAlertSettings settings) {
    _settings = settings;
  }

  /// Show a fatigue alert
  Future<void> showAlert(
    FatigueAlertType type, {
    Duration? drivingTime,
    Duration? breakTime,
    VoidCallback? action,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final alertData = _createAlertData(type,
        drivingTime: drivingTime, breakTime: breakTime, action: action);

    // Prevent duplicate alerts of the same type
    if (_activeAlerts.contains(type)) {
      return;
    }

    _activeAlerts.add(type);

    // Show different types of alerts based on settings
    if (_settings.enablePushNotifications) {
      await _showSystemNotification(alertData);
    }

    // Always show in-app alerts for critical safety
    _inAppAlertController.add(alertData);

    // Show banner alerts for non-critical alerts
    if (alertData.severity != FatigueAlertSeverity.critical) {
      _bannerAlertController.add(alertData);
      _currentBannerAlert = alertData;
    }

    // Voice alerts if enabled
    if (_settings.enableVoiceAlerts) {
      _voiceAlertController.add(alertData);
    }

    // Vibration if enabled
    if (_settings.enableVibration) {
      await _triggerVibration(alertData.severity);
    }

    // Auto-clear alert after some time
    Timer(const Duration(minutes: 2), () {
      _activeAlerts.remove(type);
    });
  }

  /// Create alert data based on type
  FatigueAlertData _createAlertData(
    FatigueAlertType type, {
    Duration? drivingTime,
    Duration? breakTime,
    VoidCallback? action,
  }) {
    switch (type) {
      case FatigueAlertType.reminder1:
        return FatigueAlertData(
          type: type,
          severity: FatigueAlertSeverity.info,
          title: 'Driving Time Reminder',
          message: drivingTime != null
              ? 'You\'ve been driving for ${_formatDuration(drivingTime)}. Consider taking a break soon.'
              : 'Consider taking a break soon.',
          voiceMessage:
              'You have been driving for a while. Consider taking a break soon.',
          actionText: 'Find Rest Stop',
          action: action,
          timestamp: DateTime.now(),
          drivingTime: drivingTime,
        );

      case FatigueAlertType.reminder2:
        return FatigueAlertData(
          type: type,
          severity: FatigueAlertSeverity.warning,
          title: 'Break Recommended',
          message: drivingTime != null
              ? 'You\'ve been driving for ${_formatDuration(drivingTime)}. A break is strongly recommended.'
              : 'A break is strongly recommended.',
          voiceMessage:
              'You should take a break soon. Find a safe place to stop.',
          actionText: 'Find Rest Stop',
          action: action,
          timestamp: DateTime.now(),
          drivingTime: drivingTime,
        );

      case FatigueAlertType.finalAlert:
        return FatigueAlertData(
          type: type,
          severity: FatigueAlertSeverity.critical,
          title: 'SAFETY ALERT: Take a Break Now',
          message: drivingTime != null
              ? 'You\'ve been driving for ${_formatDuration(drivingTime)}. You must take a break now for your safety.'
              : 'You must take a break now for your safety.',
          voiceMessage:
              'Safety alert! You must take a break now. Find the nearest safe place to stop immediately.',
          actionText: 'Find Nearest Rest Stop',
          action: action,
          timestamp: DateTime.now(),
          drivingTime: drivingTime,
        );

      case FatigueAlertType.breakStarted:
        return FatigueAlertData(
          type: type,
          severity: FatigueAlertSeverity.info,
          title: 'Break Started',
          message: 'Your break has started. Take time to rest and refresh.',
          voiceMessage: 'Break started. Take time to rest.',
          actionText: 'OK',
          timestamp: DateTime.now(),
          breakTime: breakTime,
        );

      case FatigueAlertType.breakEnded:
        final isValidBreak = breakTime != null &&
            breakTime.inMinutes >= _settings.minimumBreakMinutes;
        return FatigueAlertData(
          type: type,
          severity: isValidBreak
              ? FatigueAlertSeverity.info
              : FatigueAlertSeverity.warning,
          title: isValidBreak ? 'Break Complete' : 'Short Break',
          message: isValidBreak
              ? 'Your break is complete. Drive safely!'
              : breakTime != null
                  ? 'You took a ${_formatDuration(breakTime)} break. Consider taking longer breaks for better rest.'
                  : 'Consider taking longer breaks for better rest.',
          voiceMessage: isValidBreak
              ? 'Break complete. Drive safely.'
              : 'Consider taking longer breaks for better rest.',
          actionText: 'Continue',
          timestamp: DateTime.now(),
          breakTime: breakTime,
        );

      case FatigueAlertType.automaticBreakDetected:
        return FatigueAlertData(
          type: type,
          severity: FatigueAlertSeverity.info,
          title: 'Break Detected',
          message:
              'We noticed you\'ve stopped. Your break time is now being tracked.',
          voiceMessage: 'Break detected. Your break time is being tracked.',
          actionText: 'OK',
          timestamp: DateTime.now(),
        );
    }
  }

  /// Show system notification
  Future<void> _showSystemNotification(FatigueAlertData alertData) async {
    final importance = _getNotificationImportance(alertData.severity);
    final priority = _getNotificationPriority(alertData.severity);

    const channelId = 'fatigue_alerts';
    const channelName = 'Fatigue Monitoring';
    const channelDescription =
        'Alerts for driver fatigue monitoring and safety';

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: importance,
      priority: priority,
      showWhen: true,
      when: alertData.timestamp.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: alertData.severity == FatigueAlertSeverity.critical,
      ongoing: alertData.severity == FatigueAlertSeverity.critical,
      autoCancel: alertData.severity != FatigueAlertSeverity.critical,
      color: _getNotificationColor(alertData.severity),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: alertData.severity == FatigueAlertSeverity.critical
          ? 'alarm.wav'
          : null,
      badgeNumber: 1,
      interruptionLevel: alertData.severity == FatigueAlertSeverity.critical
          ? InterruptionLevel.critical
          : InterruptionLevel.active,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      alertData.type.index,
      alertData.title,
      alertData.message,
      notificationDetails,
      payload:
          '${alertData.type.name}|${alertData.timestamp.millisecondsSinceEpoch}',
    );
  }

  /// Get Android notification importance based on severity
  Importance _getNotificationImportance(FatigueAlertSeverity severity) {
    switch (severity) {
      case FatigueAlertSeverity.info:
        return Importance.defaultImportance;
      case FatigueAlertSeverity.warning:
        return Importance.high;
      case FatigueAlertSeverity.critical:
        return Importance.max;
    }
  }

  /// Get Android notification priority based on severity
  Priority _getNotificationPriority(FatigueAlertSeverity severity) {
    switch (severity) {
      case FatigueAlertSeverity.info:
        return Priority.defaultPriority;
      case FatigueAlertSeverity.warning:
        return Priority.high;
      case FatigueAlertSeverity.critical:
        return Priority.max;
    }
  }

  /// Get notification color based on severity
  Color _getNotificationColor(FatigueAlertSeverity severity) {
    switch (severity) {
      case FatigueAlertSeverity.info:
        return Colors.blue;
      case FatigueAlertSeverity.warning:
        return Colors.orange;
      case FatigueAlertSeverity.critical:
        return Colors.red;
    }
  }

  /// Trigger vibration based on severity
  Future<void> _triggerVibration(FatigueAlertSeverity severity) async {
    switch (severity) {
      case FatigueAlertSeverity.info:
        await HapticFeedback.lightImpact();
        break;
      case FatigueAlertSeverity.warning:
        await HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(milliseconds: 100));
        await HapticFeedback.mediumImpact();
        break;
      case FatigueAlertSeverity.critical:
        for (int i = 0; i < 3; i++) {
          await HapticFeedback.heavyImpact();
          await Future.delayed(const Duration(milliseconds: 200));
        }
        break;
    }
  }

  /// Format duration to human readable string
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    } else {
      return '${minutes}m';
    }
  }

  /// Clear current banner alert
  void clearBannerAlert() {
    _currentBannerAlert = null;
  }

  /// Get current banner alert
  FatigueAlertData? get currentBannerAlert => _currentBannerAlert;

  /// Clear all active alerts
  void clearAllAlerts() {
    _activeAlerts.clear();
    _currentBannerAlert = null;
    _notifications.cancelAll();
  }

  /// Dispose of resources
  void dispose() {
    _inAppAlertController.close();
    _bannerAlertController.close();
    _voiceAlertController.close();
    clearAllAlerts();
  }
}
