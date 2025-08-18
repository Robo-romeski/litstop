import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/fatigue_monitoring_provider.dart';
import '../screens/fatigue_settings_screen.dart';

/// Card widget that displays fatigue monitoring status and provides quick controls
class FatigueMonitoringCard extends StatelessWidget {
  /// Whether to show the full card or a compact version
  final bool compact;

  /// Callback when monitoring is toggled
  final VoidCallback? onMonitoringToggled;

  const FatigueMonitoringCard({
    super.key,
    this.compact = false,
    this.onMonitoringToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<FatigueMonitoringProvider>(
      builder: (context, fatigueProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with title and settings button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.timer,
                          color: fatigueProvider.isMonitoring
                              ? Theme.of(context).primaryColor
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Fatigue Monitoring',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Settings button
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () => _openSettings(context),
                          tooltip: 'Settings',
                        ),
                        // Toggle switch
                        Switch(
                          value: fatigueProvider.isMonitoring,
                          onChanged: (enabled) =>
                              _toggleMonitoring(context, enabled),
                        ),
                      ],
                    ),
                  ],
                ),

                if (!compact) ...[
                  const SizedBox(height: 12),

                  // Current status
                  _buildStatusSection(context, fatigueProvider),

                  const SizedBox(height: 12),

                  // Progress indicators
                  _buildProgressSection(context, fatigueProvider),
                ],

                if (compact) ...[
                  const SizedBox(height: 8),
                  _buildCompactStatus(context, fatigueProvider),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Build status section for full card
  Widget _buildStatusSection(
      BuildContext context, FatigueMonitoringProvider provider) {
    if (!provider.isMonitoring) {
      return const Text(
        'Monitoring is disabled',
        style: TextStyle(color: Colors.grey),
      );
    }

    if (provider.isCurrentlyOnBreak) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_cafe, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Text(
                'On Break',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Break time: ${provider.formattedCurrentBreakTime}'),
          if (provider.currentBreakMinutes < provider.minimumBreakMinutes)
            Text(
              'Minimum break: ${_formatDuration(provider.minimumBreakMinutes)}',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.drive_eta,
              color: provider.shouldTakeBreak ? Colors.red : Colors.blue,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Driving',
              style: TextStyle(
                color: provider.shouldTakeBreak ? Colors.red : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Continuous driving: ${provider.formattedContinuousDrivingTime}'),
        if (provider.shouldTakeBreak)
          const Text(
            'You should take a break!',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
      ],
    );
  }

  /// Build progress section showing time until alerts
  Widget _buildProgressSection(
      BuildContext context, FatigueMonitoringProvider provider) {
    if (!provider.isMonitoring || provider.isCurrentlyOnBreak) {
      return const SizedBox.shrink();
    }

    final currentMinutes = provider.currentContinuousDrivingMinutes;
    final maxMinutes = provider.maxContinuousDrivingMinutes;
    final progress = (currentMinutes / maxMinutes).clamp(0.0, 1.0);

    Color progressColor;
    if (provider.shouldTakeBreak) {
      progressColor = Colors.red;
    } else if (provider.hasShownReminder2) {
      progressColor = Colors.orange;
    } else if (provider.hasShownReminder1) {
      progressColor = Colors.yellow;
    } else {
      progressColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Driving time', style: TextStyle(fontSize: 12)),
            Text(
              '${provider.formattedContinuousDrivingTime} / ${_formatDuration(maxMinutes)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(progressColor),
        ),
        if (!provider.shouldTakeBreak) ...[
          const SizedBox(height: 8),
          _buildTimeUntilAlerts(context, provider),
        ],
      ],
    );
  }

  /// Build time until next alert
  Widget _buildTimeUntilAlerts(
      BuildContext context, FatigueMonitoringProvider provider) {
    String nextAlert;
    int minutesUntil;

    if (!provider.hasShownReminder1) {
      nextAlert = 'First reminder';
      minutesUntil = provider.minutesUntilReminder1;
    } else if (!provider.hasShownReminder2) {
      nextAlert = 'Second reminder';
      minutesUntil = provider.minutesUntilReminder2;
    } else {
      nextAlert = 'Final alert';
      minutesUntil = provider.minutesUntilFinalAlert;
    }

    if (minutesUntil <= 0) {
      return const SizedBox.shrink();
    }

    return Text(
      '$nextAlert in ${_formatDuration(minutesUntil)}',
      style: const TextStyle(fontSize: 12, color: Colors.grey),
    );
  }

  /// Build compact status for small card
  Widget _buildCompactStatus(
      BuildContext context, FatigueMonitoringProvider provider) {
    if (!provider.isMonitoring) {
      return const Text(
        'Monitoring disabled',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      );
    }

    if (provider.isCurrentlyOnBreak) {
      return Text(
        'On break: ${provider.formattedCurrentBreakTime}',
        style: const TextStyle(color: Colors.green, fontSize: 12),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'Driving: ${provider.formattedContinuousDrivingTime}',
            style: TextStyle(
              fontSize: 12,
              color: provider.shouldTakeBreak ? Colors.red : null,
            ),
          ),
        ),
        if (provider.shouldTakeBreak)
          const Icon(Icons.warning, color: Colors.red, size: 16),
      ],
    );
  }

  /// Toggle monitoring on/off
  Future<void> _toggleMonitoring(BuildContext context, bool enabled) async {
    final provider =
        Provider.of<FatigueMonitoringProvider>(context, listen: false);

    try {
      if (enabled) {
        await provider.startMonitoring();
      } else {
        await provider.stopMonitoring();
      }

      onMonitoringToggled?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Failed to ${enabled ? 'start' : 'stop'} monitoring: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Open settings screen
  void _openSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FatigueSettingsScreen(),
      ),
    );
  }

  /// Format duration consistently with the app style
  String _formatDuration(int minutes) {
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
}

