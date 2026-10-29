import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../navigation/nav_models.dart';
import 'road_models.dart';

class MatchedRoad {
  const MatchedRoad(
    this.edge,
    this.progress,
    this.forward,
    this.heading,
    this.score,
  );
  final RoadEdge edge;
  final RouteProgress progress;
  final bool forward;
  final double heading, score;
  double get along => edge.offset + progress.along;
}

MatchedRoad? matchRoad(
  List<RoadEdge> roads,
  LatLng point,
  double heading, {
  int? previous,
}) {
  final candidates = <MatchedRoad>[];
  for (final road in roads) {
    final p = projectRoute(road.geometry, point);
    if (p.distance > 30) continue;
    final h = course(
      road.geometry.points[p.segment],
      road.geometry.points[p.segment + 1],
    );
    final forward =
        road.oneWay == 1 ||
        road.oneWay != -1 &&
            angleDifference(heading, h) <= angleDifference(heading, h + 180);
    final travel = (h + (forward ? 0 : 180)) % 360;
    final difference = angleDifference(heading, travel);
    if (difference >= 60) continue;
    candidates.add(
      MatchedRoad(
        road,
        p,
        forward,
        travel,
        p.distance + difference * .12 - (previous == road.id ? 3 : 0),
      ),
    );
  }
  candidates.sort((a, b) => a.score.compareTo(b.score));
  if (candidates.isEmpty) return null;
  final best = candidates.first;
  // Parallel roads/junctions with comparable geometry are ambiguous. Do not
  // present one road's numeric limit as if the match were certain.
  if (candidates
      .skip(1)
      .any((c) => c.edge.id != best.edge.id && c.score < best.score + 4))
    return null;
  return best;
}

int? parseMaxspeed(String? raw) {
  final m = RegExp(
    r'^\s*(\d+(?:\.\d+)?)\s*(km/h|kph|mph)?\s*$',
    caseSensitive: false,
  ).firstMatch(raw ?? '');
  if (m == null) return null;
  final value =
      double.parse(m[1]!) * (m[2]?.toLowerCase() == 'mph' ? 1.609344 : 1);
  return value >= 1 && value <= 150 ? value.round() : null;
}

int? legalEstimate(
  String vehicle, {
  required bool urban,
  required bool dividedOrTwoLanesOneWay,
  required bool motorway,
}) {
  if (motorway) return null; // 120 is a ceiling, not every motorway's limit.
  if (vehicle == 'special') return 40;
  if (vehicle == 'quadPassenger') return 30;
  if (vehicle == 'quadCargo') return 50;
  if (urban) return dividedOrTwoLanesOneWay ? 60 : 50;
  final pair = switch (vehicle) {
    'heavy' => (80, 70),
    'bus' => (70, 60),
    'towing' => (60, 50),
    _ => (90, 80),
  };
  return dividedOrTwoLanesOneWay ? pair.$1 : pair.$2;
}

