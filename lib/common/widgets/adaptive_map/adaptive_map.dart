// Google Maps with an OpenStreetMap fallback.
//
// `AdaptiveMap` takes the same arguments as `GoogleMap` and draws Google Maps normally. When the
// backend reports that Google Maps is unavailable (billing, quota or key problems, or the admin chose
// "Always OpenStreetMap"), it draws the same markers, route lines and zone outlines on an
// OpenStreetMap map (flutter_map) instead.
//
// `AdaptiveMapController` offers the GoogleMapController methods the app uses (animateCamera,
// moveCamera, getVisibleRegion, getZoomLevel) for both maps, so screen code does not change.
//
// The choice comes from GET /api/v1/config/map-provider (re-checked at most every 5 minutes).
// The same file is used in the customer, seller and courier apps.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' as ll;

import '../../../util/app_constants.dart';

// ---------------------------------------------------------------------------------------------
// Provider state
// ---------------------------------------------------------------------------------------------

/// Which map to draw ("google" or "osm") and the OpenStreetMap tile settings.
class MapProviderState {
  MapProviderState._();
  static final MapProviderState instance = MapProviderState._();

  final ValueNotifier<bool> useOsm = ValueNotifier<bool>(false);
  String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  String attribution = '© OpenStreetMap contributors';
  double maxZoom = 19;

  DateTime? _lastCheck;
  Future<void>? _inflight;

  /// Applies `map_provider` / `osm_tile_*` fields, e.g. from /api/v1/config.
  void apply(Map<String, dynamic>? cfg) {
    if (cfg == null) return;
    final dynamic provider = cfg['map_provider'];
    if (provider == 'osm' || provider == 'google') useOsm.value = provider == 'osm';
    final dynamic url = cfg['osm_tile_url'];
    if (url is String && url.contains('{z}')) tileUrl = url;
    final dynamic credit = cfg['osm_tile_attribution'];
    if (credit is String && credit.isNotEmpty) attribution = credit;
    final double? zoom = double.tryParse('${cfg['osm_tile_max_zoom']}');
    if (zoom != null && zoom > 0) maxZoom = zoom;
  }

  /// Asks the backend which map to use. Cheap; called when a map screen opens.
  Future<void> refresh({bool force = false}) {
    if (!force && _lastCheck != null && DateTime.now().difference(_lastCheck!) < const Duration(minutes: 5)) {
      return Future<void>.value();
    }
    return _inflight ??= () async {
      try {
        final http.Response res = await http
            .get(Uri.parse('${AppConstants.baseUrl}/api/v1/config/map-provider'), headers: <String, String>{'Accept': 'application/json'})
            .timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final dynamic body = jsonDecode(res.body);
          final dynamic cfg = body is Map && body['content'] is Map ? body['content'] : body;
          if (cfg is Map) apply(Map<String, dynamic>.from(cfg));
        }
        _lastCheck = DateTime.now();
      } catch (_) {
        // Offline or backend unreachable: keep the current choice.
      } finally {
        _inflight = null;
      }
    }();
  }
}

// ---------------------------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------------------------

/// Works with Google Maps and OpenStreetMap. Same method names as GoogleMapController.
class AdaptiveMapController {
  AdaptiveMapController._google(GoogleMapController this.google) : osm = null;
  AdaptiveMapController._osm(fm.MapController this.osm) : google = null;

  /// Set when Google Maps is drawn.
  final GoogleMapController? google;

  /// Set when OpenStreetMap is drawn.
  final fm.MapController? osm;

  bool get isOsm => osm != null;

  Future<void> animateCamera(CameraUpdate update, {Duration? duration}) async {
    if (google != null) return google!.animateCamera(update, duration: duration);
    _applyToOsm(update);
  }

  Future<void> moveCamera(CameraUpdate update) async {
    if (google != null) return google!.moveCamera(update);
    _applyToOsm(update);
  }

  Future<double> getZoomLevel() async {
    if (google != null) return google!.getZoomLevel();
    return osm!.camera.zoom;
  }

  Future<LatLngBounds> getVisibleRegion() async {
    if (google != null) return google!.getVisibleRegion();
    final fm.LatLngBounds b = osm!.camera.visibleBounds;
    return LatLngBounds(
      southwest: LatLng(b.southWest.latitude, b.southWest.longitude),
      northeast: LatLng(b.northEast.latitude, b.northEast.longitude),
    );
  }

  /// No-op for OpenStreetMap; kept so existing `controller.dispose()` calls compile.
  void dispose() => google?.dispose();

