import 'dart:async';
import 'package:flutter/material.dart';
import '../services/fatigue_alert_service.dart';
import 'fatigue_alert_dialog.dart';

/// Widget that manages and displays fatigue alerts from the alert service
class FatigueAlertManager extends StatefulWidget {
  final Widget child;
  final VoidCallback? onRestStopRequested;

  const FatigueAlertManager({
    super.key,
    required this.child,
    this.onRestStopRequested,
  });

  @override
  State<FatigueAlertManager> createState() => _FatigueAlertManagerState();
}

class _FatigueAlertManagerState extends State<FatigueAlertManager>
    with TickerProviderStateMixin {
  final FatigueAlertService _alertService = FatigueAlertService();

  late StreamSubscription<FatigueAlertData> _inAppAlertSubscription;
  late StreamSubscription<FatigueAlertData> _bannerAlertSubscription;
  late StreamSubscription<FatigueAlertData> _voiceAlertSubscription;

  // Banner alert state
  FatigueAlertData? _currentBannerAlert;
  late AnimationController _bannerAnimationController;
  late Animation<Offset> _bannerSlideAnimation;
  Timer? _bannerDismissTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupAlertListeners();
  }

  /// Initialize animations
  void _initializeAnimations() {
    _bannerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bannerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  /// Set up alert stream listeners
  void _setupAlertListeners() {
    // Listen for in-app alerts (dialogs)
    _inAppAlertSubscription = _alertService.inAppAlerts.listen((alertData) {
      _showInAppAlert(alertData);
    });

    // Listen for banner alerts
    _bannerAlertSubscription = _alertService.bannerAlerts.listen((alertData) {
      _showBannerAlert(alertData);
    });

    // Listen for voice alerts (handled by voice alert integration in subtask 9.4)
    _voiceAlertSubscription = _alertService.voiceAlerts.listen((alertData) {
      _handleVoiceAlert(alertData);
    });
  }

  /// Show in-app alert dialog
  void _showInAppAlert(FatigueAlertData alertData) {
    if (!mounted) return;

    FatigueAlertDialog.show(
      context,
      alertData,
      onAction: () {
        // Handle action (e.g., find rest stop)
        widget.onRestStopRequested?.call();
      },
      onDismiss: () {
        // Alert dismissed
      },
    );
  }

  /// Show banner alert
  void _showBannerAlert(FatigueAlertData alertData) {
    if (!mounted) return;

    setState(() {
      _currentBannerAlert = alertData;
    });

    // Animate banner in
    _bannerAnimationController.forward();

    // Auto-dismiss after 5 seconds for non-critical alerts
    _bannerDismissTimer?.cancel();
    if (alertData.severity != FatigueAlertSeverity.critical) {
      _bannerDismissTimer = Timer(const Duration(seconds: 5), () {
        _dismissBannerAlert();
      });
    }
  }

  /// Handle voice alert (placeholder for voice integration)
  void _handleVoiceAlert(FatigueAlertData alertData) {
    // This will be implemented in subtask 9.4 (Voice Alert Integration)
    debugPrint('Voice alert: ${alertData.voiceMessage}');
  }

  /// Dismiss banner alert
  void _dismissBannerAlert() {
    if (!mounted) return;

    _bannerAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentBannerAlert = null;
        });
        _alertService.clearBannerAlert();
      }
    });

    _bannerDismissTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Main app content
          widget.child,

          // Banner alert overlay
          if (_currentBannerAlert != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: SlideTransition(
                  position: _bannerSlideAnimation,
                  child: FatigueAlertBanner(
                    alertData: _currentBannerAlert!,
                    onTap: () {
                      // Show full alert dialog when banner is tapped
                      _showInAppAlert(_currentBannerAlert!);
                      _dismissBannerAlert();
                    },
                    onDismiss: _dismissBannerAlert,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _inAppAlertSubscription.cancel();
    _bannerAlertSubscription.cancel();
    _voiceAlertSubscription.cancel();
    _bannerAnimationController.dispose();
    _bannerDismissTimer?.cancel();
    super.dispose();
  }
}

/// Overlay widget for showing banner alerts that doesn't require wrapping the entire app
class FatigueAlertOverlay extends StatefulWidget {
  final VoidCallback? onRestStopRequested;

  const FatigueAlertOverlay({
    super.key,
    this.onRestStopRequested,
  });

  @override
  State<FatigueAlertOverlay> createState() => _FatigueAlertOverlayState();
}

class _FatigueAlertOverlayState extends State<FatigueAlertOverlay>
    with TickerProviderStateMixin {
  final FatigueAlertService _alertService = FatigueAlertService();

  late StreamSubscription<FatigueAlertData> _bannerAlertSubscription;

  FatigueAlertData? _currentBannerAlert;
  late AnimationController _bannerAnimationController;
  late Animation<Offset> _bannerSlideAnimation;
  Timer? _bannerDismissTimer;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setupBannerListener();
  }

  /// Initialize animations
  void _initializeAnimations() {
    _bannerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _bannerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _bannerAnimationController,
      curve: Curves.easeOutBack,
    ));
  }

  /// Set up banner alert listener
  void _setupBannerListener() {
    _bannerAlertSubscription = _alertService.bannerAlerts.listen((alertData) {
      _showBannerAlert(alertData);
    });
  }

  /// Show banner alert
  void _showBannerAlert(FatigueAlertData alertData) {
    if (!mounted) return;

    setState(() {
      _currentBannerAlert = alertData;
    });

    _bannerAnimationController.forward();

    _bannerDismissTimer?.cancel();
    if (alertData.severity != FatigueAlertSeverity.critical) {
      _bannerDismissTimer = Timer(const Duration(seconds: 5), () {
        _dismissBannerAlert();
      });
    }
  }

  /// Dismiss banner alert
  void _dismissBannerAlert() {
    if (!mounted) return;

    _bannerAnimationController.reverse().then((_) {
      if (mounted) {
        setState(() {
          _currentBannerAlert = null;
        });
        _alertService.clearBannerAlert();
      }
    });

    _bannerDismissTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentBannerAlert == null) {
      return const SizedBox.shrink();
    }

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          child: SlideTransition(
            position: _bannerSlideAnimation,
            child: FatigueAlertBanner(
              alertData: _currentBannerAlert!,
              onTap: () {
                // Show full alert dialog when banner is tapped
                if (context.mounted) {
                  FatigueAlertDialog.show(
                    context,
                    _currentBannerAlert!,
                    onAction: widget.onRestStopRequested,
                  );
                }
                _dismissBannerAlert();
              },
              onDismiss: _dismissBannerAlert,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bannerAlertSubscription.cancel();
    _bannerAnimationController.dispose();
    _bannerDismissTimer?.cancel();
    super.dispose();
  }
}

/// In-app alert listener for dialogs (no banner)
class FatigueDialogListener extends StatefulWidget {
  final VoidCallback? onRestStopRequested;

  const FatigueDialogListener({
    super.key,
    this.onRestStopRequested,
  });

  @override
  State<FatigueDialogListener> createState() => _FatigueDialogListenerState();
}

class _FatigueDialogListenerState extends State<FatigueDialogListener> {
  final FatigueAlertService _alertService = FatigueAlertService();
  late StreamSubscription<FatigueAlertData> _inAppAlertSubscription;

  @override
  void initState() {
    super.initState();
    _setupDialogListener();
  }

  /// Set up in-app alert listener
  void _setupDialogListener() {
    _inAppAlertSubscription = _alertService.inAppAlerts.listen((alertData) {
      _showInAppAlert(alertData);
    });
  }

  /// Show in-app alert dialog
  void _showInAppAlert(FatigueAlertData alertData) {
    if (!mounted) return;

    FatigueAlertDialog.show(
      context,
      alertData,
      onAction: widget.onRestStopRequested,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    _inAppAlertSubscription.cancel();
    super.dispose();
  }
}