SpeedLimit resolveLimit(
  MatchedRoad? match, {
  required List<RoadSign> pins,
  required LatLng position,
  required double heading,
  required bool urbanHint,
  String vehicle = 'car',
  bool estimates = true,
}) {
  final active = <(RoadSign, double)>[];
  for (final pin in pins.where((s) => s.kind == 'speed' && s.value != null)) {
    if (pin.bearing != null && angleDifference(pin.bearing!, heading) >= 60)
      continue;
    double? passed;
    if (match != null && pin.way != null) {
      if (pin.way != match.edge.id || pin.along == null) continue;
      passed = (match.along - pin.along!) * (match.forward ? 1 : -1);
    } else if (pin.way == null) {
      final dist = meters(pin.point, position),
          difference = angleDifference(course(pin.point, position), heading);
      if (dist > 2 && difference > 30) continue;
      if (dist * math.sin(difference * math.pi / 180).abs() > 15) continue;
      passed = dist;
    }
    if (passed != null && passed >= 0 && passed <= pin.scope)
      active.add((pin, passed));
  }
  active.sort((a, b) => a.$2.compareTo(b.$2));
  if (active.isNotEmpty)
    return SpeedLimit(
      active.first.$1.value,
      'user',
      reason: 'Trong phạm vi ghim ${active.first.$1.scope.round()} m',
    );
  if (match == null)
    return const SpeedLimit(
      null,
      'unknown',
      reason: 'Chưa khớp chắc đoạn đường',
    );
  final tags = match.edge.tags,
      direction = match.forward ? 'forward' : 'backward';
  final vehicleKey = switch (vehicle) {
    'heavy' => 'hgv',
    'bus' => 'bus',
    'towing' => 'hgv_articulated',
    _ => 'motorcar',
  };
  final prefixes = [
    'maxspeed:$vehicleKey',
    'maxspeed:motor_vehicle',
    'maxspeed',
  ];
  if (tags.keys.any(
    (key) => prefixes.any(
      (p) =>
          key == '$p:conditional' ||
          key == '$p:$direction:conditional' ||
          key == '$p:lanes' ||
          key == '$p:lanes:$direction',
    ),
  ))
    return const SpeedLimit(
      null,
      'unknown',
      reason: 'Hạn tốc theo làn/điều kiện · xem biển',
    );
  String? raw;
  for (final prefix in prefixes) {
    raw = tags['$prefix:$direction'] ?? tags[prefix];
    if (raw != null) break;
  }
  final explicit = parseMaxspeed(raw);
  if (explicit != null)
    return SpeedLimit(explicit, 'osm', reason: 'Dữ liệu đoạn đường OSM');
  if (raw != null && !{'VN:urban', 'VN:rural'}.contains(raw))
    return const SpeedLimit(
      null,
      'unknown',
      reason: 'Hạn tốc OSM chưa diễn giải được',
    );
  if (!estimates ||
      {'service', 'track', 'living_street'}.contains(tags['highway']))
    return const SpeedLimit(null, 'unknown');
  final kind = tags['maxspeed:type'] ?? tags['source:maxspeed'] ?? raw;
  final urban =
      kind == 'VN:urban' ||
      tags['urban'] == 'yes' ||
      kind != 'VN:rural' && tags['urban'] != 'no' && urbanHint;
  final lanes = int.tryParse(
    tags['lanes:motor_vehicle'] ??
        tags['lanes:$direction'] ??
        (match.edge.oneWay != 0 ? tags['lanes'] ?? '' : ''),
  );
  final divided =
      tags['dual_carriageway'] == 'yes' ||
      match.edge.oneWay != 0 && lanes != null && lanes >= 2;
  final value = legalEstimate(
    vehicle,
    urban: urban,
    dividedOrTwoLanesOneWay: divided,
    motorway: {'motorway', 'motorway_link'}.contains(tags['highway']),
  );
  return SpeedLimit(
    value,
    value == null ? 'unknown' : 'estimate',
    estimated: value != null,
    reason: value == null
        ? 'Cao tốc · xem biển thực tế'
        : 'Ước tính loại đường và vùng dân cư · TT38/2024',
  );
}

class RoadEngine {
  final passed = <String>{};
  Set<String> visible = {};
  String? routeKey;
  double? lastHeading;
  int? previousRoad, warningTime;
  int warningCount = 0;
  bool warning = false;
  String? limitKey;
  void reset() {
    passed.clear();
    visible.clear();
    previousRoad = null;
    warning = false;
    warningCount = 0;
    warningTime = null;
    limitKey = null;
  }

