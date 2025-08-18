import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/fatigue_alert_service.dart';
import '../providers/fatigue_monitoring_provider.dart';
import '../widgets/fatigue_alert_dialog.dart';
import '../widgets/fatigue_monitoring_card.dart';

class FatigueTestScreen extends StatefulWidget {
  const FatigueTestScreen({super.key});

  @override
  State<FatigueTestScreen> createState() => _FatigueTestScreenState();
}

class _FatigueTestScreenState extends State<FatigueTestScreen> {
  final FatigueAlertService _alertService = FatigueAlertService();
  bool _isAlertServiceInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeAlertService();
  }

  Future<void> _initializeAlertService() async {
    await _alertService.initialize();
    setState(() {
      _isAlertServiceInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fatigue Alert System Test'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isAlertServiceInitialized
          ? _buildTestContent()
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildTestContent() {
    return Consumer<FatigueMonitoringProvider>(
      builder: (context, fatigueProvider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fatigue Monitoring Card Test
              const Text(
                'Fatigue Monitoring Card',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const FatigueMonitoringCard(),

              const SizedBox(height: 24),

              // Monitoring Controls
              _buildMonitoringControls(fatigueProvider),

              const SizedBox(height: 24),

              // Alert Type Tests
              _buildAlertTests(),

              const SizedBox(height: 24),

              // System Information
              _buildSystemInfo(fatigueProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMonitoringControls(FatigueMonitoringProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Monitoring Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isMonitoring
                        ? null
                        : () => provider.startMonitoring(),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Monitoring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isMonitoring
                        ? () => provider.stopMonitoring()
                        : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Monitoring'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        provider.isMonitoring && !provider.isCurrentlyOnBreak
                            ? () => provider.startBreak()
                            : null,
                    icon: const Icon(Icons.local_cafe),
                    label: const Text('Start Break'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: provider.isCurrentlyOnBreak
                        ? () => provider.endBreak()
                        : null,
                    icon: const Icon(Icons.drive_eta),
                    label: const Text('End Break'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => provider.resetAlerts(),
              icon: const Icon(Icons.refresh),
              label: const Text('Reset Alerts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTests() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Alert System Tests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Reminder alerts
            _buildAlertTestButton(
              'Test Reminder 1 (Info)',
              FatigueAlertType.reminder1,
              Icons.info_outline,
              Colors.blue,
            ),

            const SizedBox(height: 8),

            _buildAlertTestButton(
              'Test Reminder 2 (Warning)',
              FatigueAlertType.reminder2,
              Icons.warning_amber,
              Colors.orange,
            ),

            const SizedBox(height: 8),

            _buildAlertTestButton(
              'Test Final Alert (Critical)',
              FatigueAlertType.finalAlert,
              Icons.error_outline,
              Colors.red,
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 16),

            // Break alerts
            _buildAlertTestButton(
              'Test Break Started',
              FatigueAlertType.breakStarted,
              Icons.local_cafe,
              Colors.green,
            ),

            const SizedBox(height: 8),

            _buildAlertTestButton(
              'Test Break Ended',
              FatigueAlertType.breakEnded,
              Icons.check_circle,
              Colors.blue,
            ),

            const SizedBox(height: 8),

            _buildAlertTestButton(
              'Test Auto Break Detected',
              FatigueAlertType.automaticBreakDetected,
              Icons.pause_circle_filled,
              Colors.teal,
            ),

            const SizedBox(height: 16),

            const Divider(),

            const SizedBox(height: 16),

            // Special tests
            ElevatedButton.icon(
              onPressed: _testBannerAlert,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Test Banner Alert (5s duration)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _testFullScreenDialog,
              icon: const Icon(Icons.fullscreen),
              label: const Text('Test Full-Screen Critical Dialog'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[800],
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            ElevatedButton.icon(
              onPressed: _clearAllAlerts,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All Alerts'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[700],
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertTestButton(
    String label,
    FatigueAlertType alertType,
    IconData icon,
    Color color,
  ) {
    return ElevatedButton.icon(
      onPressed: () => _testAlert(alertType),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildSystemInfo(FatigueMonitoringProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'System Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
                'Monitoring Active', provider.isMonitoring.toString()),
            _buildInfoRow(
                'Currently on Break', provider.isCurrentlyOnBreak.toString()),
            _buildInfoRow('Continuous Driving Time',
                provider.formattedContinuousDrivingTime),
            _buildInfoRow(
                'Current Break Time', provider.formattedCurrentBreakTime),
            _buildInfoRow('Minutes Until Reminder 1',
                '${provider.minutesUntilReminder1} min'),
            _buildInfoRow('Minutes Until Reminder 2',
                '${provider.minutesUntilReminder2} min'),
            _buildInfoRow('Minutes Until Final Alert',
                '${provider.minutesUntilFinalAlert} min'),
            _buildInfoRow(
                'Should Take Break', provider.shouldTakeBreak.toString()),
            _buildInfoRow(
                'Reminder 1 Shown', provider.hasShownReminder1.toString()),
            _buildInfoRow(
                'Reminder 2 Shown', provider.hasShownReminder2.toString()),
            _buildInfoRow(
                'Final Alert Shown', provider.hasShownFinalAlert.toString()),
            if (provider.continuousDrivingStart != null)
              _buildInfoRow('Driving Started',
                  provider.continuousDrivingStart!.toString().substring(0, 19)),
            if (provider.lastBreakTime != null)
              _buildInfoRow('Last Break',
                  provider.lastBreakTime!.toString().substring(0, 19)),
            if (provider.currentBreakStart != null)
              _buildInfoRow('Current Break Started',
                  provider.currentBreakStart!.toString().substring(0, 19)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  // Test methods
  void _testAlert(FatigueAlertType alertType) {
    _alertService.showAlert(
      alertType,
      drivingTime: const Duration(hours: 2, minutes: 15),
      breakTime: const Duration(minutes: 20),
      action: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert action triggered!')),
        );
      },
    );
  }

  void _testBannerAlert() {
    // Trigger a banner alert via the alert service
    _alertService.showAlert(
      FatigueAlertType.reminder1,
      drivingTime: const Duration(hours: 1, minutes: 30),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Banner alert triggered!')),
    );
  }

  void _testFullScreenDialog() {
    final alertData = FatigueAlertData(
      type: FatigueAlertType.finalAlert,
      severity: FatigueAlertSeverity.critical,
      title: 'CRITICAL SAFETY ALERT',
      message:
          'This is a test of the critical full-screen alert dialog. In real use, this would appear when the driver has been driving for too long.',
      voiceMessage: 'Critical safety alert! Take a break immediately!',
      timestamp: DateTime.now(),
      drivingTime: const Duration(hours: 2, minutes: 30),
    );

    FatigueAlertDialog.show(
      context,
      alertData,
      onAction: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Critical alert action: Find rest stop!'),
            backgroundColor: Colors.red,
          ),
        );
      },
    );
  }

  void _clearAllAlerts() {
    _alertService.clearAllAlerts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All alerts cleared')),
    );
  }

  @override
  void dispose() {
    // Don't dispose the alert service here as it's a singleton
    super.dispose();
  }
}
