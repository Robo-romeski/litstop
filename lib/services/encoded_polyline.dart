import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes a Google encoded polyline (precision 5) into coordinates.
List<LatLng> decodeEncodedPolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  int nextDelta() {
    var result = 0;
    var shift = 0;
    int b;
    do {
      if (index >= encoded.length) {
        throw const FormatException('Truncated encoded polyline');
      }
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    return (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
  }

  while (index < encoded.length) {
    lat += nextDelta();
    lng += nextDelta();
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }
  return points;
}
