import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:litstop/widgets/route_planner_sheet.dart';
import 'package:litstop/providers/location_provider.dart';
import 'package:litstop/providers/poi_provider.dart';

void main() {
  testWidgets('shows error when no destination selected', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocationProvider()),
          ChangeNotifierProvider(create: (_) => POIProvider()),
        ],
        child: const MaterialApp(
          home: Scaffold(body: RoutePlannerSheet()),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Find POIs Along Route'));
    await tester.pump();

    expect(
      find.textContaining('Please select a start location'),
      findsWidgets,
    );
  });
}
