import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:litstop/providers/journey_provider.dart';
import 'package:litstop/services/journey_prompt_parser.dart';
import 'package:litstop/services/journey_store.dart';
import 'package:litstop/widgets/journey_next_banner.dart';

void main() {
  testWidgets('Finish day moves the active journey into history',
      (tester) async {
    var n = 0;
    final provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j1',
      store: MemoryJourneyStore(),
    );
    provider.parsePrompt('School drop');
    await provider.confirmDraft();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: JourneyNextBanner()),
        ),
      ),
    );

    expect(find.textContaining('School'), findsOneWidget);
    await tester.tap(find.text('Finish day'));
    await tester.pump();

    expect(provider.history, hasLength(1));
    expect(find.text('Finish day'), findsNothing);
  });

  testWidgets('Skip advances to the next stop', (tester) async {
    var n = 0;
    final provider = JourneyProvider(
      parser: JourneyPromptParser(idFactory: () => 's${++n}'),
      journeyId: () => 'j1',
    );
    provider.parsePrompt('School drop, SFO arrivals');
    await provider.confirmDraft();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: Scaffold(body: JourneyNextBanner()),
        ),
      ),
    );

    expect(find.textContaining('School'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pump();

    expect(provider.nextStop!.title, contains('SFO'));
    expect(find.textContaining('SFO'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });
}
