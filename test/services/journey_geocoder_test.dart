import 'package:flutter_test/flutter_test.dart';
import 'package:litstop/services/journey_geocoder.dart';

void main() {
  test('geocodeCandidates keeps the phrase and adds aliases', () {
    expect(
      geocodeCandidates('School drop at 8:15'),
      containsAll(['School drop at 8:15', 'Lincoln High School']),
    );
    expect(
      geocodeCandidates('be at SFO arrivals'),
      containsAll(['be at SFO arrivals', 'SFO']),
    );
    expect(geocodeCandidates('  '), isEmpty);
  });
}
