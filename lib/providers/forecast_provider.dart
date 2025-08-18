import 'dart:async';
import 'package:flutter/foundation.dart';
import '../widgets/demand_forecast_chart.dart';
import '../widgets/zone_selection_component.dart';

/// Manages demand forecast data for the application.
/// Currently uses mock data but designed to be extended with real API data.
class ForecastProvider with ChangeNotifier {
  // Default refresh interval in minutes
  static const int defaultRefreshInterval = 15;

  // Store current forecast data
  List<TimeSeriesPoint> _hourlyForecast = [];
  List<TimeSeriesPoint> _dailyForecast = [];
  List<TimeSeriesPoint> _weeklyForecast = [];

  // Status tracking
  bool _isLoading = false;
  String? _error;
  DateTime? _lastUpdated;
  Timer? _refreshTimer;

  // Currently selected zone
  ForecastZone _selectedZone;

  // List of available zones (mock data)
  final List<ForecastZone> _availableZones = [
    const ForecastZone(
      id: 'downtown',
      name: 'Downtown',
      description:
          'City center with high business activity and entertainment venues',
    ),
    const ForecastZone(
      id: 'airport',
      name: 'Airport',
      description:
          'Airport and surrounding areas with consistent traveler demand',
    ),
    const ForecastZone(
      id: 'suburbs',
      name: 'Suburban Areas',
      description: 'Residential neighborhoods with commuter patterns',
    ),
    const ForecastZone(
      id: 'university',
      name: 'University District',
      description: 'High student population with variable demand patterns',
    ),
    const ForecastZone(
      id: 'shopping',
      name: 'Shopping District',
      description: 'Retail-focused area with weekend peaks',
    ),
  ];

  // Getters
  List<TimeSeriesPoint> get hourlyForecast => _hourlyForecast;
  List<TimeSeriesPoint> get dailyForecast => _dailyForecast;
  List<TimeSeriesPoint> get weeklyForecast => _weeklyForecast;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime? get lastUpdated => _lastUpdated;
  ForecastZone get selectedZone => _selectedZone;
  List<ForecastZone> get availableZones => _availableZones;

  ForecastProvider()
      : _selectedZone = const ForecastZone(
          id: 'downtown',
          name: 'Downtown',
          description:
              'City center with high business activity and entertainment venues',
        ) {
    // Initialize with mock data
    refreshForecast();

    // Set up automatic refresh timer
    _setupRefreshTimer(defaultRefreshInterval);
  }

