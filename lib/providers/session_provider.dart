import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/secure_storage.dart';
import 'dart:convert';

class AppUser {
  final String id;
  final String email;
  final String name;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
  });
}

class SessionProvider with ChangeNotifier {
  String _userId = '';
  String _userName = '';
  String _userEmail = '';
  DateTime? _sessionStart;
  DateTime? _sessionEnd;
  bool _isSessionActive = false;
  bool _isAuthenticated = false;
  DateTime _lastActivity = DateTime.now();

  // Session timeout in minutes (default: 20 minutes)
  int _sessionTimeout = 20;

  // Secure storage instance
  final SecureStorage _secureStorage = SecureStorage();

  // Session metrics
  double _totalDistance = 0.0; // In miles
  double _totalEarnings = 0.0; // In dollars
  int _totalRides = 0;
  int _totalTime = 0; // In minutes

  // Getters
  String get userId => _userId;
  String get userName => _userName;
  String get userEmail => _userEmail;
  DateTime? get sessionStart => _sessionStart;
  DateTime? get sessionEnd => _sessionEnd;
  bool get isSessionActive => _isSessionActive;
  bool get isAuthenticated => _isAuthenticated;
  double get totalDistance => _totalDistance;
  double get totalEarnings => _totalEarnings;
  int get totalRides => _totalRides;
  int get totalTime => _totalTime;
  int get sessionTimeout => _sessionTimeout;
  DateTime get lastActivity => _lastActivity;

  // Session duration in minutes
  int get sessionDuration {
    if (!_isSessionActive || _sessionStart == null) return 0;

    final now = DateTime.now();
    return now.difference(_sessionStart!).inMinutes;
  }

  // Formatted session time
  String get formattedSessionTime {
    final duration = sessionDuration;
    final hours = duration ~/ 60;
    final minutes = duration % 60;

    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  // Average earnings per hour
  double get averageEarningsPerHour {
    if (sessionDuration <= 0) return 0;

    return (_totalEarnings * 60) / sessionDuration;
  }

  // Average ride value
  double get averageRideValue {
    if (_totalRides <= 0) return 0;

    return _totalEarnings / _totalRides;
  }

  // Formatted session start time
  String get formattedSessionStart {
    if (_sessionStart == null) return 'Not started';

    return DateFormat('MMM d, h:mm a').format(_sessionStart!);
  }

  SessionProvider() {
    _loadSessionData();
  }

  Future<void> _loadSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load user ID - this is not sensitive so we can use shared preferences
      _userId = prefs.getString('user_id') ?? '';
      _isAuthenticated = prefs.getBool('is_authenticated') ?? false;

      // Load session timeout setting
      _sessionTimeout = prefs.getInt('session_timeout_minutes') ?? 20;

      // Load sensitive data from secure storage if user ID is available
      if (_userId.isNotEmpty) {
        final userDataString =
            await _secureStorage.readSecure('user_data_$_userId');
        if (userDataString != null) {
          try {
            // Simple string splitting approach since we're not using complex JSON
            final dataParts = userDataString.split('|');
            if (dataParts.length >= 2) {
              _userName = dataParts[0];
              _userEmail = dataParts[1];
            }
          } catch (e) {
            debugPrint('Error parsing user data: $e');
          }
        }
      }

      // Load active session data if exists
      final hasActiveSession = prefs.getBool('is_session_active') ?? false;

      if (hasActiveSession) {
        final startTimeMillis = prefs.getInt('session_start_time') ?? 0;

        if (startTimeMillis > 0) {
          _sessionStart = DateTime.fromMillisecondsSinceEpoch(startTimeMillis);
          _isSessionActive = true;

          // Load metrics
          _totalDistance = prefs.getDouble('total_distance') ?? 0.0;
          _totalEarnings = prefs.getDouble('total_earnings') ?? 0.0;
          _totalRides = prefs.getInt('total_rides') ?? 0;
          _totalTime = prefs.getInt('total_time') ?? 0;
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading session data: $e');
    }
  }

  // Set session timeout duration
  Future<void> setSessionTimeout(int minutes) async {
    if (minutes <= 0) return;

    _sessionTimeout = minutes;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('session_timeout_minutes', minutes);
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting session timeout: $e');
    }
  }

