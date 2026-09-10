import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/services/encoded_polyline.dart';

void main() {
  test('decodes the Google encoded-polyline sample', () {
    const encoded = r'_p~iF~ps|U_ulLnnqC_mqNvxq`@';
    final points = decodeEncodedPolyline(encoded);
    expect(points, hasLength(3));
    expect(points[0].latitude, closeTo(38.5, 0.001));
    expect(points[0].longitude, closeTo(-120.2, 0.001));
    expect(points[1].latitude, closeTo(40.7, 0.001));
    expect(points[1].longitude, closeTo(-120.95, 0.001));
    expect(points[2].latitude, closeTo(43.252, 0.001));
    expect(points[2].longitude, closeTo(-126.453, 0.001));
  });
}