  void _applyToOsm(CameraUpdate update) {
    final fm.MapController map = osm!;
    final dynamic json = update.toJson();
    if (json is! List || json.isEmpty) return;
    final String kind = '${json[0]}';
    final double zoom = map.camera.zoom;
    try {
      switch (kind) {
        case 'newCameraPosition':
          final Map<dynamic, dynamic> pos = json[1] as Map<dynamic, dynamic>;
          map.move(_ll(pos['target']), (pos['zoom'] as num?)?.toDouble() ?? zoom);
        case 'newLatLng':
          map.move(_ll(json[1]), zoom);
        case 'newLatLngZoom':
          map.move(_ll(json[1]), (json[2] as num).toDouble());
        case 'newLatLngBounds':
          final List<dynamic> bounds = json[1] as List<dynamic>;
          final double padding = json.length > 2 ? (json[2] as num).toDouble() : 0;
          map.fitCamera(fm.CameraFit.bounds(
            bounds: fm.LatLngBounds(_ll(bounds[0]), _ll(bounds[1])),
            padding: EdgeInsets.all(padding),
          ));
        case 'zoomTo':
          map.move(map.camera.center, (json[1] as num).toDouble());
        case 'zoomIn':
          map.move(map.camera.center, zoom + 1);
        case 'zoomOut':
          map.move(map.camera.center, zoom - 1);
        case 'zoomBy':
          map.move(map.camera.center, zoom + (json[1] as num).toDouble());
        default:
          debugPrint('AdaptiveMap: camera update "$kind" is not supported on OpenStreetMap');
      }
    } catch (e) {
      // move() throws if called before the map is laid out; the next update will apply.
      debugPrint('AdaptiveMap: camera update skipped ($e)');
    }
  }
}

ll.LatLng _ll(dynamic json) {
  final List<dynamic> p = json as List<dynamic>;
  return ll.LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
}

ll.LatLng _toLl(LatLng p) => ll.LatLng(p.latitude, p.longitude);
LatLng _fromLl(ll.LatLng p) => LatLng(p.latitude, p.longitude);

// ---------------------------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------------------------

/// Drop-in replacement for `GoogleMap` with an automatic OpenStreetMap fallback.
class AdaptiveMap extends StatefulWidget {
  const AdaptiveMap({
    super.key,
    required this.initialCameraPosition,
    this.onMapCreated,
    this.markers = const <Marker>{},
    this.polylines = const <Polyline>{},
    this.polygons = const <Polygon>{},
    this.circles = const <Circle>{},
    this.onTap,
    this.onLongPress,
    this.onCameraMove,
    this.onCameraMoveStarted,
    this.onCameraIdle,
    this.minMaxZoomPreference = MinMaxZoomPreference.unbounded,
    this.zoomControlsEnabled = true,
    this.zoomGesturesEnabled = true,
    this.scrollGesturesEnabled = true,
    this.rotateGesturesEnabled = true,
    this.tiltGesturesEnabled = true,
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = true,
    this.compassEnabled = true,
    this.mapToolbarEnabled = true,
    this.indoorViewEnabled = false,
    this.trafficEnabled = false,
    this.buildingsEnabled = true,
    this.liteModeEnabled = false,
    this.mapType = MapType.normal,
    this.padding = EdgeInsets.zero,
    this.style,
    this.gestureRecognizers = const <Factory<OneSequenceGestureRecognizer>>{},
  });

  final CameraPosition initialCameraPosition;
  final void Function(AdaptiveMapController controller)? onMapCreated;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final Set<Polygon> polygons;
  final Set<Circle> circles;
  final ArgumentCallback<LatLng>? onTap;
  final ArgumentCallback<LatLng>? onLongPress;
  final CameraPositionCallback? onCameraMove;
  final VoidCallback? onCameraMoveStarted;
  final VoidCallback? onCameraIdle;
  final MinMaxZoomPreference minMaxZoomPreference;
  final bool zoomControlsEnabled;
  final bool zoomGesturesEnabled;
  final bool scrollGesturesEnabled;
  final bool rotateGesturesEnabled;
  final bool tiltGesturesEnabled;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool compassEnabled;
  final bool mapToolbarEnabled;
  final bool indoorViewEnabled;
  final bool trafficEnabled;
  final bool buildingsEnabled;
  final bool liteModeEnabled;
  final MapType mapType;
  final EdgeInsets padding;
  final String? style;
  final Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers;

  @override
  State<AdaptiveMap> createState() => _AdaptiveMapState();
}

class _AdaptiveMapState extends State<AdaptiveMap> {
  final MapProviderState _provider = MapProviderState.instance;

  @override
  void initState() {
    super.initState();
    _provider.useOsm.addListener(_onProviderChanged);
    _provider.refresh();
  }

  @override
  void dispose() {
    _provider.useOsm.removeListener(_onProviderChanged);
    super.dispose();
  }

