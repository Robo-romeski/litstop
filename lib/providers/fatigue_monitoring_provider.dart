import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../services/fatigue_alert_service.dart';

/// Provider for monitoring driver fatigue and alerting based on continuous driving time
class FatigueMonitoringProvider with ChangeNotifier {
  // Alert service integration
  final FatigueAlertService _alertService = FatigueAlertService();

  // Monitoring state
  bool _isMonitoring = false;
  DateTime? _continuousDrivingStart;
  DateTime? _lastBreakTime;
  int _totalContinuousDrivingMinutes = 0;

  // Location tracking for movement validation
  Position? _lastPosition;
  DateTime? _lastMovementTime;
  Timer? _monitoringTimer;
  Timer? _backgroundTimer;

  // Configuration (customizable via settings)
  int _maxContinuousDrivingMinutes = 120; // 2 hours default
  int _breakReminder1Minutes = 90; // First reminder at 1.5 hours
  int _breakReminder2Minutes = 105; // Second reminder at 1.75 hours
  int _minimumBreakMinutes = 15; // Minimum break duration
  double _movementThresholdMeters =
      50.0; // Minimum distance to consider "moving"
  int _stationaryThresholdMinutes =
      10; // Minutes stationary to consider a break

  // Alert state
  bool _hasShownReminder1 = false;
  bool _hasShownReminder2 = false;
  bool _hasShownFinalAlert = false;
  bool _isCurrentlyOnBreak = false;
  DateTime? _currentBreakStart;

  // Preferences key
  static const String _prefsKey = 'fatigue_monitoring_';

  // Getters
  bool get isMonitoring => _isMonitoring;
  bool get isCurrentlyOnBreak => _isCurrentlyOnBreak;
  DateTime? get continuousDrivingStart => _continuousDrivingStart;
  DateTime? get lastBreakTime => _lastBreakTime;
  DateTime? get currentBreakStart => _currentBreakStart;
  int get totalContinuousDrivingMinutes => _totalContinuousDrivingMinutes;
  int get maxContinuousDrivingMinutes => _maxContinuousDrivingMinutes;
  int get breakReminder1Minutes => _breakReminder1Minutes;
  int get breakReminder2Minutes => _breakReminder2Minutes;
  int get minimumBreakMinutes => _minimumBreakMinutes;
  bool get hasShownReminder1 => _hasShownReminder1;
  bool get hasShownReminder2 => _hasShownReminder2;
  bool get hasShownFinalAlert => _hasShownFinalAlert;

  /// Current continuous driving duration in minutes
  int get currentContinuousDrivingMinutes {
    if (!_isMonitoring ||
        _isCurrentlyOnBreak ||
        _continuousDrivingStart == null) {
      return 0;
    }
    return DateTime.now().difference(_continuousDrivingStart!).inMinutes;
  }

  /// Current break duration in minutes
  int get currentBreakMinutes {
    if (!_isCurrentlyOnBreak || _currentBreakStart == null) {
      return 0;
    }
    return DateTime.now().difference(_currentBreakStart!).inMinutes;
  }

  /// Remaining driving time before first reminder
  int get minutesUntilReminder1 {
    final current = currentContinuousDrivingMinutes;
    return math.max(0, _breakReminder1Minutes - current);
  }

  /// Remaining driving time before second reminder
  int get minutesUntilReminder2 {
    final current = currentContinuousDrivingMinutes;
    return math.max(0, _breakReminder2Minutes - current);
  }

  /// Remaining driving time before final alert
  int get minutesUntilFinalAlert {
    final current = currentContinuousDrivingMinutes;
    return math.max(0, _maxContinuousDrivingMinutes - current);
  }

  /// Whether driver should take a break (reached max continuous driving time)
  bool get shouldTakeBreak {
    return currentContinuousDrivingMinutes >= _maxContinuousDrivingMinutes;
  }

