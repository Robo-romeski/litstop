import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/journey_provider.dart';
import 'journey_planner_sheet.dart';

class JourneyPlanButton extends StatelessWidget {
  const JourneyPlanButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: 'journeyPlan',
      icon: const Icon(Icons.route),
      label: const Text('Plan day'),
      onPressed: () {
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<JourneyProvider>(),
            child: const JourneyPlannerSheet(),
          ),
        );
      },
    );
  }
}
