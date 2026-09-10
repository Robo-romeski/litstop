import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/models/gas_station.dart';
import 'package:litstop/models/journey.dart';
import 'package:litstop/models/point_of_interest.dart';
import 'package:litstop/services/constraint_poi.dart';

void main() {
  final here = const LatLng(37.77, -122.42);

  PointOfInterest poi({
    required String name,
    required POIType type,
    required LatLng location,
  }) {
    return PointOfInterest(
      id: name,
      name: name,
      type: type,
      location: location,
      address: name,
    );
  }

  test('picks the nearest rest area for a rest constraint', () {
    final near = poi(
      name: 'Near rest',
      type: POIType.restArea,
      location: const LatLng(37.771, -122.421),
    );
    final far = poi(
      name: 'Far rest',
      type: POIType.restArea,
      location: const LatLng(37.90, -122.20),
    );
    final cafe = poi(
      name: 'Cafe',
      type: POIType.cafe,
      location: const LatLng(37.7701, -122.4201),
    );

    final picked = pickConstraintPoi(
      kind: JourneyStopKind.rest,
      from: here,
      pois: [far, cafe, near],
    );
    expect(picked?.title, 'Near rest');
  });

  test('picks a nearby gas station for a fuel constraint', () {
    final station = GasStation(
      id: 'g1',
      name: 'Shell',
      location: const LatLng(37.772, -122.419),
      address: '1 Main',
      state: 'CA',
      prices: const {},
      lastUpdated: DateTime(2026, 9, 8),
    );
    final picked = pickConstraintPoi(
      kind: JourneyStopKind.fuel,
      from: here,
      stations: [station],
    );
    expect(picked?.title, 'Shell');
  });
}