  /// Formatted current continuous driving time
  String get formattedContinuousDrivingTime {
    final minutes = currentContinuousDrivingMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  /// Formatted current break time
  String get formattedCurrentBreakTime {
    final minutes = currentBreakMinutes;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  FatigueMonitoringProvider() {
    _loadSettings();
    _initializeAlertService();
  }

  /// Initialize the alert service
  Future<void> _initializeAlertService() async {
    await _alertService.initialize();
  }

  /// Load saved settings from preferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _maxContinuousDrivingMinutes =
          prefs.getInt('${_prefsKey}max_driving_minutes') ?? 120;
      _breakReminder1Minutes =
          prefs.getInt('${_prefsKey}reminder1_minutes') ?? 90;
      _breakReminder2Minutes =
          prefs.getInt('${_prefsKey}reminder2_minutes') ?? 105;
      _minimumBreakMinutes =
          prefs.getInt('${_prefsKey}min_break_minutes') ?? 15;
      _stationaryThresholdMinutes =
          prefs.getInt('${_prefsKey}stationary_minutes') ?? 10;
      _movementThresholdMeters =
          prefs.getDouble('${_prefsKey}movement_threshold') ?? 50.0;

      // Load active monitoring state
      _isMonitoring = prefs.getBool('${_prefsKey}is_monitoring') ?? false;
      _isCurrentlyOnBreak = prefs.getBool('${_prefsKey}is_on_break') ?? false;

      final drivingStartMillis =
          prefs.getInt('${_prefsKey}driving_start_time') ?? 0;
      if (drivingStartMillis > 0) {
        _continuousDrivingStart =
            DateTime.fromMillisecondsSinceEpoch(drivingStartMillis);
      }

      final lastBreakMillis = prefs.getInt('${_prefsKey}last_break_time') ?? 0;
      if (lastBreakMillis > 0) {
        _lastBreakTime = DateTime.fromMillisecondsSinceEpoch(lastBreakMillis);
      }

      final currentBreakMillis =
          prefs.getInt('${_prefsKey}current_break_start') ?? 0;
      if (currentBreakMillis > 0) {
        _currentBreakStart =
            DateTime.fromMillisecondsSinceEpoch(currentBreakMillis);
      }

      _totalContinuousDrivingMinutes =
          prefs.getInt('${_prefsKey}total_continuous_minutes') ?? 0;
      _hasShownReminder1 =
          prefs.getBool('${_prefsKey}shown_reminder1') ?? false;
      _hasShownReminder2 =
          prefs.getBool('${_prefsKey}shown_reminder2') ?? false;
      _hasShownFinalAlert =
          prefs.getBool('${_prefsKey}shown_final_alert') ?? false;

      // Resume monitoring if it was active
      if (_isMonitoring) {
        _startMonitoringTimer();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading fatigue monitoring settings: $e');
    }
  }

  /// Save current state to preferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('${_prefsKey}is_monitoring', _isMonitoring);
      await prefs.setBool('${_prefsKey}is_on_break', _isCurrentlyOnBreak);

      if (_continuousDrivingStart != null) {
        await prefs.setInt('${_prefsKey}driving_start_time',
            _continuousDrivingStart!.millisecondsSinceEpoch);
      } else {
        await prefs.remove('${_prefsKey}driving_start_time');
      }

      if (_lastBreakTime != null) {
        await prefs.setInt('${_prefsKey}last_break_time',
            _lastBreakTime!.millisecondsSinceEpoch);
      }

      if (_currentBreakStart != null) {
        await prefs.setInt('${_prefsKey}current_break_start',
            _currentBreakStart!.millisecondsSinceEpoch);
      } else {
        await prefs.remove('${_prefsKey}current_break_start');
      }

      await prefs.setInt('${_prefsKey}total_continuous_minutes',
          _totalContinuousDrivingMinutes);
      await prefs.setBool('${_prefsKey}shown_reminder1', _hasShownReminder1);
      await prefs.setBool('${_prefsKey}shown_reminder2', _hasShownReminder2);
      await prefs.setBool('${_prefsKey}shown_final_alert', _hasShownFinalAlert);
    } catch (e) {
      debugPrint('Error saving fatigue monitoring state: $e');
    }
  }

  /// Update settings and sync with alert service
  Future<void> updateSettings({
    int? maxContinuousDrivingMinutes,
    int? breakReminder1Minutes,
    int? breakReminder2Minutes,
    int? minimumBreakMinutes,
    int? stationaryThresholdMinutes,
    double? movementThresholdMeters,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (maxContinuousDrivingMinutes != null) {
      _maxContinuousDrivingMinutes = maxContinuousDrivingMinutes;
      await prefs.setInt(
          '${_prefsKey}max_driving_minutes', maxContinuousDrivingMinutes);
    }

    if (breakReminder1Minutes != null) {
      _breakReminder1Minutes = breakReminder1Minutes;
      await prefs.setInt(
          '${_prefsKey}reminder1_minutes', breakReminder1Minutes);
    }

    if (breakReminder2Minutes != null) {
      _breakReminder2Minutes = breakReminder2Minutes;
      await prefs.setInt(
          '${_prefsKey}reminder2_minutes', breakReminder2Minutes);
    }

    if (minimumBreakMinutes != null) {
      _minimumBreakMinutes = minimumBreakMinutes;
      await prefs.setInt('${_prefsKey}min_break_minutes', minimumBreakMinutes);
    }

    if (stationaryThresholdMinutes != null) {
      _stationaryThresholdMinutes = stationaryThresholdMinutes;
      await prefs.setInt(
          '${_prefsKey}stationary_minutes', stationaryThresholdMinutes);
    }

    if (movementThresholdMeters != null) {
      _movementThresholdMeters = movementThresholdMeters;
      await prefs.setDouble(
          '${_prefsKey}movement_threshold', movementThresholdMeters);
    }

    notifyListeners();
  }

  /// Start fatigue monitoring
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _continuousDrivingStart = DateTime.now();
    _lastMovementTime = DateTime.now();
    _isCurrentlyOnBreak = false;
    _currentBreakStart = null;

    // Reset alert flags for new session
    _hasShownReminder1 = false;
    _hasShownReminder2 = false;
    _hasShownFinalAlert = false;

    _startMonitoringTimer();
    await _saveState();

    debugPrint('🚗 Fatigue monitoring started at $DateTime.now()');
    notifyListeners();
  }

  /// Stop fatigue monitoring
  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    _isMonitoring = false;
    _isCurrentlyOnBreak = false;
    _currentBreakStart = null;

    // Update total continuous driving time before stopping
    if (_continuousDrivingStart != null) {
      _totalContinuousDrivingMinutes +=
          DateTime.now().difference(_continuousDrivingStart!).inMinutes;
    }

    _continuousDrivingStart = null;
    _lastPosition = null;
    _lastMovementTime = null;

    _stopMonitoringTimer();
    await _saveState();

    debugPrint('🛑 Fatigue monitoring stopped at $DateTime.now()');
    notifyListeners();
  }

  /// Update location for movement tracking
  void updateLocation(Position position) {
    if (!_isMonitoring) return;

    final now = DateTime.now();

    // Check if we've moved significantly
    if (_lastPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      if (distance >= _movementThresholdMeters) {
        _lastMovementTime = now;

        // If we were on a break and started moving, end the break
        if (_isCurrentlyOnBreak) {
          _endBreak();
        }
      }
    }

    _lastPosition = position;
  }

  /// Manually start a break
  Future<void> startBreak() async {
    if (!_isMonitoring || _isCurrentlyOnBreak) return;

    _isCurrentlyOnBreak = true;
    _currentBreakStart = DateTime.now();

    debugPrint('☕ Manual break started at $DateTime.now()');

    // Show break started alert
    _alertService.showAlert(FatigueAlertType.breakStarted);

    await _saveState();
    notifyListeners();
  }

  /// Manually end a break
  Future<void> endBreak() async {
    if (!_isCurrentlyOnBreak) return;
    _endBreak();
  }

  /// Internal method to end a break
  Future<void> _endBreak() async {
    if (!_isCurrentlyOnBreak || _currentBreakStart == null) return;

    final breakDuration =
        DateTime.now().difference(_currentBreakStart!).inMinutes;

    // Only count as a valid break if it meets minimum duration
    if (breakDuration >= _minimumBreakMinutes) {
      _lastBreakTime = DateTime.now();

      // Reset continuous driving start time after a valid break
      _continuousDrivingStart = DateTime.now();

      // Reset alert flags for new driving period
      _hasShownReminder1 = false;
      _hasShownReminder2 = false;
      _hasShownFinalAlert = false;

      debugPrint('✅ Valid break completed: $breakDuration minutes');
    } else {
      debugPrint(
          '⚠️ Break too short: $breakDuration minutes (minimum: $_minimumBreakMinutes)');
    }

    // Show break ended alert
    _alertService.showAlert(
      FatigueAlertType.breakEnded,
      breakTime: Duration(minutes: breakDuration),
    );

    _isCurrentlyOnBreak = false;
    _currentBreakStart = null;

    await _saveState();
    notifyListeners();
  }

  /// Start the monitoring timer
  void _startMonitoringTimer() {
    _stopMonitoringTimer();

    // Check every minute for alerts and break detection
    _monitoringTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkForAlerts();
      _checkForAutomaticBreak();
    });

    // Background timer for when app is minimized (every 5 minutes)
    _backgroundTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _saveState(); // Persist state regularly
    });
  }

  /// Stop monitoring timers
  void _stopMonitoringTimer() {
    _monitoringTimer?.cancel();
    _backgroundTimer?.cancel();
    _monitoringTimer = null;
    _backgroundTimer = null;
  }

  /// Check if alerts should be triggered
  void _checkForAlerts() {
    if (!_isMonitoring || _isCurrentlyOnBreak) return;

    final currentMinutes = currentContinuousDrivingMinutes;

    // First reminder
    if (!_hasShownReminder1 && currentMinutes >= _breakReminder1Minutes) {
      _hasShownReminder1 = true;
      _triggerReminder1Alert();
    }

    // Second reminder
    if (!_hasShownReminder2 && currentMinutes >= _breakReminder2Minutes) {
      _hasShownReminder2 = true;
      _triggerReminder2Alert();
    }

    // Final alert
    if (!_hasShownFinalAlert &&
        currentMinutes >= _maxContinuousDrivingMinutes) {
      _hasShownFinalAlert = true;
      _triggerFinalAlert();
    }
  }

  /// Check if driver has been stationary long enough to automatically start a break
  void _checkForAutomaticBreak() {
    if (!_isMonitoring || _isCurrentlyOnBreak || _lastMovementTime == null) {
      return;
    }

    final minutesSinceMovement =
        DateTime.now().difference(_lastMovementTime!).inMinutes;

    if (minutesSinceMovement >= _stationaryThresholdMinutes) {
      // Automatically start a break
      _isCurrentlyOnBreak = true;
      _currentBreakStart = _lastMovementTime!
          .add(Duration(minutes: _stationaryThresholdMinutes));

      debugPrint(
          '🅿️ Automatic break detected (stationary for $minutesSinceMovement minutes)');

      // Show automatic break detection alert
      _alertService.showAlert(FatigueAlertType.automaticBreakDetected);

      _saveState();
      notifyListeners();
    }
  }

  /// Trigger first reminder alert (1.5 hours)
  void _triggerReminder1Alert() {
    debugPrint(
        '⏰ Fatigue Reminder 1: You\'ve been driving for $formattedContinuousDrivingTime');

    // Show alert via alert service
    _alertService.showAlert(
      FatigueAlertType.reminder1,
      drivingTime: Duration(minutes: currentContinuousDrivingMinutes),
    );

    notifyListeners();
  }

  /// Trigger second reminder alert (1.75 hours)
  void _triggerReminder2Alert() {
    debugPrint(
        '⏰⏰ Fatigue Reminder 2: Consider taking a break soon ($formattedContinuousDrivingTime)');

    // Show alert via alert service
    _alertService.showAlert(
      FatigueAlertType.reminder2,
      drivingTime: Duration(minutes: currentContinuousDrivingMinutes),
    );

    notifyListeners();
  }

  /// Trigger final alert (2 hours)
  void _triggerFinalAlert() {
    debugPrint(
        '🚨 FATIGUE ALERT: You should take a break now! ($formattedContinuousDrivingTime)');

    // Show alert via alert service
    _alertService.showAlert(
      FatigueAlertType.finalAlert,
      drivingTime: Duration(minutes: currentContinuousDrivingMinutes),
    );

    notifyListeners();
  }

  /// Reset all alert flags (useful for testing or manual reset)
  Future<void> resetAlerts() async {
    _hasShownReminder1 = false;
    _hasShownReminder2 = false;
    _hasShownFinalAlert = false;
    await _saveState();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopMonitoringTimer();
    _alertService.dispose();
    super.dispose();
  }
}
