import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DemandForecastPanel extends StatelessWidget {
  final List<double> hourlyDemand;
  final String selectedZone;

  const DemandForecastPanel({
    super.key,
    required this.hourlyDemand,
    required this.selectedZone,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Demand Forecast - $selectedZone',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final hour = value.toInt();
                          if (hour % 3 == 0 && hour < 24) {
                            return Text('$hour:00');
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: hourlyDemand.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Peak Hours',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _findPeakHours(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Current Demand',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  _getCurrentDemand(),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _findPeakHours() {
    if (hourlyDemand.isEmpty) return 'N/A';
    final maxDemand = hourlyDemand.reduce((a, b) => a > b ? a : b);
    final peakHours = hourlyDemand
        .asMap()
        .entries
        .where((entry) => entry.value == maxDemand)
        .map((entry) => '${entry.key}:00')
        .join(', ');
    return peakHours;
  }

  String _getCurrentDemand() {
    if (hourlyDemand.isEmpty) return 'N/A';
    final now = DateTime.now();
    final currentHour = now.hour;
    if (currentHour < hourlyDemand.length) {
      return '${hourlyDemand[currentHour].toStringAsFixed(1)}x';
    }
    return 'N/A';
  }
}
