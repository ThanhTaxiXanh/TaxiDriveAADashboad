import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'nav_controller.dart';
import 'nav_models.dart';
import 'routing_provider.dart';

class MapStyleClient extends http.BaseClient {
  final http.Client inner = http.Client();
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    request.headers['User-Agent'] = navUserAgent;
    final response = await inner
        .send(request)
        .timeout(const Duration(seconds: 15));
    if (!['/styles/liberty', '/styles/dark'].contains(request.url.path) ||
        response.statusCode != 200)
      return response;
    final text = await response.stream.bytesToString().timeout(
      const Duration(seconds: 15),
    );
    final json = jsonDecode(text) as Map;
    for (final layer in json['layers'] as List) {
      if (layer['type'] == 'symbol' &&
          layer['layout'] is Map &&
          layer['layout']['text-field'] != null) {
        final value = layer['layout']['text-size'];
        layer['layout']['text-size'] = value is num ? math.max(16, value) : 18;
      }
    }
    final bytes = utf8.encode(jsonEncode(json));
    return http.StreamedResponse(
      Stream.value(bytes),
      response.statusCode,
      headers: {...response.headers}
        ..remove('content-length')
        ..remove('content-encoding'),
      request: request,
    );
  }

  @override
  void close() {
    inner.close();
    super.close();
  }
}

class MapPanel extends StatefulWidget {
  const MapPanel({
    super.key,
    required this.navigation,
    this.car = false,
    this.loadNetwork = true,
  });
  final NavController navigation;
  final bool car;
  final bool loadNetwork;
  @override
  State<MapPanel> createState() => _MapPanelState();
}

class _MapPanelState extends State<MapPanel> {
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
    nav.addListener(changed);
  }

  @override
  void didUpdateWidget(MapPanel oldWidget) {
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
          nav.precise &&
          fixTime != nav.fix!.time.millisecondsSinceEpoch) {
        fixTime = nav.fix!.time.millisecondsSinceEpoch;
        final speed = nav.fix!.speed * 3.6;
        camera.move(
          nav.fix!.point,
          speed > 80
              ? 15.5
              : speed > 40
              ? 16.5
              : 17.5,
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
                  if (nav.route != null)
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
                          width: 40,
                          height: 40,
                          child: Icon(
                            Icons.my_location,
                            color: nav.precise ? Colors.blue : Colors.grey,
                            size: 32,
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
                      onPressed: () {
                        setState(() {
                          follow = true;
                          fixTime = null;
                        });
                        changed();
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

String distanceText(double meters) => meters < 1000
    ? '${meters.round()} m'
    : '${(meters / 1000).toStringAsFixed(1)} km';

class NavSummary extends StatelessWidget {
  const NavSummary({super.key, required this.navigation});
  final NavController navigation;
  @override
  Widget build(BuildContext context) {
    final n = navigation;
    return SizedBox(
      height: 144,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  n.instruction,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    Text(
                      n.precise && n.fix!.speed >= 0
                          ? '${(n.fix!.speed * 3.6).round()} km/h'
                          : 'GPS: —',
                      style: const TextStyle(fontSize: 22),
                    ),
                    if (n.active && n.precise && n.route != null && !n.offRoute)
                      Text(
                        '${distanceText(n.turnDistance)} tới thao tác',
                        style: const TextStyle(fontSize: 16),
                      ),
                  ],
                ),
                if (n.remaining != null)
                  Text(
                    'Còn ${distanceText(n.remaining!)} · ~${math.max(1, (n.route!.seconds * n.remaining! / math.max(1, n.route!.length) / 60).round())} phút',
                    style: const TextStyle(fontSize: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showPlaces(
  BuildContext context,
  NavController nav,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Text('Yêu thích và gần đây', style: TextStyle(fontSize: 22)),
          if (!nav.running)
            const Text(
              'Mở điện thoại để bật vị trí trước khi dẫn đường',
              style: TextStyle(fontSize: 16),
            ),
          if (nav.places.isEmpty)
            const Text(
              'Tìm và lưu địa điểm trên điện thoại',
              style: TextStyle(fontSize: 16),
            ),
          for (final p in [
            ...nav.places.where((p) => p.favorite),
            ...nav.places.where((p) => !p.favorite),
          ])
            ListTile(
              leading: Icon(p.favorite ? Icons.star : Icons.history),
              title: Text(p.name, style: const TextStyle(fontSize: 18)),
              enabled: nav.running,
              onTap: () async {
                try {
                  await nav.start(p);
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {
                  if (context.mounted)
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Bật vị trí trên điện thoại rồi chọn lại điểm đến',
                        ),
                      ),
                    );
                }
              },
            ),
          TextButton(
            onPressed: () async {
              await nav.stop();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Dừng dẫn đường'),
          ),
        ],
      ),
    ),
  ),
);