  void _onProviderChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final AdaptiveMap w = widget;
    if (!_provider.useOsm.value) {
      return GoogleMap(
        initialCameraPosition: w.initialCameraPosition,
        onMapCreated: w.onMapCreated == null ? null : (GoogleMapController c) => w.onMapCreated!(AdaptiveMapController._google(c)),
        markers: w.markers,
        polylines: w.polylines,
        polygons: w.polygons,
        circles: w.circles,
        onTap: w.onTap,
        onLongPress: w.onLongPress,
        onCameraMove: w.onCameraMove,
        onCameraMoveStarted: w.onCameraMoveStarted,
        onCameraIdle: w.onCameraIdle,
        minMaxZoomPreference: w.minMaxZoomPreference,
        zoomControlsEnabled: w.zoomControlsEnabled,
        zoomGesturesEnabled: w.zoomGesturesEnabled,
        scrollGesturesEnabled: w.scrollGesturesEnabled,
        rotateGesturesEnabled: w.rotateGesturesEnabled,
        tiltGesturesEnabled: w.tiltGesturesEnabled,
        myLocationEnabled: w.myLocationEnabled,
        myLocationButtonEnabled: w.myLocationButtonEnabled,
        compassEnabled: w.compassEnabled,
        mapToolbarEnabled: w.mapToolbarEnabled,
        indoorViewEnabled: w.indoorViewEnabled,
        trafficEnabled: w.trafficEnabled,
        buildingsEnabled: w.buildingsEnabled,
        liteModeEnabled: w.liteModeEnabled,
        mapType: w.mapType,
        padding: w.padding,
        style: w.style,
        gestureRecognizers: w.gestureRecognizers,
      );
    }
    return _OsmMap(widget: w, provider: _provider);
  }
}

class _OsmMap extends StatefulWidget {
  const _OsmMap({required this.widget, required this.provider});
  final AdaptiveMap widget;
  final MapProviderState provider;

  @override
  State<_OsmMap> createState() => _OsmMapState();
}

class _OsmMapState extends State<_OsmMap> {
  final fm.MapController _controller = fm.MapController();
  bool _moving = false;