/// Quick action widget for starting/ending breaks
class FatigueBreakControl extends StatelessWidget {
  const FatigueBreakControl({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FatigueMonitoringProvider>(
      builder: (context, provider, child) {
        if (!provider.isMonitoring) {
          return const SizedBox.shrink();
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  provider.isCurrentlyOnBreak
                      ? 'Currently on break'
                      : 'Need a break?',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                if (provider.isCurrentlyOnBreak) ...[
                  Text(
                    'Break time: ${provider.formattedCurrentBreakTime}',
                    style: const TextStyle(color: Colors.green),
                  ),
                  if (provider.currentBreakMinutes >=
                      provider.minimumBreakMinutes)
                    const Text(
                      '✓ Minimum break time reached',
                      style: TextStyle(color: Colors.green, fontSize: 12),
                    )
                  else
                    Text(
                      'Minimum: ${_formatDuration(provider.minimumBreakMinutes)}',
                      style:
                          const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _endBreak(context, provider),
                      child: const Text('End Break'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Driving: ${provider.formattedContinuousDrivingTime}',
                    style: TextStyle(
                      color: provider.shouldTakeBreak ? Colors.red : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _startBreak(context, provider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            provider.shouldTakeBreak ? Colors.red : null,
                      ),
                      child: const Text('Start Break'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Start a break
  Future<void> _startBreak(
      BuildContext context, FatigueMonitoringProvider provider) async {
    try {
      await provider.startBreak();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Break started'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start break: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// End a break
  Future<void> _endBreak(
      BuildContext context, FatigueMonitoringProvider provider) async {
    try {
      await provider.endBreak();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.currentBreakMinutes >= provider.minimumBreakMinutes
                  ? 'Break ended - you\'re refreshed!'
                  : 'Break ended - consider taking a longer break next time',
            ),
            backgroundColor:
                provider.currentBreakMinutes >= provider.minimumBreakMinutes
                    ? Colors.green
                    : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end break: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Format duration consistently with the app style
  String _formatDuration(int minutes) {
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
}
