import '../models/journey.dart';

typedef IdFactory = String Function();

/// Turns a spoken or typed task list into ordered [JourneyStop]s.
///
/// v1 is deterministic so tests stay stable. An LLM can emit the same schema later.
class JourneyPromptParser {
  static const int maxStops = 8;

  final IdFactory _idFactory;

  JourneyPromptParser({IdFactory? idFactory})
      : _idFactory = idFactory ?? _incrementalIds();

  static IdFactory _incrementalIds() {
    var n = 0;
    return () => 'stop-${++n}';
  }

  List<JourneyStop> parse(String prompt, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final parts = _split(prompt);
    final stops = <JourneyStop>[];
    for (final part in parts) {
      if (stops.length >= maxStops) break;
      final stop = _parsePart(part, reference);
      if (stop != null) stops.add(stop);
    }
    return stops;
  }

  List<String> _split(String prompt) {
    final normalized = prompt.replaceAll(RegExp(r'\s+then\s+', caseSensitive: false), ',');
    return normalized
        .split(RegExp(r'[,|\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  JourneyStop? _parsePart(String part, DateTime reference) {
    final cleaned = part.replaceAll(RegExp(r'[.!?]+$'), '').trim();
    final roam = RegExp(
      r'\b(drive until|roam|work until|gig until|drive for work)\b',
      caseSensitive: false,
    ).hasMatch(cleaned);

    DateTime? windowStart;
    DateTime? windowEnd;
    for (final match in _timePattern.allMatches(cleaned)) {
      final bound = match.group(1)!.toLowerCase();
      final when = _parseClock(match.group(2)!, match.group(3), reference);
      if (when == null) continue;
      if (bound == 'at') {
        windowStart = when;
        windowEnd = when;
      } else {
        windowEnd = when;
      }
    }

    var title = cleaned.replaceAll(_timePattern, '').trim();
    title = title.replaceAll(
      RegExp(r'^\s*(be at|go to|stop at|head to)\s+', caseSensitive: false),
      '',
    );
    title = title.replaceAll(
      RegExp(r'\b(drive until|roam|work until|gig until|drive for work)\b',
          caseSensitive: false),
      '',
    );
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (roam) {
      final leftover = RegExp(r'^(drive|work|gig)$', caseSensitive: false);
      if (title.isEmpty || leftover.hasMatch(title)) {
        title = 'Roam for work';
      }
      return JourneyStop(
        id: _idFactory(),
        title: title,
        kind: JourneyStopKind.roamForWork,
        placeQuery: null,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
    }

    if (title.isEmpty) return null;
    return JourneyStop(
      id: _idFactory(),
      title: title,
      kind: JourneyStopKind.hardStop,
      placeQuery: title,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }

  static final _timePattern = RegExp(
    r'\b(at|by|until)\s+(\d{1,2}(?::\d{2})?)\s*(am|pm)?\b',
    caseSensitive: false,
  );

  DateTime? _parseClock(String clock, String? meridiem, DateTime reference) {
    final bits = clock.split(':');
    var hour = int.tryParse(bits[0]);
    if (hour == null) return null;
    final minute = bits.length > 1 ? int.tryParse(bits[1]) ?? 0 : 0;
    final mer = meridiem?.toLowerCase();
    if (mer == 'pm' && hour < 12) hour += 12;
    if (mer == 'am' && hour == 12) hour = 0;
    if (mer == null && hour >= 1 && hour <= 7) hour += 12;
    return DateTime(reference.year, reference.month, reference.day, hour, minute);
  }
}
