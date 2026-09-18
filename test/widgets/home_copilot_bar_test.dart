import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:litstop/providers/journey_provider.dart';
import 'package:litstop/services/journey_prompt_parser.dart';
import 'package:litstop/widgets/home_copilot_bar.dart';

void main() {
  testWidgets('Plan day is visible and partner-status chips are not',
      (tester) async {
    var n = 0;
    final provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j1',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: HomeCopilotBar()),
        ),
      ),
    );

    expect(find.text('Plan day'), findsOneWidget);
    expect(find.text('AI'), findsOneWidget);
    expect(find.textContaining('Uber'), findsNothing);
    expect(find.textContaining('Lyft'), findsNothing);
    expect(find.textContaining('Global'), findsNothing);
  });
}
