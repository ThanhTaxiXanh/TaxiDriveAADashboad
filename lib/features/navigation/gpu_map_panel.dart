import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_flutter_gpu/maplibre_flutter_gpu.dart' as gpu;

import 'follow_camera.dart';
import 'map_3d_style.dart';
import 'map_road_sign.dart';
import 'map_style_client.dart';
import 'map_widgets.dart';
import 'nav_controller.dart';
import 'vehicle_marker.dart';
import '../road_data/road_screen.dart';
import '../road_data/road_widgets.dart';

import 'package:latlong2/latlong.dart' as geo;

class GpuMapPanel extends StatefulWidget {
  const GpuMapPanel({
    super.key,
    required this.navigation,
    required this.car,
    required this.onUnavailable,
  });
  final NavController navigation;
  final bool car;
  final VoidCallback onUnavailable;
  @override
  State<GpuMapPanel> createState() => _GpuMapPanelState();
}

class _GpuMapPanelState extends State<GpuMapPanel> {
  final follow = FollowCamera();
  gpu.MapLibreMapController? controller;
  final client = MapStyleClient();
  Map<String, dynamic>? base;
  String? styleString, error;
  Brightness? brightness;
  bool loading = false;
  int token = 0, routeRevision = -1, gesture = 0;
  int? fixTime;
  Object? lastRoute;
  int goalRevision = -1;
  bool lastActive = false;
  double viewportHeight = 0;
  Offset? pointerStart;
  int pointers = 0;
  DateTime? lastTap;
  NavController get nav => widget.navigation;
  @override
  void initState() {
    super.initState();
    gesture = nav.gesture;
    nav.addListener(changed);
  }

  @override
  void didUpdateWidget(GpuMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigation != nav) {
      oldWidget.navigation.removeListener(changed);
      nav.addListener(changed);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = Theme.of(context).brightness;
    if (brightness != next) {
      brightness = next;
      unawaited(loadStyle());
    }
  }

