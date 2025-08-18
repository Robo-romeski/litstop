import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:litstop/providers/auth_provider.dart';
import 'package:litstop/providers/session_provider.dart';

/// Session Security Manager for handling timeout and security features
///
/// This class manages session timeout, user activity tracking,
/// and automatic logout when session expires
class SessionSecurityManager {
  // Singleton instance
  static SessionSecurityManager? _instance;

  // Default session timeout duration (20 minutes)
  static const Duration defaultSessionTimeout = Duration(minutes: 20);

  // Key for storing session timeout settings
  static const String timeoutSettingKey = 'session_timeout_minutes';

  // User activity timer
  Timer? _inactivityTimer;

  // Current timeout duration
  Duration _timeoutDuration = defaultSessionTimeout;

  // Last activity timestamp
  DateTime _lastActivity = DateTime.now();

  // Flag to track whether user was warned about session expiration
  bool _wasWarned = false;

  // Warning threshold (percentage of timeout when warning should appear)
  final double _warningThreshold = 0.8; // 80% of timeout

  // Providers
  final AuthProvider? _authProvider;
  final SessionProvider? _sessionProvider;

  // Context for showing dialogs
  BuildContext? _context;

  // Private constructor
  SessionSecurityManager._({
    this.onSessionExpired,
    this.onSessionWarning,
    required AuthProvider authProvider,
    required SessionProvider sessionProvider,
  })  : _authProvider = authProvider,
        _sessionProvider = sessionProvider {
    _loadTimeoutSetting();
    _startActivityTracking();
  }

  // Factory constructor for singleton pattern
  factory SessionSecurityManager({
    required AuthProvider authProvider,
    required SessionProvider sessionProvider,
    Function? onSessionExpired,
    Function? onSessionWarning,
  }) {
    _instance ??= SessionSecurityManager._(
      authProvider: authProvider,
      sessionProvider: sessionProvider,
      onSessionExpired: onSessionExpired,
      onSessionWarning: onSessionWarning,
    );
    return _instance!;
  }

  // Callbacks
  final Function? onSessionExpired;
  final Function? onSessionWarning;

  // Set the context for showing dialogs
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Load timeout setting from shared preferences
  Future<void> _loadTimeoutSetting() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final minutes = prefs.getInt(timeoutSettingKey);

      if (minutes != null && minutes > 0) {
        _timeoutDuration = Duration(minutes: minutes);
      }
    } catch (e) {
      debugPrint('Error loading timeout setting: $e');
    }
  }

  /// Save timeout setting to shared preferences
  Future<void> _saveTimeoutSetting(int minutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(timeoutSettingKey, minutes);
    } catch (e) {
      debugPrint('Error saving timeout setting: $e');
    }
  }

  /// Set the session timeout duration
  Future<void> setSessionTimeout(int minutes) async {
    if (minutes <= 0) return;

    _timeoutDuration = Duration(minutes: minutes);
    await _saveTimeoutSetting(minutes);
    _resetInactivityTimer();
  }

  /// Get the current session timeout in minutes
  int getSessionTimeoutMinutes() {
    return _timeoutDuration.inMinutes;
  }

  /// Start tracking user activity
  void _startActivityTracking() {
    _resetInactivityTimer();
  }

  /// Reset the inactivity timer
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _wasWarned = false;

    _inactivityTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final now = DateTime.now();
      final difference = now.difference(_lastActivity);

      // Check if session is about to expire (80% of timeout)
      if (!_wasWarned &&
          difference.inMilliseconds >
              _timeoutDuration.inMilliseconds * _warningThreshold) {
        _showSessionWarning();
        _wasWarned = true;
      }

      // Check if session has expired
      if (difference >= _timeoutDuration) {
        _handleSessionExpired();
        timer.cancel();
      }
    });
  }

  /// Record user activity to extend session
  void recordUserActivity() {
    _lastActivity = DateTime.now();

    // Reset warning flag
    if (_wasWarned) {
      _wasWarned = false;
    }
  }

  /// Show warning when session is about to expire
  void _showSessionWarning() {
    // Invoke callback if provided
    onSessionWarning?.call();

    // Show warning dialog if context is available
    if (_context != null) {
      showDialog(
        context: _context!,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Session Timeout Warning'),
            content:
                const Text('Your session will expire soon due to inactivity. '
                    'Do you want to stay logged in?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleSessionExpired();
                },
                child: const Text('Logout'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  recordUserActivity();
                },
                child: const Text('Stay Logged In'),
              ),
            ],
          );
        },
      );
    }
  }

  /// Handle session expiration
  void _handleSessionExpired() {
    // Invoke callback if provided
    onSessionExpired?.call();

    // Log out user if auth provider is available
    if (_authProvider != null && _sessionProvider != null) {
      _authProvider!.signOut();
      _sessionProvider!.clearUser();

      // Show session expired dialog if context is available
      if (_context != null) {
        showDialog(
          context: _context!,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Session Expired'),
              content: const Text('Your session has expired due to inactivity. '
                  'Please log in again.'),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigation to login screen would be handled by authProvider
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  /// Cleanup resources
  void dispose() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }
}