  /// Sets up a timer to periodically refresh forecast data
  void _setupRefreshTimer(int minutes) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(minutes: minutes),
      (_) => refreshForecast(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  /// Change the auto-refresh interval
  void setRefreshInterval(int minutes) {
    _setupRefreshTimer(minutes);
  }

  /// Change the selected zone and refresh data
  Future<void> setZone(ForecastZone zone) async {
    if (_selectedZone.id != zone.id) {
      _selectedZone = zone;
      notifyListeners();
      await refreshForecast();
    }
  }

  /// Force a refresh of all forecast data
  Future<void> refreshForecast() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // In a real implementation, these would be API calls with zone parameter
      await Future.delayed(
          const Duration(milliseconds: 800)); // Simulate network delay

      _hourlyForecast = _generateMockHourlyForecast();
      _dailyForecast = _generateMockDailyForecast();
      _weeklyForecast = _generateMockWeeklyForecast();

      _lastUpdated = DateTime.now();
    } catch (e) {
      _error = 'Failed to update forecast: ${e.toString()}';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns forecast data for specific timestamp range
  List<TimeSeriesPoint> getForecastForTimeRange(DateTime start, DateTime end) {
    // In a real implementation, this would filter data based on the range
    // For now, we'll return hourly data if the range is within a day, otherwise daily

    final difference = end.difference(start).inHours;

    if (difference <= 24) {
      return _hourlyForecast;
    } else if (difference <= 168) {
      // 7 days
      return _dailyForecast;
    } else {
      return _weeklyForecast;
    }
  }

  /// Creates mock hourly forecast data
  List<TimeSeriesPoint> _generateMockHourlyForecast() {
    final now = DateTime.now();
    final data = <TimeSeriesPoint>[];

    // Use zone ID as a seed for deterministic but different data per zone
    final zoneSeed = _selectedZone.id.hashCode % 10;

    // Current hour
    final baseCurrentValue =
        15 + (now.hour % 12) / 3 * 5 + (now.minute / 60) * 3;
    final zoneCurrentValue = _applyZoneAdjustment(baseCurrentValue, zoneSeed);

    data.add(TimeSeriesPoint(
      label: 'Now',
      value: zoneCurrentValue,
      additionalInfo: 'Current predicted demand based on live data',
    ));

    // Next 6 hours
    for (int i = 1; i <= 6; i++) {
      final hour = (now.hour + i) % 24;
      final isPeak = hour >= 7 && hour <= 9 || hour >= 16 && hour <= 19;

      // Create a realistic demand curve with peak hours
      double baseValue = 10 + (hour % 12) / 2;
      if (isPeak) baseValue += 8 + (i / 3); // Higher demand during peak hours

      // Add some randomness
      final randomFactor = 0.8 + (DateTime.now().millisecond % 100) / 50;
      final rawValue = baseValue * randomFactor;

      // Apply zone-specific adjustment
      final value = _applyZoneAdjustment(rawValue, zoneSeed);

      String timeInfo = '${(now.hour + i) % 24}:00';
      String demandInfo = isPeak
          ? 'Peak hours - High demand expected'
          : (value > 15 ? 'Above average demand' : 'Moderate demand');

      data.add(TimeSeriesPoint(
        label: '+${i}hr',
        value: value,
        additionalInfo: '$timeInfo • $demandInfo',
      ));
    }

    return data;
  }

  /// Creates mock daily forecast data
  List<TimeSeriesPoint> _generateMockDailyForecast() {
    final now = DateTime.now();
    final data = <TimeSeriesPoint>[];

    // Use zone ID as a seed for deterministic but different data per zone
    final zoneSeed = _selectedZone.id.hashCode % 10;

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Today and next 6 days
    for (int i = 0; i < 7; i++) {
      final day = now.add(Duration(days: i));
      final isWeekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

      // Create realistic demand curve (higher on weekdays, lower on weekends)
      double baseValue = isWeekend ? 12 : 18;

      // Add some randomness
      final randomFactor = 0.85 + (day.day % 10) / 20;
      final rawValue = baseValue * randomFactor;

      // Apply zone-specific adjustment
      final value = _applyZoneAdjustment(rawValue, zoneSeed);

      String label = i == 0 ? 'Today' : weekdays[(day.weekday - 1) % 7];

      // Format the day for the tooltip
      final dayInfo = '${day.month}/${day.day}';
      final demandInfo = isWeekend
          ? 'Weekend - Lower overall demand'
          : 'Weekday - Business hours peak';

      data.add(TimeSeriesPoint(
        label: label,
        value: value,
        additionalInfo: '$dayInfo • $demandInfo',
      ));
    }

    return data;
  }

  /// Creates mock weekly forecast data
  List<TimeSeriesPoint> _generateMockWeeklyForecast() {
    final data = <TimeSeriesPoint>[];
    final now = DateTime.now();

    // Use zone ID as a seed for deterministic but different data per zone
    final zoneSeed = _selectedZone.id.hashCode % 10;

    // Next 4 weeks
    for (int i = 0; i < 4; i++) {
      final weekLabel = i == 0 ? 'This week' : 'Week ${i + 1}';
      final weekStart = now.add(Duration(days: i * 7));
      final weekEnd = weekStart.add(const Duration(days: 6));

      // Create realistic demand curve with some seasonal variation
      double baseValue = 16 - (i * 0.8);

      // Add some randomness
      final randomFactor = 0.9 + (i * 0.1);
      final rawValue = baseValue * randomFactor;

      // Apply zone-specific adjustment
      final value = _applyZoneAdjustment(rawValue, zoneSeed);

      // Format dates for tooltip
      final dateRange =
          '${weekStart.month}/${weekStart.day} - ${weekEnd.month}/${weekEnd.day}';
      final trendInfo = i == 0
          ? 'Current trend'
          : (value > 15 ? 'Strong demand forecast' : 'Average demand forecast');

      data.add(TimeSeriesPoint(
        label: weekLabel,
        value: value,
        additionalInfo: '$dateRange • $trendInfo',
      ));
    }

    return data;
  }

  /// Applies zone-specific adjustments to forecast values
  double _applyZoneAdjustment(double value, int zoneSeed) {
    // Different zones have different demand patterns
    switch (_selectedZone.id) {
      case 'downtown':
        // Downtown has higher weekday values
        return value * 1.1 + zoneSeed * 0.3;
      case 'airport':
        // Airport has more consistent values
        return value * 0.9 + zoneSeed * 0.5;
      case 'suburbs':
        // Suburbs have lower overall values but more weekend demand
        return value * 0.8 + zoneSeed * 0.2;
      case 'university':
        // University has high variability
        return value * 0.95 + zoneSeed * 0.4;
      case 'shopping':
        // Shopping areas have weekend peaks
        return value * 1.05 + zoneSeed * 0.25;
      default:
        return value;
    }
  }
}
