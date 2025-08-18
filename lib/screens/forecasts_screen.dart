import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/forecast_provider.dart';
import '../widgets/demand_forecast_chart.dart';
import '../widgets/zone_selection_component.dart';

class ForecastsScreen extends StatefulWidget {
  const ForecastsScreen({super.key});

  @override
  State<ForecastsScreen> createState() => _ForecastsScreenState();
}

class _ForecastsScreenState extends State<ForecastsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Refresh data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final forecastProvider =
          Provider.of<ForecastProvider>(context, listen: false);
      forecastProvider.refreshForecast();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forecastProvider = Provider.of<ForecastProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Demand Forecasts'),
        actions: [
          if (forecastProvider.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh forecasts',
            onPressed: forecastProvider.isLoading
                ? null
                : () => forecastProvider.refreshForecast(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Hourly'),
            Tab(text: 'Daily'),
            Tab(text: 'Weekly'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildForecastTab(
            forecastProvider.hourlyForecast,
            'Hourly Forecast',
            'Shows demand forecast for the next 6 hours',
          ),
          _buildForecastTab(
            forecastProvider.dailyForecast,
            'Daily Forecast',
            'Shows demand forecast for the next 7 days',
          ),
          _buildForecastTab(
            forecastProvider.weeklyForecast,
            'Weekly Forecast',
            'Shows demand trends for the next 4 weeks',
          ),
        ],
      ),
      bottomNavigationBar: _buildInfoBar(forecastProvider),
    );
  }

  Widget _buildInfoBar(ForecastProvider provider) {
    if (provider.lastUpdated == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Last updated: ${_formatLastUpdated(provider.lastUpdated!)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton.icon(
            icon: const Icon(Icons.info_outline, size: 16),
            label:
                const Text('Using mock data', style: TextStyle(fontSize: 12)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Forecast Information'),
                  content: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Currently using simulated forecast data.'),
                      SizedBox(height: 8),
                      Text(
                        'In production, this would use real-time data from ride history, traffic patterns, and events.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildForecastTab(
      List<TimeSeriesPoint> data, String title, String description) {
    final forecastProvider =
        Provider.of<ForecastProvider>(context, listen: false);

    return RefreshIndicator(
      onRefresh: forecastProvider.refreshForecast,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zone selection component at the top
            ZoneSelectionComponent(
              zones: forecastProvider.availableZones,
              selectedZone: forecastProvider.selectedZone,
              onZoneSelected: (zone) {
                forecastProvider.setZone(zone);
              },
            ),

            if (description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            if (forecastProvider.error != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          forecastProvider.error!,
                          style: TextStyle(color: Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (data.isNotEmpty)
              DemandForecastChart(
                title: title,
                data: data,
                enableInteractions: true,
              ),
            const SizedBox(height: 24),
            if (data.isNotEmpty) ...[
              // Additional stats section
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Text(
                  'Demand Stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Card(
                child: Column(
                  children: [
                    _buildStatTile(
                      'Average Demand',
                      _calculateAverage(data).toStringAsFixed(1),
                      Icons.bar_chart,
                    ),
                    const Divider(height: 1),
                    _buildStatTile(
                      'Highest Demand',
                      _findHighestValue(data).toStringAsFixed(1),
                      Icons.trending_up,
                      subtitle: _findLabelForHighestValue(data),
                    ),
                    const Divider(height: 1),
                    _buildStatTile(
                      'Lowest Demand',
                      _findLowestValue(data).toStringAsFixed(1),
                      Icons.trending_down,
                      subtitle: _findLabelForLowestValue(data),
                    ),
                  ],
                ),
              ),

              // Zone-specific insights
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                child: Text(
                  'Zone Insights',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        forecastProvider.selectedZone.name,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(forecastProvider.selectedZone.description),
                      const SizedBox(height: 16),
                      Text(
                        _getZoneInsight(forecastProvider.selectedZone.id, data),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(String title, String value, IconData icon,
      {String? subtitle}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  double _calculateAverage(List<TimeSeriesPoint> data) {
    if (data.isEmpty) return 0;
    final sum = data.fold(0.0, (sum, point) => sum + point.value);
    return sum / data.length;
  }

  double _findHighestValue(List<TimeSeriesPoint> data) {
    if (data.isEmpty) return 0;
    return data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
  }

  String _findLabelForHighestValue(List<TimeSeriesPoint> data) {
    if (data.isEmpty) return '';
    final highestValue = _findHighestValue(data);
    final point = data.firstWhere((e) => e.value == highestValue);
    return point.label;
  }

  double _findLowestValue(List<TimeSeriesPoint> data) {
    if (data.isEmpty) return 0;
    return data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
  }

  String _findLabelForLowestValue(List<TimeSeriesPoint> data) {
    if (data.isEmpty) return '';
    final lowestValue = _findLowestValue(data);
    final point = data.firstWhere((e) => e.value == lowestValue);
    return point.label;
  }

  String _formatLastUpdated(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }

  String _getZoneInsight(String zoneId, List<TimeSeriesPoint> data) {
    final avg = _calculateAverage(data);

    switch (zoneId) {
      case 'downtown':
        return 'The downtown area shows typical business hour peaks with stronger morning and evening rush hours. Average demand of ${avg.toStringAsFixed(1)} is above the city-wide average.';
      case 'airport':
        return 'Airport demand tends to be more consistent throughout the day with slight increases during flight arrival waves. The average demand of ${avg.toStringAsFixed(1)} has less variance than other zones.';
      case 'suburbs':
        return 'Suburban areas show steady commuter patterns with defined morning and evening peaks. The average demand of ${avg.toStringAsFixed(1)} is typically lower than downtown but more predictable.';
      case 'university':
        return 'The university district has variable patterns based on class schedules and events. An average demand of ${avg.toStringAsFixed(1)} shows high variability depending on the academic calendar.';
      case 'shopping':
        return 'Shopping districts see peak demand on weekends and evenings with an average of ${avg.toStringAsFixed(1)}. Consider targeting these high-volume periods for maximizing earnings.';
      default:
        return 'This zone has an average demand of ${avg.toStringAsFixed(1)}. Analyze the chart patterns to identify optimal driving times.';
    }
  }
}
