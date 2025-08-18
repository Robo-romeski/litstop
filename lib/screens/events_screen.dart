import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/event_provider.dart';
import '../providers/location_provider.dart';
import '../widgets/event_list.dart';
import '../models/ride_event.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Screen for displaying ride events
class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize events on first load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().initialize();
    });
  }

  /// Navigate to the location on the map when a location is tapped
  void _handleLocationTap(RideEvent event) {
    if (event.location != null) {
      Navigator.of(context).pop(event.location);
    }
  }

  /// Show event details dialog
  void _showEventDetails(RideEvent event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.description),
            const SizedBox(height: 8),
            Text(
              'Time: ${_formatDateTime(event.timestamp)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (event.location != null) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  _handleLocationTap(event);
                },
                icon: const Icon(Icons.map),
                label: const Text('View on Map'),
              ),
            ],
            if (event.estimatedFare != null) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated Fare: \$${event.estimatedFare!.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (event.estimatedDistance != null) ...[
              const SizedBox(height: 4),
              Text(
                'Distance: ${event.estimatedDistance!.toStringAsFixed(1)} miles',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (event.estimatedDuration != null) ...[
              const SizedBox(height: 4),
              Text(
                'Duration: ${event.estimatedDuration} minutes',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Format a DateTime into a readable string
  String _formatDateTime(DateTime dateTime) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour < 12 ? 'AM' : 'PM';

    return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year} at $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final eventProvider = context.watch<EventProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride Events'),
        actions: [
          if (eventProvider.hasUnreadEvents)
            IconButton(
              icon: const Icon(Icons.mark_email_read),
              tooltip: 'Mark all as read',
              onPressed: () {
                eventProvider.markAllEventsAsRead();
              },
            ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all events',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear Events'),
                  content:
                      const Text('Are you sure you want to clear all events?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        eventProvider.clearAllEvents();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: EventList(
        onEventTap: _showEventDetails,
        onLocationTap: _handleLocationTap,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Simulate a new random event
          final random = context.read<LocationProvider>().currentPosition;
          if (random != null) {
            final randomLocation = LatLng(
              random.latitude + ((0.5 - (0.5 * 0.2)) * 0.05),
              random.longitude + ((0.5 - (0.5 * 0.2)) * 0.05),
            );

            final event = RideEvent(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              type: RideEventType.highDemandArea,
              title: 'High Demand Alert',
              description: 'New high demand area detected nearby.',
              timestamp: DateTime.now(),
              location: randomLocation,
            );

            // Add a hotspot to the heatmap at this location
            Navigator.of(context).pop(randomLocation);
          }
        },
        child: const Icon(Icons.add_alert),
        tooltip: 'Generate test event',
      ),
    );
  }
}
