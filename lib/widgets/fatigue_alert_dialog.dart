import 'package:flutter/material.dart';
import '../services/fatigue_alert_service.dart';

/// Full-screen alert dialog for critical fatigue alerts
class FatigueAlertDialog extends StatelessWidget {
  final FatigueAlertData alertData;
  final VoidCallback? onDismiss;
  final VoidCallback? onAction;

  const FatigueAlertDialog({
    super.key,
    required this.alertData,
    this.onDismiss,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Alert icon based on severity
              _buildAlertIcon(),

              const SizedBox(height: 24),

              // Title
              Text(
                alertData.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Message
              Text(
                alertData.message,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontSize: 20,
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),

              if (alertData.drivingTime != null) ...[
                const SizedBox(height: 24),
                _buildDrivingTimeInfo(),
              ],

              const SizedBox(height: 48),

              // Action buttons
              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Build alert icon based on severity
  Widget _buildAlertIcon() {
    IconData iconData;
    Color iconColor;
    double iconSize = 80;

    switch (alertData.severity) {
      case FatigueAlertSeverity.info:
        iconData = Icons.info_outline;
        iconColor = Colors.blue;
        break;
      case FatigueAlertSeverity.warning:
        iconData = Icons.warning_amber;
        iconColor = Colors.orange;
        break;
      case FatigueAlertSeverity.critical:
        iconData = Icons.error_outline;
        iconColor = Colors.red;
        iconSize = 100;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: iconColor.withOpacity(0.2),
        border: Border.all(color: iconColor, width: 3),
      ),
      child: Icon(
        iconData,
        size: iconSize,
        color: iconColor,
      ),
    );
  }

  /// Build driving time information
  Widget _buildDrivingTimeInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(
            'Driving time: ${_formatDuration(alertData.drivingTime!)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons
  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // Primary action button
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: () {
              onAction?.call();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _getActionButtonColor(),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_getActionIcon(), size: 28),
                const SizedBox(width: 12),
                Text(
                  alertData.actionText,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),

        if (alertData.severity != FatigueAlertSeverity.critical) ...[
          const SizedBox(height: 16),

          // Dismiss button for non-critical alerts
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () {
                onDismiss?.call();
                Navigator.of(context).pop();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
              ),
              child: const Text(
                'Dismiss',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Get action button color based on severity
  Color _getActionButtonColor() {
    switch (alertData.severity) {
      case FatigueAlertSeverity.info:
        return Colors.blue;
      case FatigueAlertSeverity.warning:
        return Colors.orange;
      case FatigueAlertSeverity.critical:
        return Colors.red;
    }
  }

  /// Get action icon based on alert type
  IconData _getActionIcon() {
    switch (alertData.type) {
      case FatigueAlertType.reminder1:
      case FatigueAlertType.reminder2:
      case FatigueAlertType.finalAlert:
        return Icons.local_cafe;
      case FatigueAlertType.breakStarted:
      case FatigueAlertType.automaticBreakDetected:
        return Icons.check;
      case FatigueAlertType.breakEnded:
        return Icons.drive_eta;
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

  /// Show the alert dialog
  static Future<void> show(
    BuildContext context,
    FatigueAlertData alertData, {
    VoidCallback? onDismiss,
    VoidCallback? onAction,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: alertData.severity != FatigueAlertSeverity.critical,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FatigueAlertDialog(
          alertData: alertData,
          onDismiss: onDismiss,
          onAction: onAction,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// Compact banner alert for non-critical notifications
class FatigueAlertBanner extends StatelessWidget {
  final FatigueAlertData alertData;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const FatigueAlertBanner({
    super.key,
    required this.alertData,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getBannerColor(),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Alert icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getBannerIcon(),
                    color: Colors.white,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                // Alert content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alertData.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        alertData.message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Dismiss button
                if (onDismiss != null)
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, color: Colors.white),
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Get banner background color based on severity
  Color _getBannerColor() {
    switch (alertData.severity) {
      case FatigueAlertSeverity.info:
        return Colors.blue;
      case FatigueAlertSeverity.warning:
        return Colors.orange;
      case FatigueAlertSeverity.critical:
        return Colors.red;
    }
  }

  /// Get banner icon based on alert type
  IconData _getBannerIcon() {
    switch (alertData.type) {
      case FatigueAlertType.reminder1:
      case FatigueAlertType.reminder2:
        return Icons.timer;
      case FatigueAlertType.finalAlert:
        return Icons.warning;
      case FatigueAlertType.breakStarted:
      case FatigueAlertType.automaticBreakDetected:
        return Icons.local_cafe;
      case FatigueAlertType.breakEnded:
        return Icons.check_circle;
    }
  }
}
