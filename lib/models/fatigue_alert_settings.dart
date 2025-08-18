/// Data model for fatigue alert settings and user preferences
class FatigueAlertSettings {
  /// Maximum continuous driving time in minutes before final alert (default: 2 hours)
  final int maxContinuousDrivingMinutes;

  /// First reminder time in minutes (default: 1.5 hours)
  final int breakReminder1Minutes;

  /// Second reminder time in minutes (default: 1.75 hours)
  final int breakReminder2Minutes;

  /// Minimum break duration in minutes to be considered valid (default: 15 minutes)
  final int minimumBreakMinutes;

  /// Time to be stationary before automatically starting a break (default: 10 minutes)
  final int stationaryThresholdMinutes;

  /// Minimum distance to move to be considered "driving" in meters (default: 50m)
  final double movementThresholdMeters;

  /// Whether fatigue monitoring is enabled
  final bool isMonitoringEnabled;

  /// Whether to show voice alerts
  final bool enableVoiceAlerts;

  /// Whether to show push notifications
  final bool enablePushNotifications;

  /// Whether to use vibration for alerts
  final bool enableVibration;

  /// Alert volume level (0.0 to 1.0)
  final double alertVolume;

  /// Whether to suggest nearby rest areas when alerts trigger
  final bool suggestNearbyRestAreas;

  /// Whether to automatically start breaks when stationary
  final bool enableAutomaticBreakDetection;

  const FatigueAlertSettings({
    this.maxContinuousDrivingMinutes = 120, // 2 hours
    this.breakReminder1Minutes = 90, // 1.5 hours
    this.breakReminder2Minutes = 105, // 1.75 hours
    this.minimumBreakMinutes = 15,
    this.stationaryThresholdMinutes = 10,
    this.movementThresholdMeters = 50.0,
    this.isMonitoringEnabled = true,
    this.enableVoiceAlerts = true,
    this.enablePushNotifications = true,
    this.enableVibration = true,
    this.alertVolume = 0.8,
    this.suggestNearbyRestAreas = true,
    this.enableAutomaticBreakDetection = true,
  });

  /// Create a copy with updated values
  FatigueAlertSettings copyWith({
    int? maxContinuousDrivingMinutes,
    int? breakReminder1Minutes,
    int? breakReminder2Minutes,
    int? minimumBreakMinutes,
    int? stationaryThresholdMinutes,
    double? movementThresholdMeters,
    bool? isMonitoringEnabled,
    bool? enableVoiceAlerts,
    bool? enablePushNotifications,
    bool? enableVibration,
    double? alertVolume,
    bool? suggestNearbyRestAreas,
    bool? enableAutomaticBreakDetection,
  }) {
    return FatigueAlertSettings(
      maxContinuousDrivingMinutes:
          maxContinuousDrivingMinutes ?? this.maxContinuousDrivingMinutes,
      breakReminder1Minutes:
          breakReminder1Minutes ?? this.breakReminder1Minutes,
      breakReminder2Minutes:
          breakReminder2Minutes ?? this.breakReminder2Minutes,
      minimumBreakMinutes: minimumBreakMinutes ?? this.minimumBreakMinutes,
      stationaryThresholdMinutes:
          stationaryThresholdMinutes ?? this.stationaryThresholdMinutes,
      movementThresholdMeters:
          movementThresholdMeters ?? this.movementThresholdMeters,
      isMonitoringEnabled: isMonitoringEnabled ?? this.isMonitoringEnabled,
      enableVoiceAlerts: enableVoiceAlerts ?? this.enableVoiceAlerts,
      enablePushNotifications:
          enablePushNotifications ?? this.enablePushNotifications,
      enableVibration: enableVibration ?? this.enableVibration,
      alertVolume: alertVolume ?? this.alertVolume,
      suggestNearbyRestAreas:
          suggestNearbyRestAreas ?? this.suggestNearbyRestAreas,
      enableAutomaticBreakDetection:
          enableAutomaticBreakDetection ?? this.enableAutomaticBreakDetection,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'maxContinuousDrivingMinutes': maxContinuousDrivingMinutes,
      'breakReminder1Minutes': breakReminder1Minutes,
      'breakReminder2Minutes': breakReminder2Minutes,
      'minimumBreakMinutes': minimumBreakMinutes,
      'stationaryThresholdMinutes': stationaryThresholdMinutes,
      'movementThresholdMeters': movementThresholdMeters,
      'isMonitoringEnabled': isMonitoringEnabled,
      'enableVoiceAlerts': enableVoiceAlerts,
      'enablePushNotifications': enablePushNotifications,
      'enableVibration': enableVibration,
      'alertVolume': alertVolume,
      'suggestNearbyRestAreas': suggestNearbyRestAreas,
      'enableAutomaticBreakDetection': enableAutomaticBreakDetection,
    };
  }

