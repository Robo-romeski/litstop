import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/journey.dart';

abstract class JourneyStore {
  Future<List<Journey>> load();
  Future<void> saveAll(List<Journey> journeys);
}

class MemoryJourneyStore implements JourneyStore {
  MemoryJourneyStore([List<Journey>? seed]) : _journeys = [...?seed];

  final List<Journey> _journeys;

  @override
  Future<List<Journey>> load() async => List.unmodifiable(_journeys);

  @override
  Future<void> saveAll(List<Journey> journeys) async {
    _journeys
      ..clear()
      ..addAll(journeys);
  }
}

class SharedPreferencesJourneyStore implements JourneyStore {
  static const historyKey = 'journey_history';

  SharedPreferencesJourneyStore({SharedPreferences? prefs}) : _prefs = prefs;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  @override
  Future<List<Journey>> load() async {
    final prefs = await _instance();
    final raw = prefs.getString(historyKey);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) Journey.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<void> saveAll(List<Journey> journeys) async {
    final prefs = await _instance();
    await prefs.setString(
      historyKey,
      jsonEncode([for (final journey in journeys) journey.toJson()]),
    );
  }
}
