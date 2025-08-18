import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SessionHistory {
  final DateTime startTime;
  final DateTime endTime;
  final int totalRides;
  final double earnings;
  final String zone;

  SessionHistory({
    required this.startTime,
    required this.endTime,
    required this.totalRides,
    required this.earnings,
    required this.zone,
  });

  String get duration {
    final duration = endTime.difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }
}

class SessionHistoryScreen extends StatelessWidget {
  final List<SessionHistory> sessions;

  const SessionHistoryScreen({
    super.key,
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Text('No session history available'),
            )
          : ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      DateFormat('MMM dd, yyyy').format(session.startTime),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('HH:mm').format(session.startTime)} - ${DateFormat('HH:mm').format(session.endTime)}',
                        ),
                        Text('Duration: ${session.duration}'),
                        Text('Zone: ${session.zone}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${session.earnings.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        Text(
                          '${session.totalRides} rides',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
