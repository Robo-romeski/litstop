import 'package:flutter/material.dart';

import 'ai_controller_button.dart';
import 'journey_next_banner.dart';
import 'journey_plan_button.dart';

class HomeCopilotBar extends StatelessWidget {
  const HomeCopilotBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JourneyNextBanner(),
          SizedBox(height: 8),
          JourneyPlanButton(),
          SizedBox(height: 8),
          AIControllerButton(),
        ],
      ),
    );
  }
}
