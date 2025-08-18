import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/ride_event.dart';
import '../providers/event_provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Widget to display a list of ride events
class EventList extends StatelessWidget {
  /// Optional callback when an event is tapped
  final Function(RideEvent)? onEventTap;

  /// Optional callback when an event's location is tapped
  final Function(RideEvent)? onLocationTap;

  /// Constructor
  const EventList({
    super.key,
    this.onEventTap,
    this.onLocationTap,
  });

  @override
  Widget build(BuildContext context) {
    final eventProvider = Provider.of<EventProvider>(context);
    final events = eventProvider.events;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.notifications_none,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No events yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Events will appear here as they occur',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        // In a real app, we would fetch fresh events here
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(context, event);
        },
      ),
    );
  }

  /// Build a card for a single event
  Widget _buildEventCard(BuildContext context, RideEvent event) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: event.isRead ? 0 : 2,
      color: event.isRead
          ? Theme.of(context).cardColor
          : Theme.of(context).colorScheme.primary.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          // Mark as read when tapped
          if (!event.isRead) {
            Provider.of<EventProvider>(context, listen: false)
                .markEventAsRead(event.id);
          }

          // Call the tap callback if provided
          if (onEventTap != null) {
            onEventTap!(event);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildEventIcon(event.type),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      event.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: event.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                    ),
                  ),
                  Text(
                    _formatTimestamp(event.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (event.location != null) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () {
                    if (onLocationTap != null) {
                      onLocationTap!(event);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'View on Map',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
              if (event.type == RideEventType.rideRequest &&
                  event.estimatedFare != null &&
                  event.estimatedDistance != null &&
                  event.estimatedDuration != null) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildDetailChip(
                      context,
                      Icons.attach_money,
                      '\$${event.estimatedFare!.toStringAsFixed(2)}',
                    ),
                    _buildDetailChip(
                      context,
                      Icons.route,
                      '${event.estimatedDistance!.toStringAsFixed(1)} mi',
                    ),
                    _buildDetailChip(
                      context,
                      Icons.timer,
                      '${event.estimatedDuration} min',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build a chip for displaying ride details
  Widget _buildDetailChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Build an icon based on event type
  Widget _buildEventIcon(RideEventType type) {
    final IconData icon;
    final Color color;

    switch (type) {
      case RideEventType.rideRequest:
        icon = Icons.directions_car;
        color = Colors.blue;
        break;
      case RideEventType.rideAccepted:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case RideEventType.rideCompleted:
        icon = Icons.done_all;
        color = Colors.teal;
        break;
      case RideEventType.rideCancelled:
        icon = Icons.cancel;
        color = Colors.red;
        break;
      case RideEventType.highDemandArea:
        icon = Icons.trending_up;
        color = Colors.orange;
        break;
      case RideEventType.notification:
        icon = Icons.notifications;
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  /// Format a timestamp into a readable string
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }
}
