import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:latlong2/latlong.dart';
import 'nav_controller.dart';
import 'routing_provider.dart';
import 'follow_camera.dart';
import 'vehicle_marker.dart';
import 'map_widgets.dart';
import 'map_style_client.dart';
import 'gpu_map_panel.dart';
export 'map_widgets.dart';

class MapPanel extends StatefulWidget {
  const MapPanel({
    super.key,
    required this.navigation,
    this.car = false,
    this.loadNetwork = true,
  });
  final NavController navigation;
  final bool car, loadNetwork;
  @override
  State<MapPanel> createState() => _MapPanelHostState();
}

class _MapPanelHostState extends State<MapPanel> {
  bool gpuFailed = false;
  bool? previous3d;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.navigation,
    builder: (context, _) {
      final enabled = widget.navigation.settings['map3d'] != false;
      if (enabled != previous3d) {
        previous3d = enabled;
        gpuFailed = false;
      }
      if (widget.loadNetwork && enabled && !gpuFailed)
        return GpuMapPanel(
          navigation: widget.navigation,
          car: widget.car,
          onUnavailable: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => gpuFailed = true);
            });
          },
        );
      return Column(
        children: [
          if (gpuFailed)
            const Text(
              '3D chưa khởi động được trên máy này · đang dùng bản đồ 2D',
              style: TextStyle(fontSize: 16),
            ),
          Expanded(
            child: FlatMapPanel(
              navigation: widget.navigation,
              car: widget.car,
              loadNetwork: widget.loadNetwork,
            ),
          ),
        ],
      );
    },
  );
}

class FlatMapPanel extends StatefulWidget {
  const FlatMapPanel({
    super.key,
    required this.navigation,
    this.car = false,
    this.loadNetwork = true,
  });
  final NavController navigation;
  final bool car;
  final bool loadNetwork;
  @override
  State<FlatMapPanel> createState() => _FlatMapPanelState();
}

class _FlatMapPanelState extends State<FlatMapPanel> {
  final camera = MapController();
  MapStyleClient? client;
  vt.Style? style;
  bool ready = false, loading = false, follow = true;
  String? error;
  Brightness? brightness;
  int loadToken = 0, gesture = 0;
  int? fixTime;
  NavController get nav => widget.navigation;
  @override
  void initState() {
    super.initState();
    gesture = nav.gesture;
    nav.addListener(changed);
  }

  @override
  void didUpdateWidget(FlatMapPanel oldWidget) {
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
    if (widget.loadNetwork && brightness != next) {
      brightness = next;
      loadStyle();
    }
  }

