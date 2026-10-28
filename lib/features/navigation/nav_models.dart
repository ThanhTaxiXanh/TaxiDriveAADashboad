import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

LatLng coordinate(num lat, num lon) {
  if (!lat.isFinite || !lon.isFinite || lat.abs() > 90 || lon.abs() > 180)
    throw const FormatException('Tọa độ không hợp lệ');
  return LatLng(lat.toDouble(), lon.toDouble());
}

class Place {
  const Place(this.name, this.point, {this.favorite = false});
  final String name;
  final LatLng point;
  final bool favorite;
  String get id =>
      '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': point.latitude,
    'lon': point.longitude,
    'favorite': favorite,
  };
  factory Place.fromJson(Map j) => Place(
    (j['name'] as String).substring(
      0,
      math.min(150, (j['name'] as String).length),
    ),
    coordinate(j['lat'], j['lon']),
    favorite: j['favorite'] == true,
  );
}

class NavFix {
  NavFix.fromJson(Map j)
    : point = coordinate(j['lat'], j['lon']),
      accuracy = (j['accuracy'] as num).toDouble(),
      speed = (j['speed'] as num).toDouble(),
      bearing = (j['bearing'] as num).toDouble(),
      time = DateTime.fromMillisecondsSinceEpoch(j['time'] as int);
  final LatLng point;
  final double accuracy, speed, bearing;
  final DateTime time;
  bool fresh(DateTime now) =>
      now.difference(time).inSeconds >= -2 &&
      now.difference(time).inSeconds <= 10;
  bool usable(DateTime now) =>
      fresh(now) && accuracy.isFinite && accuracy >= 0 && accuracy <= 50;
}

class TurnStep {
  const TurnStep(this.index, this.text);
  final int index;
  final String text;
  Map<String, dynamic> toJson() => {'index': index, 'text': text};
}

class NavRoute {
  NavRoute(this.points, this.steps, this.seconds, this.provider) {
    if (points.length < 2 ||
        points.length > 100000 ||
        !seconds.isFinite ||
        seconds < 0)
      throw const FormatException('Tuyến không hợp lệ');
    cumulative = [0];
    for (var i = 1; i < points.length; i++) {
      cumulative.add(cumulative.last + meters(points[i - 1], points[i]));
    }
    if (steps.any(
      (s) => s.index < 0 || s.index >= points.length || s.text.length > 500,
    ))
      throw const FormatException('Chỉ dẫn không hợp lệ');
  }
  final List<LatLng> points;
  final List<TurnStep> steps;
  final double seconds;
  final String provider;
  late final List<double> cumulative;
  double get length => cumulative.last;
  Map<String, dynamic> toJson() => {
    'points': [
      for (final p in points) [p.latitude, p.longitude],
    ],
    'steps': [for (final s in steps) s.toJson()],
    'seconds': seconds,
    'provider': provider,
  };
  factory NavRoute.fromJson(Map j) => NavRoute(
    [for (final p in j['points']) coordinate(p[0], p[1])],
    [
      for (final s in j['steps'])
        TurnStep(s['index'] as int, s['text'] as String),
    ],
    (j['seconds'] as num).toDouble(),
    j['provider'] as String,
  );
}

double meters(LatLng a, LatLng b) =>
    const Distance().as(LengthUnit.Meter, a, b);

class RouteProgress {
  const RouteProgress(this.along, this.distance, this.segment);
  final double along, distance;
  final int segment;
}

RouteProgress projectRoute(NavRoute route, LatLng point, {double? previous}) {
  var best = const RouteProgress(0, double.infinity, 0);
  var score = double.infinity;
  final cosLat = math.cos(point.latitude * math.pi / 180);
  const factor = 111195.0;
  for (var i = 0; i < route.points.length - 1; i++) {
    final a = route.points[i], b = route.points[i + 1];
    final ax = (a.longitude - point.longitude) * factor * cosLat;
    final ay = (a.latitude - point.latitude) * factor;
    final dx = (b.longitude - a.longitude) * factor * cosLat;
    final dy = (b.latitude - a.latitude) * factor;
    final denominator = dx * dx + dy * dy;
    final t = denominator == 0
        ? 0.0
        : (-(ax * dx + ay * dy) / denominator).clamp(0.0, 1.0);
    final distance = math.sqrt(
      math.pow(ax + dx * t, 2) + math.pow(ay + dy * t, 2),
    );
    final along =
        route.cumulative[i] +
        t * (route.cumulative[i + 1] - route.cumulative[i]);
    // At repeated crossings prefer progress near the last fix, without masking
    // a genuinely closer segment after a GPS recovery.
    final penalty = previous == null
        ? 0.0
        : math.min(30.0, (along - previous).abs() * .015);
    if (distance + penalty < score) {
      score = distance + penalty;
      best = RouteProgress(along, distance, i);
    }
  }
  return best;
}

double smoothBearing(double previous, double next) =>
    (previous + ((next - previous + 540) % 360 - 180) * .3 + 360) % 360;
List<LatLng> decodePolyline6(String value) {
  if (value.length > 2000000) throw const FormatException('Tuyến quá lớn');
  var index = 0, lat = 0, lon = 0;
  int component() {
    var result = 0, shift = 0;
    while (true) {
      if (index >= value.length || shift > 30)
        throw const FormatException('Polyline bị cắt');
      final b = value.codeUnitAt(index++) - 63;
      if (b < 0 || b > 63) throw const FormatException('Polyline sai');
      result |= (b & 31) << shift;
      if (b < 32) break;
      shift += 5;
    }
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  final points = <LatLng>[];
  while (index < value.length) {
    lat += component();
    lon += component();
    points.add(coordinate(lat / 1e6, lon / 1e6));
  }
  return points;
}

String vietnameseTurn(int type, {String road = '', int exit = 0}) {
  final action = switch (type) {
    1 || 2 || 3 => 'Bắt đầu đi',
    4 || 5 || 6 => 'Đến nơi',
    9 => 'Chếch phải',
    10 => 'Rẽ phải',
    11 => 'Rẽ ngoặt phải',
    12 || 13 => 'Quay đầu',
    14 => 'Rẽ ngoặt trái',
    15 => 'Rẽ trái',
    16 => 'Chếch trái',
    18 => 'Vào nhánh bên phải',
    19 => 'Vào nhánh bên trái',
    20 => 'Ra lối bên phải',
    21 => 'Ra lối bên trái',
    23 => 'Giữ bên phải',
    24 => 'Giữ bên trái',
    25 || 37 || 38 => 'Nhập làn',
    26 => exit > 0 ? 'Vào vòng xuyến, ra lối thứ $exit' : 'Vào vòng xuyến',
    27 => 'Ra khỏi vòng xuyến',
    28 => 'Lên phà',
    29 => 'Rời phà',
    _ => 'Đi thẳng',
  };
  return road.isEmpty || [4, 5, 6].contains(type) ? action : '$action · $road';
}
