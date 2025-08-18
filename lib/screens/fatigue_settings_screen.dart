import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fatigue_alert_settings.dart';
import '../providers/fatigue_monitoring_provider.dart';

/// Screen for configuring fatigue alert settings and thresholds
class FatigueSettingsScreen extends StatefulWidget {
  const FatigueSettingsScreen({super.key});

  @override
  State<FatigueSettingsScreen> createState() => _FatigueSettingsScreenState();
}

class _FatigueSettingsScreenState extends State<FatigueSettingsScreen> {
  // Current settings being edited
  late FatigueAlertSettings _currentSettings;

  // Loading and error states
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  // Preferences key for settings storage
  static const String _settingsKey = 'fatigue_alert_settings';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Load settings from storage
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_settingsKey);

      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _currentSettings = FatigueAlertSettings.fromJson(settingsMap);
      } else {
        _currentSettings = const FatigueAlertSettings();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load settings: $e';
        _currentSettings = const FatigueAlertSettings();
      });
    }
  }

  /// Save settings to storage and update provider
  Future<void> _saveSettings() async {
    // Validate settings first
    final validationErrors = _currentSettings.validate();
    if (validationErrors.isNotEmpty) {
      _showValidationErrors(validationErrors);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Get provider reference before async operations
      final fatigueProvider =
          Provider.of<FatigueMonitoringProvider>(context, listen: false);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(_currentSettings.toJson());
      await prefs.setString(_settingsKey, settingsJson);

      // Update fatigue monitoring provider
      await fatigueProvider.updateSettings(
        maxContinuousDrivingMinutes:
            _currentSettings.maxContinuousDrivingMinutes,
        breakReminder1Minutes: _currentSettings.breakReminder1Minutes,
        breakReminder2Minutes: _currentSettings.breakReminder2Minutes,
        minimumBreakMinutes: _currentSettings.minimumBreakMinutes,
        stationaryThresholdMinutes: _currentSettings.stationaryThresholdMinutes,
        movementThresholdMeters: _currentSettings.movementThresholdMeters,
      );

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save settings: $e';
      });
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  /// Show validation errors dialog
  void _showValidationErrors(List<String> errors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Settings Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please fix the following issues:'),
            const SizedBox(height: 8),
            ...errors.map((error) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $error',
                      style: const TextStyle(color: Colors.red)),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Reset to default settings
  void _resetToDefaults() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
            'Are you sure you want to reset all settings to their default values?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _currentSettings = const FatigueAlertSettings();
              });
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  /// Update a setting value
  void _updateSetting(FatigueAlertSettings newSettings) {
    setState(() {
      _currentSettings = newSettings;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fatigue Alert Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fatigue Alert Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetToDefaults,
            tooltip: 'Reset to defaults',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Error message
            if (_errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade800),
                ),
              ),

            // Master enable/disable switch
            _buildSectionCard(
              'Monitoring',
              [
                _buildSwitchTile(
                  'Enable Fatigue Monitoring',
                  'Monitor driving time and show alerts',
                  _currentSettings.isMonitoringEnabled,
                  (value) => _updateSetting(
                      _currentSettings.copyWith(isMonitoringEnabled: value)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Driving time thresholds
            _buildSectionCard(
              'Driving Time Thresholds',
              [
                _buildTimeSetting(
                  'Maximum Continuous Driving',
                  'Stop driving and take a break after this time',
                  _currentSettings.maxContinuousDrivingMinutes,
                  30, // min 30 minutes
                  480, // max 8 hours
                  (value) => _updateSetting(_currentSettings.copyWith(
                      maxContinuousDrivingMinutes: value)),
                ),
                _buildTimeSetting(
                  'First Reminder',
                  'Show first reminder at this time',
                  _currentSettings.breakReminder1Minutes,
                  30,
                  _currentSettings.maxContinuousDrivingMinutes - 15,
                  (value) => _updateSetting(
                      _currentSettings.copyWith(breakReminder1Minutes: value)),
                ),
                _buildTimeSetting(
                  'Second Reminder',
                  'Show second reminder at this time',
                  _currentSettings.breakReminder2Minutes,
                  _currentSettings.breakReminder1Minutes + 5,
                  _currentSettings.maxContinuousDrivingMinutes - 5,
                  (value) => _updateSetting(
                      _currentSettings.copyWith(breakReminder2Minutes: value)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Break settings
            _buildSectionCard(
              'Break Settings',
              [
                _buildTimeSetting(
                  'Minimum Break Duration',
                  'Minimum time for a break to be considered valid',
                  _currentSettings.minimumBreakMinutes,
                  5,
                  60,
                  (value) => _updateSetting(
                      _currentSettings.copyWith(minimumBreakMinutes: value)),
                ),
                _buildTimeSetting(
                  'Stationary Threshold',
                  'Auto-detect break after being stationary for this time',
                  _currentSettings.stationaryThresholdMinutes,
                  1,
                  30,
                  (value) => _updateSetting(_currentSettings.copyWith(
                      stationaryThresholdMinutes: value)),
                ),
                _buildSwitchTile(
                  'Automatic Break Detection',
                  'Automatically start breaks when stationary',
                  _currentSettings.enableAutomaticBreakDetection,
                  (value) => _updateSetting(_currentSettings.copyWith(
                      enableAutomaticBreakDetection: value)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Alert preferences
            _buildSectionCard(
              'Alert Preferences',
              [
                _buildSwitchTile(
                  'Voice Alerts',
                  'Play spoken alerts when fatigue thresholds are reached',
                  _currentSettings.enableVoiceAlerts,
                  (value) => _updateSetting(
                      _currentSettings.copyWith(enableVoiceAlerts: value)),
                ),
                _buildSwitchTile(
                  'Push Notifications',
                  'Show notifications even when app is in background',
                  _currentSettings.enablePushNotifications,
                  (value) => _updateSetting(_currentSettings.copyWith(
                      enablePushNotifications: value)),
                ),
                _buildSwitchTile(
                  'Vibration',
                  'Use vibration for alerts',
                  _currentSettings.enableVibration,
                  (value) => _updateSetting(
                      _currentSettings.copyWith(enableVibration: value)),
                ),
                _buildVolumeSetting(),
              ],
            ),

            const SizedBox(height: 16),

            // Additional features
            _buildSectionCard(
              'Additional Features',
              [
                _buildSwitchTile(
                  'Suggest Nearby Rest Areas',
                  'Show nearby rest stops when alerts trigger',
                  _currentSettings.suggestNearbyRestAreas,
                  (value) => _updateSetting(
                      _currentSettings.copyWith(suggestNearbyRestAreas: value)),
                ),
                _buildMovementThresholdSetting(),
              ],
            ),

            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Settings',
                        style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build a section card with title and children
  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  /// Build a switch tile
  Widget _buildSwitchTile(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }

  /// Build a time setting with slider
  Widget _buildTimeSetting(String title, String subtitle, int currentValue,
      int minValue, int maxValue, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Text(
            _currentSettings.formatDuration(currentValue),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        Slider(
          value: currentValue.toDouble(),
          min: minValue.toDouble(),
          max: maxValue.toDouble(),
          divisions: maxValue - minValue,
          label: _currentSettings.formatDuration(currentValue),
          onChanged: (value) => onChanged(value.round()),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Build volume setting
  Widget _buildVolumeSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Alert Volume'),
          subtitle: const Text('Volume level for alert sounds'),
          trailing: Text(
            '${(_currentSettings.alertVolume * 100).round()}%',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        Slider(
          value: _currentSettings.alertVolume,
          min: 0.0,
          max: 1.0,
          divisions: 10,
          label: '${(_currentSettings.alertVolume * 100).round()}%',
          onChanged: (value) =>
              _updateSetting(_currentSettings.copyWith(alertVolume: value)),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Build movement threshold setting
  Widget _buildMovementThresholdSetting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Movement Sensitivity'),
          subtitle: const Text('Minimum distance to detect driving movement'),
          trailing: Text(
            '${_currentSettings.movementThresholdMeters.round()}m',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          contentPadding: EdgeInsets.zero,
        ),
        Slider(
          value: _currentSettings.movementThresholdMeters,
          min: 10.0,
          max: 200.0,
          divisions: 19,
          label: '${_currentSettings.movementThresholdMeters.round()}m',
          onChanged: (value) => _updateSetting(
              _currentSettings.copyWith(movementThresholdMeters: value)),
        ),
      ],
    );
  }
}
