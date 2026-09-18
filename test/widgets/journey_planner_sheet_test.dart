import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:litstop/providers/journey_provider.dart';
import 'package:litstop/services/journey_prompt_parser.dart';
import 'package:litstop/widgets/journey_planner_sheet.dart';

void main() {
  testWidgets('parses a prompt into a visible stop list', (tester) async {
    var n = 0;
    final provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j1',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: JourneyPlannerSheet()),
        ),
      ),
    );

    await tester.enterText(
      find.byType(TextField),
      'School drop at 8:15, then drive until 2, be at SFO arrivals by 6',
    );
    await tester.tap(find.text('Map it out'));
    await tester.pump();

    expect(find.textContaining('School'), findsWidgets);
    expect(find.text('Roam for work'), findsOneWidget);
    expect(find.textContaining('SFO'), findsWidgets);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Start journey')).onPressed,
        isNotNull);
  });
}
