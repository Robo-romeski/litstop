import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/journey.dart';
import '../providers/journey_provider.dart';

class JourneyPlannerSheet extends StatefulWidget {
  const JourneyPlannerSheet({super.key});

  @override
  State<JourneyPlannerSheet> createState() => _JourneyPlannerSheetState();
}

class _JourneyPlannerSheetState extends State<JourneyPlannerSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final journey = context.watch<JourneyProvider>();
    final stops = journey.draft?.stops ?? const <JourneyStop>[];

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Plan day', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'List what you need to do. Use commas or new lines. '
              '"Drive until 2" becomes a roam-for-work block.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    'School drop at 8:15, then drive until 2, be at SFO arrivals by 6',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      journey.parsePrompt(_controller.text);
                      setState(() {});
                    },
                    child: const Text('Map it out'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: stops.isEmpty
                        ? null
                        : () async {
                            await journey.confirmDraft();
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    child: const Text('Start journey'),
                  ),
                ),
              ],
            ),
            if (stops.isNotEmpty) ...[
              const SizedBox(height: 16),
              ...stops.map((stop) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      stop.kind == JourneyStopKind.roamForWork
                          ? Icons.explore
                          : Icons.place,
                    ),
                    title: Text(stop.title),
                    subtitle: Text(_subtitle(stop)),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  String _subtitle(JourneyStop stop) {
    final kind = stop.kind == JourneyStopKind.roamForWork
        ? 'Roam for work'
        : 'Hard stop';
    final time = stop.windowEnd ?? stop.windowStart;
    if (time == null) return kind;
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$kind · $h:$m';
  }
}
