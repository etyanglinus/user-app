import 'package:fasta_deliveries/common/widgets/adaptive_map/adaptive_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

void main() {
  const LatLng nairobi = LatLng(-1.2864, 36.8172);
  const LatLng westlands = LatLng(-1.2614, 36.8024);

  setUp(() => MapProviderState.instance.useOsm.value = true);

  Future<AdaptiveMapController> pumpMap(WidgetTester tester, {List<CameraPosition>? moves, void Function()? onIdle}) async {
    AdaptiveMapController? created;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: AdaptiveMap(
            initialCameraPosition: const CameraPosition(target: nairobi, zoom: 14),
            markers: <Marker>{
              const Marker(markerId: MarkerId('shop'), position: nairobi, infoWindow: InfoWindow(title: 'Shop')),
              Marker(markerId: const MarkerId('home'), position: westlands, icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue)),
            },
            polylines: <Polyline>{const Polyline(polylineId: PolylineId('route'), points: <LatLng>[nairobi, westlands], width: 4)},
            polygons: <Polygon>{
              const Polygon(polygonId: PolygonId('zone'), points: <LatLng>[LatLng(-1.3, 36.8), LatLng(-1.25, 36.8), LatLng(-1.25, 36.85)]),
            },
            onMapCreated: (AdaptiveMapController c) => created = c,
            onCameraMove: (CameraPosition p) => moves?.add(p),
            onCameraIdle: onIdle,
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(created, isNotNull, reason: 'onMapCreated must fire for OpenStreetMap too');
    return created!;
  }

  testWidgets('draws OpenStreetMap with markers, route and zone when the backend says osm', (WidgetTester tester) async {
    final AdaptiveMapController c = await pumpMap(tester);
    expect(find.byType(fm.FlutterMap), findsOneWidget);
    expect(find.byType(GoogleMap), findsNothing);
    expect(find.byType(fm.MarkerLayer), findsOneWidget);
    expect(find.byType(fm.PolylineLayer), findsOneWidget);
    expect(find.byType(fm.PolygonLayer), findsOneWidget);
    expect(find.byIcon(Icons.location_on), findsNWidgets(2));
    expect(c.isOsm, isTrue);
    expect(await c.getZoomLevel(), 14);
  });

  testWidgets('camera updates written for Google work on OpenStreetMap', (WidgetTester tester) async {
    final AdaptiveMapController c = await pumpMap(tester);

    await c.moveCamera(CameraUpdate.newCameraPosition(const CameraPosition(target: westlands, zoom: 16)));
    await tester.pump();
    expect(await c.getZoomLevel(), 16);
    final LatLngBounds visible = await c.getVisibleRegion();
    expect(visible.contains(westlands), isTrue);

    await c.animateCamera(CameraUpdate.zoomTo(12));
    await tester.pump();
    expect(await c.getZoomLevel(), 12);

    await c.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: nairobi, northeast: westlands), 40));
    await tester.pump();
    final LatLngBounds fitted = await c.getVisibleRegion();
    expect(fitted.contains(nairobi) && fitted.contains(westlands), isTrue);
  });

  testWidgets('switches between Google and OpenStreetMap at runtime', (WidgetTester tester) async {
    await pumpMap(tester);
    expect(find.byType(fm.FlutterMap), findsOneWidget);
    MapProviderState.instance.useOsm.value = false;
    await tester.pump();
    expect(find.byType(fm.FlutterMap), findsNothing);
    expect(find.byType(GoogleMap), findsOneWidget);
  });

  test('backend settings are applied', () {
    final MapProviderState s = MapProviderState.instance;
    s.apply(<String, dynamic>{'map_provider': 'google', 'osm_tile_url': 'https://tiles.example.com/{z}/{x}/{y}.png', 'osm_tile_max_zoom': 18});
    expect(s.useOsm.value, isFalse);
    expect(s.tileUrl, contains('tiles.example.com'));
    expect(s.maxZoom, 18);
    s.apply(<String, dynamic>{'map_provider': 'osm'});
    expect(s.useOsm.value, isTrue);
  });
}