  Future<void> loadStyle() async {
    final current = ++token;
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final cached = await NavController.methods.invokeMethod<String>(
        'getMapStyle',
        {'mode': mode},
      );
      if (cached != null && mounted && current == token) {
        base = jsonDecode(cached) as Map<String, dynamic>;
        rebuildStyle();
        setState(() => loading = false);
      }
      final response = await client
          .get(
            Uri.parse(
              'https://tiles.openfreemap.org/styles/${mode == 'dark' ? 'dark' : 'liberty'}',
            ),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          response.bodyBytes.length > 2 * 1024 * 1024)
        throw const FormatException('Không tải được style');
      final document =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      await NavController.methods.invokeMethod('saveMapStyle', {
        'mode': mode,
        'json': jsonEncode(document),
      });
      if (!mounted || current != token) return;
      base = document;
      rebuildStyle();
      setState(() => loading = false);
    } catch (_) {
      if (mounted && current == token)
        setState(() {
          loading = false;
          if (base == null)
            error = 'Chưa tải được bản đồ 3D. Cần mạng cho lần mở đầu tiên.';
        });
    }
  }

  void rebuildStyle() {
    if (base == null) return;
    routeRevision = nav.revision;
    lastRoute = nav.route;
    goalRevision = nav.goalRevision;
    lastActive = nav.active;
    styleString = jsonEncode(
      navigationStyle(
        base!,
        route: nav.active ? nav.route : null,
        goal: nav.goal,
        dark: brightness == Brightness.dark,
      ),
    );
  }

  void changed() {
    if (!mounted) return;
    if (routeRevision != nav.revision ||
        !identical(lastRoute, nav.route) ||
        goalRevision != nav.goalRevision ||
        lastActive != nav.active)
      rebuildStyle();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || controller == null) return;
      if (widget.car && gesture != nav.gesture) {
        gesture = nav.gesture;
        follow.browse();
        try {
          await controller!.moveCamera(
            gpu.CameraUpdate.zoomBy(math.log(nav.scale) / math.ln2),
          );
        } catch (_) {}
      }
      await followPosition();
    });
  }

  Future<void> followPosition({bool force = false}) async {
    final c = controller;
    if (!mounted || c == null || !follow.following || nav.fix == null) return;
    if (!force && fixTime == nav.fix!.time.millisecondsSinceEpoch) return;
    fixTime = nav.fix!.time.millisecondsSinceEpoch;
    final p = nav.fix!.point;
    final zoom = FollowCamera.zoom(
      speedKmh: nav.fix!.speed * 3.6,
      navigating: nav.active && nav.precise && !nav.offRoute,
      turnMeters: nav.nextTurn == null ? null : nav.turnDistance,
    );
    try {
      await c.easeCamera(
        gpu.CameraUpdate.newCameraPosition(
          gpu.CameraPosition(
            target: gpu.LatLng(p.latitude, p.longitude),
            zoom: zoom,
            tilt: FollowCamera.pitch,
            bearing: nav.settings['headingUp'] != false ? nav.bearing : 0,
          ),
        ),
        duration: Duration(milliseconds: force ? 450 : 650),
      );
    } catch (_) {
      /* Widget disposal may cancel an in-flight camera request. */
    }
  }

  Future<void> recenter() async {
    follow.recenter();
    fixTime = null;
    setState(() {});
    await followPosition(force: true);
    if (nav.fix == null || !nav.precise) {
      try {
        await nav.locate();
      } catch (_) {}
      if (mounted && nav.fix == null)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(nav.status)));
    }
  }

  Future<void> zoom(double value) async {
    follow.browse();
    setState(() {});
    try {
      await controller?.moveCamera(gpu.CameraUpdate.zoomBy(value));
    } catch (_) {}
  }

  void pointerDown(PointerDownEvent e) {
    pointers++;
    pointerStart = e.localPosition;
    final now = DateTime.now();
    if (pointers > 1 ||
        lastTap != null && now.difference(lastTap!).inMilliseconds < 300)
      follow.browse();
    lastTap = now;
  }

  @override
  void dispose() {
    token++;
    nav.removeListener(changed);
    controller = null;
    client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      NavSummary(navigation: nav),
      Expanded(
        child: LayoutBuilder(
          builder: (context, bounds) {
            viewportHeight = bounds.maxHeight;
            final p = nav.fix?.point;
            return Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    onPointerDown: pointerDown,
                    onPointerUp: (_) {
                      pointers = math.max(0, pointers - 1);
                      pointerStart = null;
                    },
                    onPointerCancel: (_) {
                      pointers = 0;
                      pointerStart = null;
                    },
                    onPointerMove: (e) {
                      if (pointerStart != null &&
                          (e.localPosition - pointerStart!).distance > 6) {
                        if (follow.following) setState(follow.browse);
                      }
                    },
                    onPointerSignal: (_) => setState(follow.browse),
                    child: styleString == null
                        ? const ColoredBox(color: Color(0xff202730))
                        : gpu.MapLibreMap(
                            styleString: styleString!,
                            initialCameraPosition: gpu.CameraPosition(
                              target: p == null
                                  ? const gpu.LatLng(21.281, 106.194)
                                  : gpu.LatLng(p.latitude, p.longitude),
                              zoom: p == null ? 14 : 17.8,
                              tilt: 60,
                              bearing: nav.settings['headingUp'] != false
                                  ? nav.bearing
                                  : 0,
                            ),
                            minMaxTiltPreference:
                                const gpu.MinMaxTiltPreference(60, 60),
                            minMaxZoomPreference:
                                const gpu.MinMaxZoomPreference(3, 20),
                            tiltGesturesEnabled: false,
                            rotateGesturesEnabled: false,
                            compassEnabled: false,
                            attributionButtonEnabled: false,
                            symbolCompositingMode:
                                gpu.SymbolCompositingMode.fastOverlay,
                            userLocation: p == null
                                ? null
                                : gpu.MapUserLocation(
                                    position: gpu.LatLng(
                                      p.latitude,
                                      p.longitude,
                                    ),
                                    headingDegrees: nav.bearing,
                                    accuracyMeters: nav.fix!.accuracy,
                                  ),
                            userLocationBuilder: (_, state) => VehicleMarker(
                              fresh: nav.precise,
                              headingRadians: state.headingRadians ?? 0,
                            ),
                            overlayBuilder: (_, frame) {
                              final c = controller;
                              if (c == null) return null;
                              return MapSignOverlay(
                                signs: nav.road.mapSigns,
                                viewport: frame.logicalSize,
                                project: (point) => c.toScreenOffset(
                                  gpu.LatLng(point.latitude, point.longitude),
                                ),
                                onTap: widget.car
                                    ? null
                                    : (sign) => sign.source == 'user'
                                          ? editPinAt(context, nav, sign.point)
                                          : showMapSignDetails(context, sign),
                              );
                            },
                            onMapLongClick: widget.car
                                ? null
                                : (_, point) => editPinAt(
                                    context,
                                    nav,
                                    geo.LatLng(point.latitude, point.longitude),
                                  ),
                            onMapClick: widget.car
                                ? null
                                : (_, point) => editPinAt(
                                    context,
                                    nav,
                                    geo.LatLng(point.latitude, point.longitude),
                                    existingOnly: true,
                                  ),
                            onMapCreated: (c) {
                              controller = c;
                              unawaited(
                                c
                                    .updateContentInsets(
                                      EdgeInsets.only(top: viewportHeight * .4),
                                    )
                                    .then((_) => followPosition(force: true))
                                    .catchError((Object _) {}),
                              );
                            },
                            onStyleLoadedCallback: () =>
                                unawaited(followPosition(force: true)),
                            errorBuilder: (_, _) {
                              widget.onUnavailable();
                              return const Center(
                                child: Text(
                                  'Đang mở bản đồ 2D dự phòng',
                                  style: TextStyle(fontSize: 16),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Positioned(
                  left: 4,
                  right: 68,
                  top: 4,
                  child: RoadWarnings(controller: nav.road),
                ),
                if (loading)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(),
                  ),
                if (error != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          children: [
                            Text(error!, style: const TextStyle(fontSize: 16)),
                            TextButton(
                              onPressed: loadStyle,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 8,
                  bottom: 8,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: SingleChildScrollView(
                      child: Card(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Phóng to bản đồ',
                              onPressed: () => zoom(1),
                              icon: const Icon(Icons.add),
                            ),
                            IconButton(
                              tooltip: 'Thu nhỏ bản đồ',
                              onPressed: () => zoom(-1),
                              icon: const Icon(Icons.remove),
                            ),
                            IconButton(
                              tooltip: 'Theo xe',
                              onPressed: recenter,
                              icon: Icon(
                                Icons.navigation,
                                color: follow.following ? Colors.green : null,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Điểm đến đã lưu',
                              onPressed: () => showPlaces(context, nav),
                              icon: const Icon(Icons.star),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      Text(
        'OpenFreeMap · © OpenMapTiles\n© OpenStreetMap contributors${nav.route == null ? '' : ' · ${nav.route!.provider}'}',
        style: const TextStyle(fontSize: 16),
      ),
    ],
  );
}