  // Record user activity to extend session
  void recordUserActivity() {
    _lastActivity = DateTime.now();
  }

  // Check if session is timed out
  bool isSessionTimedOut() {
    if (!_isAuthenticated) return false;

    final now = DateTime.now();
    final difference = now.difference(_lastActivity);

    return difference.inMinutes >= _sessionTimeout;
  }

  // Set user data when logged in
  Future<void> setUser({
    required String id,
    required String email,
    required String name,
  }) async {
    _userId = id;
    _userEmail = email;
    _userName = name;
    _isAuthenticated = true;
    _lastActivity = DateTime.now();

    try {
      final prefs = await SharedPreferences.getInstance();
      // Store non-sensitive data in shared preferences
      await prefs.setString('user_id', id);
      await prefs.setBool('is_authenticated', true);

      // Store sensitive data in secure storage
      final userData = '$name|$email';
      await _secureStorage.writeSecure('user_data_$id', userData);

      notifyListeners();
    } catch (e) {
      debugPrint('Error saving user data: $e');
    }
  }

  // Update user name
  Future<void> updateUserName(String newName) async {
    _userName = newName;

    try {
      // Update secure storage with new name
      final userData = '$newName|$_userEmail';
      await _secureStorage.writeSecure('user_data_$_userId', userData);

      notifyListeners();
    } catch (e) {
      debugPrint('Error updating user name: $e');
    }
  }

