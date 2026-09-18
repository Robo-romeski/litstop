import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/journey.dart';
import 'package:litstop/services/journey_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('SharedPreferencesJourneyStore reloads saved journeys', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesJourneyStore();
    final journey = Journey(
      id: 'j1',
      createdAt: DateTime(2026, 9, 7, 7),
      status: JourneyStatus.completed,
      stops: const [
        JourneyStop(
            id: 's1', title: 'School drop', kind: JourneyStopKind.hardStop),
      ],
      trace: const [LatLng(37.74, -122.48)],
    );

    await store.saveAll([journey]);
    final loaded = await store.load();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, 'j1');
    expect(loaded.single.trace, [const LatLng(37.74, -122.48)]);
  });
}
