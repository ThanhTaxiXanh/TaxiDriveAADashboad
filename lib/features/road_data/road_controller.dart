import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import '../navigation/nav_models.dart';
import 'road_engine.dart';
import 'road_models.dart';

class RoadController extends ChangeNotifier {
  RoadController({this.connected = true, this.car = false}) {
    if (connected) {
      subscription = events.receiveBroadcastStream().listen((raw) {
        try { accept(jsonDecode(raw as String) as Map); } catch (_) { message = 'Chưa đọc được trạng thái dữ liệu đường'; notify(); }
      }, onError: (Object _) { message = 'Dữ liệu đường tạm ngắt kết nối'; notify(); });
      unawaited(reload());
    }
  }
  static const methods = MethodChannel('taxi/roads');
  static const events = EventChannel('taxi/roads/events');
  static const files = MethodChannel('taxi/road_files');
  final bool connected, car;
  StreamSubscription<dynamic>? subscription;
  final engine = RoadEngine();
  RoadNearby nearby = const RoadNearby();
  RoadStatus status = const RoadStatus();
  Map<String, dynamic> settings = {}, pack = {};
  List<RoadSign> pins = [];
  int revision = -1, progress = 0;
  bool downloading = false, closed = false, querying = false;
  String message = 'Chưa tải gói dữ liệu đường';
  NavFix? _fix;
  double _heading = 0;
  bool _headingKnown = false;
  NavRoute? _route;
  String _version = '';
  LatLng? queryOrigin;
  DateTime? lastQuery;
  int queryGeneration = 0;
  int lastBeep = 0;
  bool get enabled => settings['enabled'] != false;
  void notify() { if (!closed) notifyListeners(); }
  Future<void> reload() async {
    try { final raw = await methods.invokeMethod<String>('snapshot'); if (!closed && raw != null) accept(jsonDecode(raw) as Map); } catch (_) { if (!closed) { message = 'Chưa kết nối dữ liệu đường'; notify(); } }
  }
  void accept(Map raw) {
    if (closed) return;
    final next = (raw['revision'] as num? ?? 0).toInt();
    settings = Map<String, dynamic>.from(raw['settings'] as Map? ?? {});
    pack = Map<String, dynamic>.from(raw['pack'] as Map? ?? {});
    pins = [for (final p in raw['pins'] as List? ?? []) RoadSign.fromJson(p)];
    downloading = raw['downloading'] == true;
    message = raw['message'] as String? ?? '';
    progress = (raw['progress'] as num? ?? 0).toInt();
    if (next != revision) { revision = next; engine.reset(); lastQuery = null; queryGeneration++; }
    evaluate(); notify();
    if (connected && _fix != null) unawaited(query());
  }
  void update({required NavFix? fix, required double heading, required bool headingKnown, NavRoute? route, String version = ''}) {
    if (closed) return;
    _fix = fix; _heading = heading; _headingKnown = headingKnown; _route = route; _version = version;
    evaluate();
    if (connected && enabled && fix != null && fix.usable(DateTime.now())) unawaited(query());
  }
  void evaluate() {
    final p = _fix?.point;
    final usable = p != null && queryOrigin != null && meters(p, queryOrigin!) <= 100;
    status = enabled ? engine.evaluate(fix: _fix, heading: _heading, headingKnown: _headingKnown, nearby: usable ? nearby : const RoadNearby(), pins: pins, route: _route, version: _version, vehicle: settings['vehicle'] as String? ?? 'car', tolerance: (settings['tolerance'] as num? ?? 5).toInt(), estimates: settings['estimates'] != false) : const RoadStatus();
    final now = DateTime.now().millisecondsSinceEpoch;
    if (connected && status.overspeed && !status.limit.estimated && settings['beep'] == true && now - lastBeep > 30000) {
      lastBeep = now; unawaited(methods.invokeMethod('beep').catchError((Object _) {}));
    }
  }
  Future<void> query() async {
    final fix = _fix;
    if (closed || querying || !enabled || fix == null || !fix.usable(DateTime.now())) return;
    final now = DateTime.now();
    if (lastQuery != null && now.difference(lastQuery!).inSeconds < 3 && queryOrigin != null && meters(fix.point, queryOrigin!) < 60) return;
    querying = true; lastQuery = now;
    final token = queryGeneration;
    try {
      final raw = await methods.invokeMethod<String>('nearby', {'lat': fix.point.latitude, 'lon': fix.point.longitude});
      if (closed || token != queryGeneration || raw == null) return;
      nearby = RoadNearby.fromJson(jsonDecode(raw) as Map);
      queryOrigin = fix.point;
      evaluate(); notify();
    } catch (_) { if (!closed) { nearby = const RoadNearby(); message = 'Chưa đọc được gói đường; có thể tải lại trong Cài đặt'; evaluate(); notify(); } }
    finally { querying = false; }
  }
  Future<void> saveSettings(Map<String, dynamic> value) => methods.invokeMethod('saveSettings', {'json': jsonEncode(value)});
  Future<void> download() => methods.invokeMethod('download');
  Future<void> deletePin(String id) => methods.invokeMethod('deletePin', {'id': id});
  Future<void> importPins() async {
    final raw = await files.invokeMethod<String>('import');
    if (raw != null) await methods.invokeMethod('importPins', {'json': raw});
  }
  Future<void> exportPins() async {
    final raw = await methods.invokeMethod<String>('exportPins');
    if (raw != null) await files.invokeMethod('export', {'json': raw});
  }
  Future<void> savePin(RoadSign pin) async {
    var result = pin;
    try {
      final raw = await methods.invokeMethod<String>('nearby', {'lat': pin.point.latitude, 'lon': pin.point.longitude});
      if (raw != null) {
        final data = RoadNearby.fromJson(jsonDecode(raw) as Map);
        MatchedRoad? match;
        if (pin.bearing != null) { match = matchRoad(data.roads, pin.point, pin.bearing!); }
        else {
          final candidates = <MatchedRoad>[];
          for (final edge in data.roads) {
            final p = projectRoute(edge.geometry, pin.point);
            if (p.distance <= 30) candidates.add(MatchedRoad(edge, p, true, 0, p.distance));
          }
          candidates.sort((a,b) => a.score.compareTo(b.score));
          if (candidates.isNotEmpty && !candidates.skip(1).any((c) => c.edge.id != candidates.first.edge.id && c.score < candidates.first.score + 4)) match = candidates.first;
        }
        if (match != null) result = RoadSign(id: pin.id, point: pin.point, kind: pin.kind, value: pin.value, bearing: pin.bearing, way: match.edge.id, along: match.along, note: pin.note, scope: pin.scope);
      }
    } catch (_) { /* An unbound pin remains usable with the narrow forward cone. */ }
    await methods.invokeMethod('savePin', {'json': jsonEncode(result.toJson())});
  }
  @override
  void dispose() { closed = true; queryGeneration++; subscription?.cancel(); super.dispose(); }
}