  /// Create from JSON
  factory FatigueAlertSettings.fromJson(Map<String, dynamic> json) {
    return FatigueAlertSettings(
      maxContinuousDrivingMinutes:
          json['maxContinuousDrivingMinutes'] as int? ?? 120,
      breakReminder1Minutes: json['breakReminder1Minutes'] as int? ?? 90,
      breakReminder2Minutes: json['breakReminder2Minutes'] as int? ?? 105,
      minimumBreakMinutes: json['minimumBreakMinutes'] as int? ?? 15,
      stationaryThresholdMinutes:
          json['stationaryThresholdMinutes'] as int? ?? 10,
      movementThresholdMeters:
          (json['movementThresholdMeters'] as num?)?.toDouble() ?? 50.0,
      isMonitoringEnabled: json['isMonitoringEnabled'] as bool? ?? true,
      enableVoiceAlerts: json['enableVoiceAlerts'] as bool? ?? true,
      enablePushNotifications: json['enablePushNotifications'] as bool? ?? true,
      enableVibration: json['enableVibration'] as bool? ?? true,
      alertVolume: (json['alertVolume'] as num?)?.toDouble() ?? 0.8,
      suggestNearbyRestAreas: json['suggestNearbyRestAreas'] as bool? ?? true,
      enableAutomaticBreakDetection:
          json['enableAutomaticBreakDetection'] as bool? ?? true,
    );
  }

  /// Get formatted duration string for time-based settings
  String formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;

    if (hours > 0 && mins > 0) {
      return '${hours}h ${mins}m';
    } else if (hours > 0) {
      return '${hours}h';
    } else {
      return '${mins}m';
    }
  }

  /// Get formatted max driving time
  String get formattedMaxDrivingTime =>
      formatDuration(maxContinuousDrivingMinutes);

  /// Get formatted first reminder time
  String get formattedReminder1Time => formatDuration(breakReminder1Minutes);

  /// Get formatted second reminder time
  String get formattedReminder2Time => formatDuration(breakReminder2Minutes);

  /// Get formatted minimum break time
  String get formattedMinBreakTime => formatDuration(minimumBreakMinutes);

  /// Get formatted stationary threshold time
  String get formattedStationaryTime =>
      formatDuration(stationaryThresholdMinutes);

  /// Validate settings (ensure logical consistency)
  List<String> validate() {
    final errors = <String>[];

    // Check timing hierarchy
    if (breakReminder1Minutes >= maxContinuousDrivingMinutes) {
      errors.add('First reminder must be before maximum driving time');
    }

    if (breakReminder2Minutes >= maxContinuousDrivingMinutes) {
      errors.add('Second reminder must be before maximum driving time');
    }

    if (breakReminder1Minutes >= breakReminder2Minutes) {
      errors.add('Second reminder must be after first reminder');
    }

    // Check minimum values
    if (maxContinuousDrivingMinutes < 30) {
      errors.add('Maximum driving time must be at least 30 minutes');
    }

    if (minimumBreakMinutes < 5) {
      errors.add('Minimum break time must be at least 5 minutes');
    }

    if (stationaryThresholdMinutes < 1) {
      errors.add('Stationary threshold must be at least 1 minute');
    }

    if (movementThresholdMeters < 10) {
      errors.add('Movement threshold must be at least 10 meters');
    }

    // Check alert volume
    if (alertVolume < 0.0 || alertVolume > 1.0) {
      errors.add('Alert volume must be between 0 and 1');
    }

    return errors;
  }

  /// Check if settings are valid
  bool get isValid => validate().isEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FatigueAlertSettings &&
        other.maxContinuousDrivingMinutes == maxContinuousDrivingMinutes &&
        other.breakReminder1Minutes == breakReminder1Minutes &&
        other.breakReminder2Minutes == breakReminder2Minutes &&
        other.minimumBreakMinutes == minimumBreakMinutes &&
        other.stationaryThresholdMinutes == stationaryThresholdMinutes &&
        other.movementThresholdMeters == movementThresholdMeters &&
        other.isMonitoringEnabled == isMonitoringEnabled &&
        other.enableVoiceAlerts == enableVoiceAlerts &&
        other.enablePushNotifications == enablePushNotifications &&
        other.enableVibration == enableVibration &&
        other.alertVolume == alertVolume &&
        other.suggestNearbyRestAreas == suggestNearbyRestAreas &&
        other.enableAutomaticBreakDetection == enableAutomaticBreakDetection;
  }

  @override
  int get hashCode {
    return maxContinuousDrivingMinutes.hashCode ^
        breakReminder1Minutes.hashCode ^
        breakReminder2Minutes.hashCode ^
        minimumBreakMinutes.hashCode ^
        stationaryThresholdMinutes.hashCode ^
        movementThresholdMeters.hashCode ^
        isMonitoringEnabled.hashCode ^
        enableVoiceAlerts.hashCode ^
        enablePushNotifications.hashCode ^
        enableVibration.hashCode ^
        alertVolume.hashCode ^
        suggestNearbyRestAreas.hashCode ^
        enableAutomaticBreakDetection.hashCode;
  }

  @override
  String toString() {
    return 'FatigueAlertSettings('
        'maxDriving: $formattedMaxDrivingTime, '
        'reminder1: $formattedReminder1Time, '
        'reminder2: $formattedReminder2Time, '
        'minBreak: $formattedMinBreakTime, '
        'monitoring: $isMonitoringEnabled'
        ')';
  }
}
