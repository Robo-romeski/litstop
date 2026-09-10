import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:litstop/providers/heatmap_provider.dart';
import 'package:litstop/services/busy_zone_selector.dart';

void main() {
  test('hotspot markers use predicted-busy copy, never surge', () {
    final provider = HeatmapProvider();
    addTearDown(provider.dispose);

    provider.setHotspots([const LatLng(37.77, -122.42)]);
    final info = provider.hotspotMarkers.single.infoWindow;

    expect(info.title, PredictedActivityCopy.zoneTitle);
    expect(info.snippet, PredictedActivityCopy.zoneSnippet);
    expect(info.title!.toLowerCase(), isNot(contains('surge')));
    expect(info.snippet!.toLowerCase(), isNot(contains('surge')));
  });
}
