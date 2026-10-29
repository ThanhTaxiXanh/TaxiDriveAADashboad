import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'nav_models.dart';
import '../road_data/road_controller.dart';
import 'routing_provider.dart';

class NavController extends ChangeNotifier {
  NavController({this.connected = true, this.car = false, http.Client? client})
    : client = client ?? http.Client() {
    road = RoadController(connected: connected, car: car);
    road.addListener(notify);
    if (connected) {
      subscription = events.receiveBroadcastStream().listen(
        (raw) => accept(jsonDecode(raw as String) as Map<String, dynamic>),
        onError: (Object _) {
          status = 'Kết nối vị trí bị ngắt; mở lại ứng dụng';
          notify();
        },
      );
      unawaited(reload());
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        evaluate();
        notify();
      });
    }
  }
  static const methods = MethodChannel('taxi/navigation');
  static const events = EventChannel('taxi/navigation/events');
  static const location = MethodChannel('taxi/location_control');
  final bool connected, car;
  late final RoadController road;
  bool get hasHeading => _hasBearing;
  final http.Client client;
  StreamSubscription<dynamic>? subscription;
  Timer? timer;
  bool closed = false,
      running = false,
      active = false,
      voiceReady = false,
      working = false,
      searching = false;
  bool carConnected = false, backgroundLocation = false;
  NavFix? fix;
  Place? goal;
  List<Place> places = [];
  Map<String, dynamic> settings = {};
  Map<String, dynamic> searchCache = {};
  bool cacheLoaded = false;
  String status = 'Bật vị trí trên điện thoại';
  int revision = -1, goalRevision = 0, generation = 0, gesture = 0;
  double scale = 1, bearing = 0;
  int? _nativeGesture;
  bool _hasBearing = false;
  NavRoute? route;
  RouteProgress? progress;
  int offCount = 0;
  int? offFixTime;
  DateTime? lastSearch;
  bool get precise => fix?.usable(DateTime.now()) ?? false;
  bool get offRoute => (progress?.distance ?? 0) > 50;
  double? get remaining => precise && route != null && progress != null
      ? math.max(0.0, route!.length - progress!.along)
      : null;
  TurnStep? get nextTurn {
    if (route == null || progress == null || route!.steps.isEmpty) return null;
    return route!.steps
            .where((s) => route!.cumulative[s.index] > progress!.along + 10)
            .firstOrNull ??
        route!.steps.last;
  }

  double get turnDistance => nextTurn == null || progress == null
      ? 0
      : math.max(0, route!.cumulative[nextTurn!.index] - progress!.along);
  String get instruction {
    if (!running) return 'Bật vị trí trên điện thoại';
    if (!precise) return 'Chờ GPS chính xác · không chỉ dẫn khi vị trí cũ/yếu';
    if (!active || route == null) return status;
    if (offRoute) return 'Lệch tuyến · $status';
    return nextTurn?.text ?? 'Đi theo tuyến';
  }

  String endpoint(String key) =>
      settings[key] as String? ??
      switch (key) {
        'valhalla' => 'https://valhalla1.openstreetmap.de/route',
        'osrm' =>
          'https://routing.openstreetmap.de/routed-car/route/v1/driving',
        _ => 'https://photon.komoot.io/api/',
      };
  void notify() {
    if (!closed) {
      road.update(fix: running ? fix : null, heading: bearing, headingKnown: _hasBearing, route: active ? route : null, version: '$revision:$goalRevision:$active');
      notifyListeners();
    }
  }

  Future<void> reload() async {
    try {
      final raw = await methods.invokeMethod<String>('snapshot');
      if (!closed) accept(jsonDecode(raw!) as Map<String, dynamic>);
    } catch (_) {
      if (!closed) {
        status = 'Không đọc được trạng thái bản đồ';
        notify();
      }
    }
  }

  void accept(Map<String, dynamic> data) {
    if (closed) return;
    carConnected = data['carConnected'] == true;
    backgroundLocation = data['backgroundLocation'] == true;
    running = data['running'] == true;
    active = data['active'] == true;
    voiceReady = data['voiceReady'] == true;
    status = data['status'] as String? ?? '';
    settings = Map<String, dynamic>.from(data['settings'] as Map? ?? {});
    goal = data['goal'] is Map ? Place.fromJson(data['goal']) : null;
    places = [for (final p in data['places'] as List? ?? []) Place.fromJson(p)];
    final nextGoal = data['goalRevision'] as int? ?? 0;
    if (nextGoal != goalRevision) {
      goalRevision = nextGoal;
      progress = null;
      offCount = 0;
    }
    fix = data['fix'] is Map ? NavFix.fromJson(data['fix']) : null;
    if (fix != null && fix!.bearing >= 0 && fix!.speed >= 2) {
      bearing = _hasBearing
          ? smoothBearing(bearing, fix!.bearing)
          : fix!.bearing;
      _hasBearing = true;
    }
    final incomingGesture = data['gesture'] as int? ?? 0;
    if (_nativeGesture != null && _nativeGesture != incomingGesture) gesture++;
    _nativeGesture = incomingGesture;
    scale = (data['scale'] as num? ?? 1).toDouble();
    final next = data['routeRevision'] as int? ?? 0;
    if (next != revision) {
      revision = next;
      route = null;
      progress = null;
      unawaited(loadRoute());
    }
    evaluate();
    notify();
  }

  Future<void> loadRoute() async {
    final token = ++generation;
    try {
      final raw = await methods.invokeMethod<String>('getRoute');
      final value = raw == null
          ? null
          : NavRoute.fromJson(jsonDecode(raw) as Map);
      if (closed || token != generation) return;
      route = value;
      progress = null;
      offCount = 0;
      evaluate();
      notify();
    } catch (_) {
      if (!closed && token == generation) {
        route = null;
        status = 'Tuyến đã lưu không đọc được; hãy chọn lại điểm đến';
        notify();
      }
    }
  }

  void evaluate() {
    if (closed || !connected || !running || !active || !precise || goal == null)
      return;
    final r = route;
    if (r != null) {
      progress = projectRoute(r, fix!.point, previous: progress?.along);
      if (fix!.time.millisecondsSinceEpoch != offFixTime) {
        offFixTime = fix!.time.millisecondsSinceEpoch;
        offCount = offRoute ? offCount + 1 : 0;
      }
      if (!offRoute &&
          (remaining ?? double.infinity) < 45 &&
          meters(fix!.point, goal!.point) < 30 &&
          fix!.accuracy <= 30) {
        unawaited(methods.invokeMethod('arrived'));
        active = false;
        return;
      }
      if (!offRoute && nextTurn != null) {
        final distance = turnDistance;
        final bucket = distance <= 40
            ? 'now'
            : distance <= 150
            ? 'near'
            : distance <= 500
            ? 'soon'
            : null;
        if (bucket != null) {
          final words = distance <= 40
              ? nextTurn!.text
              : 'Sau ${(distance / 10).round() * 10} mét, ${nextTurn!.text}';
          unawaited(
            methods
                .invokeMethod('speak', {
                  'text': words,
                  'id': '$revision:${nextTurn!.index}:$bucket',
                  'revision': revision,
                })
                .catchError((Object _) {}),
          );
        }
      }
    }
    if (r == null || offCount >= 3) unawaited(calculate());
  }

  Future<void> calculate() async {
    if (working || closed || goal == null || !precise) return;
    working = true;
    final goalVersion = goalRevision;
    String? lease;
    try {
      lease = await methods.invokeMethod<String>('claimRoute', {
        'revision': goalVersion,
      });
      if (lease == null || closed) return;
      NavRoute result;
      try {
        result = await ValhallaRouting(
          client,
          endpoint('valhalla'),
        ).route(fix!.point, goal!.point);
      } catch (_) {
        result = await OsrmRouting(
          client,
          endpoint('osrm'),
        ).route(fix!.point, goal!.point);
      }
      if (closed) return;
      await methods.invokeMethod('setRoute', {
        'lease': lease,
        'revision': goalVersion,
        'route': jsonEncode(result.toJson()),
      });
    } catch (_) {
      if (!closed && lease != null)
        await methods
            .invokeMethod('routeFailure', {
              'lease': lease,
              'revision': goalVersion,
            })
            .catchError((Object _) {});
    } finally {
      working = false;
    }
  }

  Future<void> locate() async {
    if (car) {
      await methods.invokeMethod('requestLocation');
    } else {
      await startLocation();
    }
    await reload();
  }

  Future<void> startLocation() => location.invokeMethod('start');
  Future<void> stopLocation() => methods.invokeMethod('stopLocation');
  Future<void> start(Place place) => methods.invokeMethod('destination', {
    'place': jsonEncode(place.toJson()),
  });
  Future<void> stop() => methods.invokeMethod('stop');
  Future<void> savePlace(Place place, {bool remove = false}) =>
      methods.invokeMethod(remove ? 'removePlace' : 'savePlace', {
        'place': jsonEncode(place.toJson()),
      });
  Future<void> saveSettings(Map<String, dynamic> value) {
    for (final key in ['valhalla', 'osrm', 'photon']) {
      serverUri(value[key] as String);
    }
    return methods.invokeMethod('saveSettings', {'json': jsonEncode(value)});
  }

  Future<List<Place>> search(String input) async {
    final query = input.trim();
    if (query.length < 2 || query.length > 150)
      throw const FormatException('Nhập từ 2 đến 150 ký tự');
    final pair = query.split(',');
    if (pair.length == 2 &&
        double.tryParse(pair[0].trim()) != null &&
        double.tryParse(pair[1].trim()) != null)
      return [
        Place(
          'Tọa độ đã nhập',
          coordinate(
            double.parse(pair[0].trim()),
            double.parse(pair[1].trim()),
          ),
        ),
      ];
    if (searching) throw const FormatException('Đang tìm địa điểm');
    searching = true;
    try {
      if (!cacheLoaded) {
        try {
          searchCache = Map<String, dynamic>.from(
            jsonDecode(
              await methods.invokeMethod<String>('getSearchCache') ?? '{}',
            ) as Map,
          );
        } catch (_) {
          searchCache = {};
        }
        cacheLoaded = true;
      }
      final key = '${endpoint('photon')}|${query.toLowerCase()}';
      if (searchCache[key] is List)
        return [for (final p in searchCache[key]) Place.fromJson(p)];
      final elapsed = lastSearch == null
          ? 1100
          : DateTime.now().difference(lastSearch!).inMilliseconds;
      if (elapsed < 1100)
        throw const FormatException('Chờ một giây rồi tìm tiếp');
      lastSearch = DateTime.now();
      final data = await getJson(
        client,
        serverUri(endpoint('photon'))
            .replace(queryParameters: {'q': query, 'limit': '5'}),
      );
      final result = <Place>[];
      for (final item in data['features'] as List) {
        final p = item['properties'] as Map;
        final name = [
          p['name'],
          p['street'],
          p['city'],
          p['country'],
        ].whereType<String>().where((v) => v.isNotEmpty).toSet().join(', ');
        if (name.isNotEmpty)
          result.add(
            Place(
              name.substring(0, math.min(150, name.length)),
              coordinate(
                item['geometry']['coordinates'][1],
                item['geometry']['coordinates'][0],
              ),
            ),
          );
      }
      searchCache[key] = [for (final p in result) p.toJson()];
      while (searchCache.length > 64) {
        searchCache.remove(searchCache.keys.first);
      }
      await methods.invokeMethod('saveSearchCache', {
        'json': jsonEncode(searchCache),
      });
      return result;
    } finally {
      searching = false;
    }
  }

  @override
  void dispose() {
    closed = true;
    road.removeListener(notify);
    road.dispose();
    client.close();
    timer?.cancel();
    subscription?.cancel();
    super.dispose();
  }
}
