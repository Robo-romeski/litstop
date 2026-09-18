import 'package:google_maps_flutter/google_maps_flutter.dart';

enum JourneyStopKind { hardStop, roamForWork, rest, fuel }

enum JourneyStatus { draft, active, completed }

class JourneyStop {
  final String id;
  final String title;
  final JourneyStopKind kind;
  final LatLng? location;
  final String? placeQuery;
  final DateTime? windowStart;
  final DateTime? windowEnd;

  const JourneyStop({
    required this.id,
    required this.title,
    required this.kind,
    this.location,
    this.placeQuery,
    this.windowStart,
    this.windowEnd,
  });

  bool get hasLocation => location != null;

  bool get isConstraint =>
      kind == JourneyStopKind.rest || kind == JourneyStopKind.fuel;

  bool isMissedAt(DateTime now) {
    final deadline = windowEnd ?? windowStart;
    if (deadline == null) return false;
    return now.isAfter(deadline);
  }

  JourneyStop copyWith({
    String? id,
    String? title,
    JourneyStopKind? kind,
    LatLng? location,
    String? placeQuery,
    DateTime? windowStart,
    DateTime? windowEnd,
  }) {
    return JourneyStop(
      id: id ?? this.id,
      title: title ?? this.title,
      kind: kind ?? this.kind,
      location: location ?? this.location,
      placeQuery: placeQuery ?? this.placeQuery,
      windowStart: windowStart ?? this.windowStart,
      windowEnd: windowEnd ?? this.windowEnd,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'kind': kind.name,
        'location': _latLngToJson(location),
        'placeQuery': placeQuery,
        'windowStart': windowStart?.millisecondsSinceEpoch,
        'windowEnd': windowEnd?.millisecondsSinceEpoch,
      };

  factory JourneyStop.fromJson(Map<String, dynamic> json) {
    return JourneyStop(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      kind: JourneyStopKind.values.firstWhere(
        (value) => value.name == json['kind'],
        orElse: () => JourneyStopKind.hardStop,
      ),
      location: _latLngFromJson(json['location']),
      placeQuery: json['placeQuery'] as String?,
      windowStart: _dateFromMillis(json['windowStart']),
      windowEnd: _dateFromMillis(json['windowEnd']),
    );
  }
}

class Journey {
  final String id;
  final DateTime createdAt;
  final List<JourneyStop> stops;
  final JourneyStatus status;
  final List<LatLng> trace;

  const Journey({
    required this.id,
    required this.createdAt,
    required this.stops,
    this.status = JourneyStatus.draft,
    this.trace = const [],
  });

  Journey copyWith({
    String? id,
    DateTime? createdAt,
    List<JourneyStop>? stops,
    JourneyStatus? status,
    List<LatLng>? trace,
  }) {
    return Journey(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      stops: stops ?? this.stops,
      status: status ?? this.status,
      trace: trace ?? this.trace,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status.name,
        'stops': [for (final stop in stops) stop.toJson()],
        'trace': [for (final point in trace) _latLngToJson(point)],
      };

  factory Journey.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'];
    final rawTrace = json['trace'];
    return Journey(
      id: json['id'] as String? ?? '',
      createdAt: _dateFromMillis(json['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      status: JourneyStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => JourneyStatus.draft,
      ),
      stops: [
        if (rawStops is List)
          for (final stop in rawStops)
            if (stop is Map)
              JourneyStop.fromJson(Map<String, dynamic>.from(stop)),
      ],
      trace: [
        if (rawTrace is List)
          for (final point in rawTrace)
            if (_latLngFromJson(point) != null) _latLngFromJson(point)!,
      ],
    );
  }
}

Map<String, double>? _latLngToJson(LatLng? point) {
  if (point == null) return null;
  return {'lat': point.latitude, 'lng': point.longitude};
}

LatLng? _latLngFromJson(dynamic value) {
  if (value is! Map) return null;
  final lat = value['lat'];
  final lng = value['lng'];
  if (lat is! num || lng is! num) return null;
  return LatLng(lat.toDouble(), lng.toDouble());
}

DateTime? _dateFromMillis(dynamic value) {
  if (value is! num) return null;
  return DateTime.fromMillisecondsSinceEpoch(value.toInt());
}
