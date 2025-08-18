import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DemandForecastChart extends StatefulWidget {
  final List<TimeSeriesPoint> data;
  final String title;
  final bool enableInteractions;

  const DemandForecastChart({
    super.key,
    required this.data,
    this.title = 'Demand Forecast',
    this.enableInteractions = true,
  });

  @override
  State<DemandForecastChart> createState() => _DemandForecastChartState();
}

class _DemandForecastChartState extends State<DemandForecastChart> {
  // For tracking zoom and pan state
  double _minX = 0;
  double _maxX = 0;
  double _minY = 0;
  double _maxY = 0;
  bool _isZoomed = false;

  // For highlight interaction
  int? _selectedSpotIndex;

  @override
  void initState() {
    super.initState();
    _resetZoom();
  }

  @override
  void didUpdateWidget(DemandForecastChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _resetZoom();
    }
  }

  void _resetZoom() {
    if (widget.data.isEmpty) return;

    _minX = 0;
    _maxX = (widget.data.length - 1).toDouble();

    // Calculate min and max Y values with some padding
    final values = widget.data.map((point) => point.value).toList();
    final minY = values.reduce((min, value) => min < value ? min : value);
    final maxY = values.reduce((max, value) => max > value ? max : value);

    final yPadding = (maxY - minY) * 0.1;
    _minY = minY - yPadding;
    _maxY = maxY + yPadding;

    _isZoomed = false;
    _selectedSpotIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return SizedBox(
        height: 240,
        child: Center(
          child: Text(
            'No data available',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (widget.enableInteractions && _isZoomed)
                  IconButton(
                    icon: const Icon(Icons.zoom_out_map),
                    tooltip: 'Reset zoom',
                    onPressed: () {
                      setState(() {
                        _resetZoom();
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= widget.data.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              widget.data[index].label,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 28,
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        for (int i = 0; i < widget.data.length; i++)
                          FlSpot(i.toDouble(), widget.data[i].value),
                      ],
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isSelected = _selectedSpotIndex == index;
                          return FlDotCirclePainter(
                            radius: isSelected ? 5 : 3,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.5),
                            strokeWidth: 2,
                            strokeColor: Theme.of(context).colorScheme.primary,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                      ),
                    ),
                  ],
                  minX: _minX,
                  maxX: _maxX,
                  minY: _minY,
                  maxY: _maxY,
                  lineTouchData: LineTouchData(
                    enabled: widget.enableInteractions,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey.withOpacity(0.8),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          final data = widget.data[index];

                          // Update selected spot for highlighting
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (_selectedSpotIndex != index) {
                              setState(() {
                                _selectedSpotIndex = index;
                              });
                            }
                          });

                          return LineTooltipItem(
                            '${data.label}\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    'Demand: ${data.value.toStringAsFixed(1)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              if (data.additionalInfo != null) ...[
                                const TextSpan(text: '\n'),
                                TextSpan(
                                  text: data.additionalInfo,
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          );
                        }).toList();
                      },
                    ),
                    touchCallback:
                        (FlTouchEvent event, LineTouchResponse? touchResponse) {
                      // Clear selection when touch ends
                      if (event is FlTapUpEvent || event is FlPanEndEvent) {
                        setState(() {
                          _selectedSpotIndex = null;
                        });
                      }
                    },
                  ),
                  // Enable zoom and pan functionality
                  rangeAnnotations: RangeAnnotations(),
                  clipData: FlClipData.all(),
                ),
              ),
            ),
            if (widget.enableInteractions) ...[
              const SizedBox(height: 8),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Tap for details',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  SizedBox(width: 16),
                  Icon(Icons.pinch, size: 14, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Pinch to zoom',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class TimeSeriesPoint {
  final String label;
  final double value;
  final String? additionalInfo;

  const TimeSeriesPoint({
    required this.label,
    required this.value,
    this.additionalInfo,
  });
}

// Example usage with mock data:
// DemandForecastChart(
//   data: [
//     TimeSeriesPoint(label: '8am', value: 10),
//     TimeSeriesPoint(label: '9am', value: 15),
//     TimeSeriesPoint(label: '10am', value: 20),
//     TimeSeriesPoint(label: '11am', value: 18),
//     TimeSeriesPoint(label: '12pm', value: 25),
//   ],
// )