  RoadStatus evaluate({
    required NavFix? fix,
    required double heading,
    required bool headingKnown,
    required RoadNearby nearby,
    List<RoadSign> pins = const [],
    NavRoute? route,
    String version = '',
    String vehicle = 'car',
    int tolerance = 5,
    bool estimates = true,
    DateTime? now,
  }) {
    now ??= DateTime.now();
    if (routeKey != version ||
        lastHeading != null && angleDifference(lastHeading!, heading) > 120) {
      reset();
      routeKey = version;
    }
    lastHeading = heading;
    if (fix == null ||
        !fix.usable(now) ||
        fix.accuracy > 30 ||
        !headingKnown ||
        nearby.truncated) {
      warning = false;
      warningCount = 0;
      return const RoadStatus();
    }
    final match = matchRoad(
      nearby.roads,
      fix.point,
      heading,
      previous: previousRoad,
    );
    previousRoad = match?.edge.id;
    final limit = resolveLimit(
      match,
      pins: pins,
      position: fix.point,
      heading: heading,
      urbanHint: nearby.urbanHint,
      vehicle: vehicle,
      estimates: estimates,
    );
    final horizon = (math.max(0, fix.speed) * 20).clamp(300.0, 1500.0);
    RouteProgress? origin;
    NavRoute? window;
    double base = 0;
    if (route != null) {
      origin = projectRoute(route, fix.point);
      final h = course(
        route.points[origin.segment],
        route.points[origin.segment + 1],
      );
      if (origin.distance > 30 || angleDifference(heading, h) >= 60)
        return RoadStatus(limit: limit);
      final start = math.max(0, origin.segment - 1);
      var end = origin.segment + 1;
      while (end < route.points.length - 1 &&
          route.cumulative[end] < origin.along + horizon + 50) {
        end++;
      }
      window = NavRoute(route.points.sublist(start, end + 1), [], 0, 'window');
      base = route.cumulative[start];
    }
    final ahead = <UpcomingSign>[];
    for (final item in [...pins, ...nearby.signs]) {
      if (passed.contains(item.id)) continue;
      if (vehicle != 'car' && item.id.contains(':limit:')) continue;
      if (item.source == 'osm' &&
          item.bearing == null &&
          item.kind != 'calming' &&
          !item.note.contains('hai chiều'))
        continue;
      if (meters(fix.point, item.point) > horizon + 100) continue;
      double delta, travel = heading;
      if (window != null && origin != null) {
        final p = projectRoute(window, item.point);
        if (p.distance > 30) continue;
        delta = base + p.along - origin.along;
        travel = course(window.points[p.segment], window.points[p.segment + 1]);
      } else if (match != null) {
        if (item.way != null && item.way != match.edge.id) continue;
        if (item.way == match.edge.id && item.along != null) {
          delta = (item.along! - match.along) * (match.forward ? 1 : -1);
        } else {
          final p = projectRoute(match.edge.geometry, item.point);
          if (p.distance > 20) continue;
          delta = (p.along - match.progress.along) * (match.forward ? 1 : -1);
        }
        if (item.bearing != null) travel = match.heading;
      } else {
        final d = meters(fix.point, item.point);
        if (d > 2 &&
            angleDifference(course(fix.point, item.point), heading) > 30)
          continue;
        delta = d;
      }
      if (item.bearing != null && angleDifference(item.bearing!, travel) >= 60)
        continue;
      if (delta < -20) {
        passed.add(item.id);
        continue;
      }
      if (delta > horizon + (visible.contains(item.id) ? 20 : 0)) continue;
      ahead.add(UpcomingSign(item, math.max(0, delta)));
    }
    ahead.sort((a, b) => a.distance.compareTo(b.distance));
    final unique = <UpcomingSign>[];
    for (final item in ahead) {
      if (unique.any(
        (x) =>
            x.sign.kind == item.sign.kind &&
            meters(x.sign.point, item.sign.point) < 20,
      ))
        continue;
      unique.add(item);
      if (unique.length == 3) break;
    }
    visible = unique.map((x) => x.sign.id).toSet();
    final key = '${limit.value}:${limit.source}';
    if (key != limitKey) {
      warning = false;
      warningCount = 0;
      limitKey = key;
    }
    if (fix.time.millisecondsSinceEpoch != warningTime) {
      warningTime = fix.time.millisecondsSinceEpoch;
      if (limit.value == null || fix.speed < 0) {
        warning = false;
        warningCount = 0;
      } else {
        final excess = fix.speed * 3.6 - limit.value! - tolerance;
        if (excess > 0) {
          warningCount++;
          if (warningCount >= 2) warning = true;
        } else if (excess <= -2) {
          warning = false;
          warningCount = 0;
        }
      }
    }
    return RoadStatus(limit: limit, upcoming: unique, overspeed: warning);
  }
}