  Future<void> loadStyle() async {
    final token = ++loadToken;
    setState(() {
      loading = true;
      error = null;
    });
    final nextClient = MapStyleClient();
    try {
      final next = await vt.StyleReader(
        uri:
            'https://tiles.openfreemap.org/styles/${brightness == Brightness.dark ? 'dark' : 'liberty'}',
        headers: const {'User-Agent': navUserAgent},
        httpClient: nextClient,
        language: 'vi',
        logger: const vt.Logger.noop(),
      ).read();
      if (!mounted || token != loadToken) {
        next.dispose();
        nextClient.close();
        return;
      }
      final previous = style;
      final oldClient = client;
      setState(() {
        style = next;
        client = nextClient;
        loading = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        previous?.dispose();
        oldClient?.close();
      });
    } catch (_) {
      nextClient.close();
      if (mounted && token == loadToken)
        setState(() {
          error = 'Chưa tải được bản đồ. Cần mạng cho vùng chưa xem.';
          loading = false;
        });
    }
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ready) return;
      if (widget.car && gesture != nav.gesture) {
        gesture = nav.gesture;
        follow = false;
        camera.move(
          camera.camera.center,
          (camera.camera.zoom + math.log(nav.scale) / math.ln2).clamp(
            3.0,
            20.0,
          ),
        );
      }
      if (follow &&
          nav.fix != null &&
          fixTime != nav.fix!.time.millisecondsSinceEpoch) {
        fixTime = nav.fix!.time.millisecondsSinceEpoch;
        camera.move(
          nav.fix!.point,
          FollowCamera.zoom(
            speedKmh: nav.fix!.speed * 3.6,
            navigating: nav.active && nav.precise && !nav.offRoute,
            turnMeters: nav.nextTurn == null ? null : nav.turnDistance,
          ),
        );
        camera.rotate(nav.settings['headingUp'] != false ? -nav.bearing : 0);
      }
    });
  }

  @override
  void dispose() {
    nav.removeListener(changed);
    loadToken++;
    camera.dispose();
    style?.dispose();
    client?.close();
    super.dispose();
  }

  void zoom(double delta) {
    if (!ready) return;
    setState(() => follow = false);
    camera.move(
      camera.camera.center,
      (camera.camera.zoom + delta).clamp(3.0, 20.0),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      NavSummary(navigation: nav),
      Expanded(
        child: Stack(
          children: [
            Positioned.fill(
              child: FlutterMap(
                mapController: camera,
                options: MapOptions(
                  initialCenter:
                      nav.fix?.point ?? const LatLng(21.281, 106.194),
                  initialZoom: nav.fix == null ? 13 : 16,
                  minZoom: 3,
                  maxZoom: 20,
                  onMapReady: () {
                    ready = true;
                    changed();
                  },
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture && follow) setState(() => follow = false);
                  },
                ),
                children: [
                  if (style != null)
                    vt.VectorTileLayer(
                      key: ValueKey(style),
                      theme: style!.theme,
                      tileProviders: style!.providers,
                      rasterSources: style!.rasterSources,
                      sprites: style!.sprites,
                      concurrency: 2,
                      diskCacheMaximumSizeInBytes: 300 * 1024 * 1024,
                      rasterCacheMaxBytes: 64 * 1024 * 1024,
                      memoryCacheMaxBytes: 16 * 1024 * 1024,
                      logger: const vt.Logger.noop(),
                    ),
                  if (nav.active && nav.route != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: nav.route!.points,
                          strokeWidth: 6,
                          color: nav.offRoute
                              ? Colors.grey
                              : const Color(0xff006eff),
                          borderStrokeWidth: 2,
                          borderColor: Colors.white,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (nav.goal != null)
                        Marker(
                          point: nav.goal!.point,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      if (nav.fix != null)
                        Marker(
                          point: nav.fix!.point,
                          width: 54,
                          height: 54,
                          rotate: true,
                          child: VehicleMarker(
                            fresh: nav.precise,
                            headingRadians:
                                (nav.bearing + camera.camera.rotation) *
                                math.pi /
                                180,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(error!, style: const TextStyle(fontSize: 16)),
                        TextButton(
                          onPressed: loadStyle,
                          child: const Text('Thử tải lại'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 4,
              bottom: 4,
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
                      onPressed: () async {
                        setState(() {
                          follow = true;
                          fixTime = null;
                        });
                        if (nav.fix != null && ready) {
                          camera.move(
                            nav.fix!.point,
                            FollowCamera.zoom(
                              speedKmh: nav.fix!.speed * 3.6,
                              navigating: nav.active && nav.precise,
                              turnMeters: nav.nextTurn == null
                                  ? null
                                  : nav.turnDistance,
                            ),
                          );
                          camera.rotate(
                            nav.settings['headingUp'] != false
                                ? -nav.bearing
                                : 0,
                          );
                        }
                        changed();
                        if (nav.fix == null || !nav.precise) {
                          try {
                            await nav.locate();
                          } catch (_) {}
                          if (mounted && nav.fix == null)
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(nav.status)));
                        }
                      },
                      icon: Icon(
                        Icons.my_location,
                        color: follow ? Colors.green : null,
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
          ],
        ),
      ),
      ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Text(
            'OpenFreeMap · © OpenMapTiles\n© OpenStreetMap contributors${nav.route == null ? '' : ' · ${nav.route!.provider}'}',
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    ],
  );
}
