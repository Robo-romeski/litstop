import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/journey.dart';
import '../providers/journey_provider.dart';

class JourneyNextBanner extends StatelessWidget {
  const JourneyNextBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final next = context.watch<JourneyProvider>().nextStop;
    if (next == null) return const SizedBox.shrink();

    final kind = switch (next.kind) {
      JourneyStopKind.roamForWork => 'Roam',
      JourneyStopKind.rest => 'Rest',
      JourneyStopKind.fuel => 'Gas',
      JourneyStopKind.hardStop => 'Next',
    };

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(
              next.kind == JourneyStopKind.roamForWork
                  ? Icons.explore
                  : Icons.navigation,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$kind: ${next.title}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () => context.read<JourneyProvider>().skipNextStop(),
              child: const Text('Skip'),
            ),
            TextButton(
              onPressed: () => context.read<JourneyProvider>().completeActive(),
              child: const Text('Finish day'),
            ),
          ],
        ),
      ),
    );
  }
}