  // Clear user data when logged out
  Future<void> clearUser() async {
    // End session if active
    if (_isSessionActive) {
      await endSession();
    }

    _userId = '';
    _userEmail = '';
    _userName = '';
    _isAuthenticated = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.setBool('is_authenticated', false);

      // Note: We don't delete secure data here - it's kept encrypted
      // for potential future logins. For a real security feature,
      // you might want to add an explicit option to clear all data.

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing user data: $e');
    }
  }

  // Start a new driving session
  Future<void> startSession() async {
    if (_isSessionActive) return;

    _sessionStart = DateTime.now();
    _sessionEnd = null;
    _isSessionActive = true;
    _lastActivity = DateTime.now();

    // Reset metrics
    _totalDistance = 0.0;
    _totalEarnings = 0.0;
    _totalRides = 0;
    _totalTime = 0;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_session_active', true);
      await prefs.setInt(
          'session_start_time', _sessionStart!.millisecondsSinceEpoch);

      // Save initial metrics
      await prefs.setDouble('total_distance', _totalDistance);
      await prefs.setDouble('total_earnings', _totalEarnings);
      await prefs.setInt('total_rides', _totalRides);
      await prefs.setInt('total_time', _totalTime);

      notifyListeners();
    } catch (e) {
      debugPrint('Error starting session: $e');
    }
  }

  // End the current driving session
  Future<void> endSession() async {
    if (!_isSessionActive) return;

    _sessionEnd = DateTime.now();
    _isSessionActive = false;
    _lastActivity = DateTime.now();

    // Calculate final session time
    if (_sessionStart != null) {
      _totalTime = _sessionEnd!.difference(_sessionStart!).inMinutes;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_session_active', false);
      await prefs.setInt(
          'session_end_time', _sessionEnd!.millisecondsSinceEpoch);

      // Save final session metrics to history
      final sessionId = DateTime.now().millisecondsSinceEpoch.toString();

      // Save session history to secure storage for privacy
      // Create session data object
      final sessionData = {
        'id': sessionId,
        'startTime': _sessionStart?.millisecondsSinceEpoch.toString() ?? '0',
        'endTime': _sessionEnd?.millisecondsSinceEpoch.toString() ?? '0',
        'totalDistance': _totalDistance.toString(),
        'totalEarnings': _totalEarnings.toString(),
        'totalRides': _totalRides.toString(),
        'totalTime': _totalTime.toString(),
      };

      // Get existing history
      final existingHistoryString =
          await _secureStorage.readSecure('session_history_$_userId');
      List<Map<String, dynamic>> sessionHistory = [];

      if (existingHistoryString != null) {
        try {
          // Simple conversion from string to list of sessions
          final List<String> sessions = existingHistoryString.split('||');
          for (final session in sessions) {
            if (session.isNotEmpty) {
              final sessionMap = <String, dynamic>{};
              final parts = session.split('|');
              if (parts.length >= 7) {
                sessionMap['id'] = parts[0];
                sessionMap['startTime'] = parts[1];
                sessionMap['endTime'] = parts[2];
                sessionMap['totalDistance'] = parts[3];
                sessionMap['totalEarnings'] = parts[4];
                sessionMap['totalRides'] = parts[5];
                sessionMap['totalTime'] = parts[6];
                sessionHistory.add(sessionMap);
              }
            }
          }
        } catch (e) {
          debugPrint('Error parsing session history: $e');
        }
      }

      // Add new session
      sessionHistory.add(sessionData);

      // Limit history to last 50 sessions
      if (sessionHistory.length > 50) {
        sessionHistory = sessionHistory.sublist(sessionHistory.length - 50);
      }

      // Convert back to string
      final newHistoryString = sessionHistory.map((session) {
        return '${session['id']}|${session['startTime']}|${session['endTime']}|'
            '${session['totalDistance']}|${session['totalEarnings']}|'
            '${session['totalRides']}|${session['totalTime']}';
      }).join('||');

      // Save encrypted session history
      await _secureStorage.writeSecure(
          'session_history_$_userId', newHistoryString);

      notifyListeners();
    } catch (e) {
      debugPrint('Error ending session: $e');
    }
  }

  // Update session metrics
  void updateMetrics({
    double? distance,
    double? earnings,
    int? rides,
  }) {
    if (!_isSessionActive) return;

    if (distance != null) _totalDistance += distance;
    if (earnings != null) _totalEarnings += earnings;
    if (rides != null) _totalRides += rides;

    // Record activity to keep session alive
    recordUserActivity();

    _saveMetrics();
    notifyListeners();
  }

  // Save current metrics to SharedPreferences
  Future<void> _saveMetrics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('total_distance', _totalDistance);
      await prefs.setDouble('total_earnings', _totalEarnings);
      await prefs.setInt('total_rides', _totalRides);
    } catch (e) {
      debugPrint('Error saving metrics: $e');
    }
  }

  // Get session history
  Future<List<Map<String, dynamic>>> getSessionHistory() async {
    try {
      final historyString =
          await _secureStorage.readSecure('session_history_$_userId');
      if (historyString == null || historyString.isEmpty) {
        return [];
      }

      // Parse the session history string
      final List<String> sessions = historyString.split('||');
      final sessionHistory = <Map<String, dynamic>>[];

      for (final session in sessions) {
        if (session.isNotEmpty) {
          final sessionMap = <String, dynamic>{};
          final parts = session.split('|');
          if (parts.length >= 7) {
            sessionMap['id'] = parts[0];
            sessionMap['startTime'] = parts[1];
            sessionMap['endTime'] = parts[2];
            sessionMap['totalDistance'] = parts[3];
            sessionMap['totalEarnings'] = parts[4];
            sessionMap['totalRides'] = parts[5];
            sessionMap['totalTime'] = parts[6];
            sessionHistory.add(sessionMap);
          }
        }
      }

      return sessionHistory;
    } catch (e) {
      debugPrint('Error getting session history: $e');
      return [];
    }
  }
}