  AdaptiveMap get w => widget.widget;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEvent(fm.MapEvent event) {
    final bool userOrAnimated = event is fm.MapEventMove || event is fm.MapEventFlingAnimation || event is fm.MapEventDoubleTapZoom || event is fm.MapEventScrollWheelZoom;
    if (userOrAnimated) {
      if (!_moving) {
        _moving = true;
        w.onCameraMoveStarted?.call();
      }
      w.onCameraMove?.call(CameraPosition(target: _fromLl(event.camera.center), zoom: event.camera.zoom));
    }
    final bool ended = event is fm.MapEventMoveEnd || event is fm.MapEventFlingAnimationEnd || event is fm.MapEventDoubleTapZoomEnd ||
        (event is fm.MapEventMove && event.source == fm.MapEventSource.mapController);
    if (ended && _moving) {
      _moving = false;
      w.onCameraIdle?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double minZoom = w.minMaxZoomPreference.minZoom ?? 2;
    final double maxZoom = (w.minMaxZoomPreference.maxZoom ?? widget.provider.maxZoom).clamp(minZoom, widget.provider.maxZoom).toDouble();
    int flags = fm.InteractiveFlag.drag | fm.InteractiveFlag.flingAnimation;
    if (w.zoomGesturesEnabled) flags |= fm.InteractiveFlag.pinchZoom | fm.InteractiveFlag.doubleTapZoom | fm.InteractiveFlag.scrollWheelZoom;
    if (!w.scrollGesturesEnabled) flags &= ~(fm.InteractiveFlag.drag | fm.InteractiveFlag.flingAnimation);
    if (w.rotateGesturesEnabled) flags |= fm.InteractiveFlag.rotate;

    return Stack(children: <Widget>[
      fm.FlutterMap(
        mapController: _controller,
        options: fm.MapOptions(
          initialCenter: _toLl(w.initialCameraPosition.target),
          initialZoom: w.initialCameraPosition.zoom.clamp(minZoom, maxZoom).toDouble(),
          minZoom: minZoom,
          maxZoom: maxZoom,
          interactionOptions: fm.InteractionOptions(flags: flags),
          onTap: w.onTap == null ? null : (_, ll.LatLng p) => w.onTap!(_fromLl(p)),
          onLongPress: w.onLongPress == null ? null : (_, ll.LatLng p) => w.onLongPress!(_fromLl(p)),
          onMapEvent: _onEvent,
          onMapReady: () => w.onMapCreated?.call(AdaptiveMapController._osm(_controller)),
        ),
        children: <Widget>[
          fm.TileLayer(
            urlTemplate: widget.provider.tileUrl,
            userAgentPackageName: 'co.ke.fastadeliveries',
            maxZoom: widget.provider.maxZoom,
          ),
          if (w.polygons.isNotEmpty)
            fm.PolygonLayer(polygons: <fm.Polygon>[
              for (final Polygon p in w.polygons)
                if (p.visible && p.points.length > 2)
                  fm.Polygon(
                    points: p.points.map(_toLl).toList(),
                    color: p.fillColor,
                    borderColor: p.strokeColor,
                    borderStrokeWidth: p.strokeWidth.toDouble(),
                  ),
            ]),
          if (w.circles.isNotEmpty)
            fm.CircleLayer(circles: <fm.CircleMarker>[
              for (final Circle c in w.circles)
                if (c.visible)
                  fm.CircleMarker(
                    point: _toLl(c.center),
                    radius: c.radius,
                    useRadiusInMeter: true,
                    color: c.fillColor,
                    borderColor: c.strokeColor,
                    borderStrokeWidth: c.strokeWidth.toDouble(),
                  ),
            ]),
          if (w.polylines.isNotEmpty)
            fm.PolylineLayer(polylines: <fm.Polyline>[
              for (final Polyline l in w.polylines)
                if (l.visible && l.points.length > 1)
                  fm.Polyline(points: l.points.map(_toLl).toList(), color: l.color, strokeWidth: l.width.toDouble()),
            ]),
          if (w.markers.isNotEmpty)
            fm.MarkerLayer(markers: <fm.Marker>[
              for (final Marker m in w.markers)
                if (m.visible)
                  fm.Marker(
                    point: _toLl(m.position),
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: GestureDetector(
                      onTap: () {
                        m.onTap?.call();
                        final String? title = m.infoWindow.title;
                        if (title != null && title.isNotEmpty) {
                          ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
                            content: Text(m.infoWindow.snippet == null ? title : '$title\n${m.infoWindow.snippet}'),
                            duration: const Duration(seconds: 3),
                          ));
                        }
                      },
                      child: _MarkerIcon(descriptor: m.icon),
                    ),
                  ),
            ]),
          fm.RichAttributionWidget(
            showFlutterMapAttribution: false,
            attributions: <fm.SourceAttribution>[fm.TextSourceAttribution(widget.provider.attribution)],
          ),
        ],
      ),
      if (w.zoomControlsEnabled)
        Positioned(
          right: 10 + w.padding.right,
          bottom: 24 + w.padding.bottom,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            _ZoomButton(icon: Icons.add, onPressed: () => _controller.move(_controller.camera.center, (_controller.camera.zoom + 1).clamp(minZoom, maxZoom).toDouble())),
            const SizedBox(height: 6),
            _ZoomButton(icon: Icons.remove, onPressed: () => _controller.move(_controller.camera.center, (_controller.camera.zoom - 1).clamp(minZoom, maxZoom).toDouble())),
          ]),
        ),
    ]);
  }
}

class _ZoomButton extends StatelessWidget {
  const _ZoomButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardColor,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(), onTap: onPressed, child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, size: 20))),
    );
  }
}

/// Draws a Google Maps marker icon (asset, bytes or coloured default pin) as a Flutter widget.
class _MarkerIcon extends StatelessWidget {
  const _MarkerIcon({required this.descriptor});
  final BitmapDescriptor descriptor;

  @override
  Widget build(BuildContext context) {
    try {
      final dynamic json = descriptor.toJson();
      if (json is List && json.isNotEmpty) {
        final String kind = '${json[0]}';
        if (kind == 'defaultMarker') {
          final double hue = json.length > 1 && json[1] is num ? (json[1] as num).toDouble() : 0;
          return Icon(Icons.location_on, size: 44, color: HSVColor.fromAHSV(1, hue % 360, 0.85, 0.9).toColor());
        }
        if (kind == 'fromAssetImage') return Image.asset('${json[1]}', fit: BoxFit.contain);
        if (kind == 'fromAsset') return Image.asset('${json[1]}', package: json.length > 2 ? '${json[2]}' : null, fit: BoxFit.contain);
        if (kind == 'asset' && json[1] is Map) return Image.asset('${(json[1] as Map<dynamic, dynamic>)['assetName']}', fit: BoxFit.contain);
        if (kind == 'fromBytes' && json[1] is Uint8List) return Image.memory(json[1] as Uint8List, fit: BoxFit.contain);
        if (kind == 'bytes' && json[1] is Map && (json[1] as Map<dynamic, dynamic>)['byteData'] is Uint8List) {
          return Image.memory((json[1] as Map<dynamic, dynamic>)['byteData'] as Uint8List, fit: BoxFit.contain);
        }
      }
    } catch (_) {
      // Unknown icon type: fall through to the default pin.
    }
    return Icon(Icons.location_on, size: 44, color: Theme.of(context).colorScheme.primary);
  }
}
