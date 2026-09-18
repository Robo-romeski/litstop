import 'package:flutter_test/flutter_test.dart';
import 'package:litstop/models/journey.dart';
import 'package:litstop/services/journey_prompt_parser.dart';

void main() {
  final now = DateTime(2026, 9, 6, 7, 0);
  late JourneyPromptParser parser;

  setUp(() {
    var n = 0;
    parser = JourneyPromptParser(idFactory: () => 's${++n}');
  });

  test('splits the canonical school / roam / airport prompt', () {
    final stops = parser.parse(
      'School drop at 8:15, then drive until 2, be at SFO arrivals by 6.',
      now: now,
    );

    expect(stops, hasLength(3));

    expect(stops[0].kind, JourneyStopKind.hardStop);
    expect(stops[0].title.toLowerCase(), contains('school'));
    expect(stops[0].windowStart, DateTime(2026, 9, 6, 8, 15));

    expect(stops[1].kind, JourneyStopKind.roamForWork);
    expect(stops[1].windowEnd, DateTime(2026, 9, 6, 14, 0));

    expect(stops[2].kind, JourneyStopKind.hardStop);
    expect(stops[2].title.toLowerCase(), contains('sfo'));
    expect(stops[2].windowEnd, DateTime(2026, 9, 6, 18, 0));
  });

  test('splits newlines and caps at 8 stops', () {
    final lines = List.generate(12, (i) => 'Stop $i').join('\n');
    final stops = parser.parse(lines, now: now);
    expect(stops, hasLength(8));
    expect(stops.first.title, 'Stop 0');
    expect(stops.last.title, 'Stop 7');
  });

  test('ignores empty segments', () {
    final stops = parser.parse('Lunch at home, , , gas', now: now);
    expect(stops, hasLength(2));
    expect(stops[0].title.toLowerCase(), contains('lunch'));
    expect(stops[1].title.toLowerCase(), contains('gas'));
  });
}
