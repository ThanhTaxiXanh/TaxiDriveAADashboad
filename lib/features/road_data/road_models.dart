import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../navigation/nav_models.dart';

const roadKinds = <String, String>{
  'speed': 'Tốc độ tối đa',
  'camera': 'Camera tốc độ',
  'noEntry': 'Cấm đi ngược chiều',
  'noLeft': 'Cấm rẽ trái',
  'noRight': 'Cấm rẽ phải',
  'noUturn': 'Cấm quay đầu',
  'noStraight': 'Cấm đi thẳng',
  'noStop': 'Cấm dừng và đỗ',
  'noPark': 'Cấm đỗ',
  'noCar': 'Cấm ô tô',
  'stop': 'Dừng lại',
  'giveWay': 'Nhường đường',
  'calming': 'Gờ giảm tốc',
};
const vehicleNames = <String, String>{
  'car': 'Ô tô con / xe đến 28 chỗ · VF e34',
  'heavy': 'Xe trên 28 chỗ / tải trên 3,5 tấn',
  'bus': 'Xe buýt / đầu kéo thông thường',
  'towing': 'Kéo rơ moóc / xi téc / trộn bê tông',
  'special': 'Xe máy chuyên dùng / xe gắn máy',
  'quadPassenger': 'Xe chở người bốn bánh có động cơ',
  'quadCargo': 'Xe chở hàng bốn bánh có động cơ',
};

class RoadSign {
  RoadSign({
    required this.id,
    required this.point,
    required this.kind,
    this.value,
    this.bearing,
    this.way,
    this.along,
    this.source = 'user',
    this.note = '',
    this.scope = 300,
  });
  final String id, kind, source, note;
  final LatLng point;
  final int? value, way;
  final double? bearing, along;
  final double scope;
  factory RoadSign.fromJson(Map j) {
    final kind = j['kind'] as String;
    if (!roadKinds.containsKey(kind))
      throw const FormatException('Loại biển chưa hỗ trợ');
    return RoadSign(
      id: j['id'] as String,
      point: coordinate(j['lat'], j['lon']),
      kind: kind,
      value: (j['value'] as num?)?.toInt(),
      bearing: (j['bearing'] as num?)?.toDouble(),
      way: (j['way'] as num?)?.toInt(),
      along: (j['along'] as num?)?.toDouble(),
      source: j['source'] as String? ?? 'user',
      note: j['note'] as String? ?? '',
      scope: (j['scope'] as num? ?? 300).toDouble(),
    );
  }
  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': point.latitude,
    'lon': point.longitude,
    'kind': kind,
    'value': value,
    'bearing': bearing,
    'way': way,
    'along': along,
    'source': source,
    'note': note,
    'scope': scope,
  };
  String get title => '${roadKinds[kind]}${value == null ? '' : ' $value'}';
}

class RoadEdge {
  RoadEdge(this.id, this.geometry, this.tags, {this.offset = 0});
  final int id;
  final NavRoute geometry;
  final Map<String, String> tags;
  final double offset;
  factory RoadEdge.fromJson(Map j) => RoadEdge(
    (j['id'] as num).toInt(),
    NavRoute(
      j['shape'] is String
          ? decodePolyline6(j['shape'] as String)
          : [for (final p in j['points']) coordinate(p[0], p[1])],
      [],
      0,
      'offline',
    ),
    Map<String, String>.from(j['tags'] as Map),
    offset: (j['offset'] as num? ?? 0).toDouble(),
  );
  int get oneWay => tags['oneway'] == '-1'
      ? -1
      : {'yes', 'true', '1'}.contains(tags['oneway']) ||
            tags['junction'] == 'roundabout'
      ? 1
      : 0;
}

class RoadNearby {
  const RoadNearby({
    this.roads = const [],
    this.signs = const [],
    this.urbanHint = false,
    this.truncated = false,
  });
  final List<RoadEdge> roads;
  final List<RoadSign> signs;
  final bool urbanHint, truncated;
  factory RoadNearby.fromJson(Map j) => RoadNearby(
    roads: [for (final r in j['roads'] as List? ?? []) RoadEdge.fromJson(r)],
    signs: [for (final s in j['signs'] as List? ?? []) RoadSign.fromJson(s)],
    urbanHint: j['urbanHint'] == true,
    truncated: j['truncated'] == true,
  );
}

class SpeedLimit {
  const SpeedLimit(
    this.value,
    this.source, {
    this.estimated = false,
    this.reason = '',
  });
  final int? value;
  final String source, reason;
  final bool estimated;
  String get label => estimated
      ? 'ước tính'
      : source == 'user'
      ? 'ghim của anh'
      : source == 'osm'
      ? 'OSM'
      : 'chưa rõ';
}

class UpcomingSign {
  const UpcomingSign(this.sign, this.distance);
  final RoadSign sign;
  final double distance;
}

class RoadStatus {
  const RoadStatus({
    this.limit = const SpeedLimit(null, 'unknown'),
    this.upcoming = const [],
    this.overspeed = false,
  });
  final SpeedLimit limit;
  final List<UpcomingSign> upcoming;
  final bool overspeed;
}

double course(LatLng a, LatLng b) {
  final cosLat = math.cos((a.latitude + b.latitude) / 2 * math.pi / 180);
  return (math.atan2(
                (b.longitude - a.longitude) * cosLat,
                b.latitude - a.latitude,
              ) *
              180 /
              math.pi +
          360) %
      360;
}

double angleDifference(double a, double b) => ((a - b + 540) % 360 - 180).abs();
