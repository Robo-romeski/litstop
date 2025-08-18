import 'package:flutter/material.dart';

/// A model class representing a geographic zone for forecasting
class ForecastZone {
  final String id;
  final String name;
  final String description;

  const ForecastZone({
    required this.id,
    required this.name,
    required this.description,
  });
}

/// A widget that allows users to select different forecast zones
class ZoneSelectionComponent extends StatefulWidget {
  /// List of available zones to select from
  final List<ForecastZone> zones;

  /// Currently selected zone
  final ForecastZone? selectedZone;

  /// Callback triggered when a zone is selected
  final Function(ForecastZone) onZoneSelected;

  /// Whether to show the zone description
  final bool showDescription;

  const ZoneSelectionComponent({
    super.key,
    required this.zones,
    this.selectedZone,
    required this.onZoneSelected,
    this.showDescription = true,
  });

  @override
  State<ZoneSelectionComponent> createState() => _ZoneSelectionComponentState();
}

class _ZoneSelectionComponentState extends State<ZoneSelectionComponent> {
  late ForecastZone _selectedZone;

  @override
  void initState() {
    super.initState();
    _selectedZone = widget.selectedZone ?? widget.zones.first;
  }

  @override
  void didUpdateWidget(ZoneSelectionComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedZone != null && widget.selectedZone != _selectedZone) {
      setState(() {
        _selectedZone = widget.selectedZone!;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 8),
                Text(
                  'Forecast Zone',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ForecastZone>(
              value: _selectedZone,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              items: widget.zones.map((zone) {
                return DropdownMenuItem<ForecastZone>(
                  value: zone,
                  child: Text(zone.name),
                );
              }).toList(),
              onChanged: (newZone) {
                if (newZone != null && newZone != _selectedZone) {
                  setState(() {
                    _selectedZone = newZone;
                  });
                  widget.onZoneSelected(newZone);
                }
              },
            ),
            if (widget.showDescription &&
                _selectedZone.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _selectedZone.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Example usage:
/// ```dart
/// ZoneSelectionComponent(
///   zones: [
///     ForecastZone(id: 'downtown', name: 'Downtown', description: 'City center with high activity'),
///     ForecastZone(id: 'airport', name: 'Airport', description: 'Airport and surrounding areas'),
///   ],
///   onZoneSelected: (zone) {
///     print('Selected zone: ${zone.name}');
///   },
/// )
/// ```
