import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'nav_models.dart';

const navUserAgent =
    'TaxiXanhAADashboard/0.4 (https://github.com/ThanhTaxiXanh/TaxiDriveAADashboad)';
Uri serverUri(String value) {
  final u = Uri.parse(value.trim());
  if (u.scheme != 'https' ||
      u.host.isEmpty ||
      u.userInfo.isNotEmpty ||
      u.hasQuery ||
      u.hasFragment)
    throw const FormatException(
      'Địa chỉ máy chủ phải là HTTPS, không chứa khóa/mật khẩu',
    );
  return u;
}

Future<Map<String, dynamic>> getJson(http.Client client, Uri uri) async {
  final abort = Completer<void>();
  final timer = Timer(const Duration(seconds: 12), () {
    if (!abort.isCompleted) abort.complete();
  });
  try {
    return await (() async {
      final request = http.AbortableRequest(
        'GET',
        uri,
        abortTrigger: abort.future,
      )..headers['User-Agent'] = navUserAgent;
      final response = await client.send(request);
      if (response.statusCode != 200)
        throw const FormatException('Máy chủ chưa trả được dữ liệu');
      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        if (bytes.length > 4 * 1024 * 1024)
          throw const FormatException('Dữ liệu tuyến quá lớn');
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    })().timeout(const Duration(seconds: 12));
  } finally {
    timer.cancel();
    if (!abort.isCompleted) abort.complete();
  }
}

abstract interface class RoutingProvider {
  Future<NavRoute> route(LatLng origin, LatLng destination);
}

class ValhallaRouting implements RoutingProvider {
  ValhallaRouting(this.client, this.base);
  final http.Client client;
  final String base;
  @override
  Future<NavRoute> route(LatLng origin, LatLng destination) async {
    final uri = serverUri(base).replace(
      queryParameters: {
        'json': jsonEncode({
          'locations': [
            {'lat': origin.latitude, 'lon': origin.longitude},
            {'lat': destination.latitude, 'lon': destination.longitude},
          ],
          'costing': 'auto',
          'units': 'kilometers',
          'language': 'vi-VN',
          'shape_format': 'polyline6',
        }),
      },
    );
    return parseValhalla(await getJson(client, uri));
  }
}

NavRoute parseValhalla(Map json) {
  final trip = json['trip'] as Map;
  if (trip['status'] != 0 || (trip['legs'] as List).length != 1)
    throw const FormatException('Không tìm được tuyến ô tô');
  final leg = trip['legs'][0] as Map;
  final points = decodePolyline6(leg['shape'] as String);
  final vi = trip['language'] == 'vi-VN';
  final steps = <TurnStep>[];
  for (final raw in leg['maneuvers'] as List) {
    final road = ((raw['street_names'] ?? []) as List).join(', ');
    final local = vietnameseTurn(
      raw['type'] as int,
      road: road,
      exit: raw['roundabout_exit_count'] as int? ?? 0,
    );
    final instruction =
        vi &&
            raw['instruction'] is String &&
            (raw['instruction'] as String).isNotEmpty
        ? raw['instruction'] as String
        : local;
    steps.add(TurnStep(raw['begin_shape_index'] as int, instruction));
  }
  return NavRoute(
    points,
    steps,
    (trip['summary']['time'] as num).toDouble(),
    'Valhalla',
  );
}

class OsrmRouting implements RoutingProvider {
  OsrmRouting(this.client, this.base);
  final http.Client client;
  final String base;
  @override
  Future<NavRoute> route(LatLng origin, LatLng destination) async {
    final server = serverUri(base);
    final path =
        '${server.path.replaceAll(RegExp(r'/$'), '')}/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}';
    final json = await getJson(
      client,
      server.replace(
        path: path,
        queryParameters: {
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'true',
        },
      ),
    );
    return parseOsrm(json);
  }
}

NavRoute parseOsrm(Map json) {
  if (json['code'] != 'Ok')
    throw const FormatException('Không tìm được tuyến ô tô');
  final r = (json['routes'] as List).first as Map;
  final points = [
    for (final p in r['geometry']['coordinates']) coordinate(p[1], p[0]),
  ];
  if (points.length < 2) throw const FormatException('Tuyến rỗng');
  final steps = <TurnStep>[];
  var minimum = 0;
  for (final leg in r['legs']) {
    for (final s in leg['steps']) {
      final m = s['maneuver'] as Map;
      final p = coordinate(m['location'][1], m['location'][0]);
      var nearest = minimum;
      var best = double.infinity;
      for (var i = minimum; i < points.length; i++) {
        final d = meters(p, points[i]);
        if (d < best) {
          best = d;
          nearest = i;
        }
      }
      minimum = nearest;
      final modifier = m['modifier'] as String? ?? '';
      final type = switch (m['type']) {
        'depart' => 1,
        'arrive' => 4,
        'roundabout' || 'rotary' => 26,
        'exit roundabout' || 'exit rotary' => 27,
        'merge' => 25,
        _ => switch (modifier) {
          'right' => 10,
          'left' => 15,
          'slight right' => 9,
          'slight left' => 16,
          'sharp right' => 11,
          'sharp left' => 14,
          'uturn' => 13,
          _ => 8,
        },
      };
      steps.add(
        TurnStep(
          nearest,
          vietnameseTurn(
            type,
            road: s['name'] as String? ?? '',
            exit: m['exit'] as int? ?? 0,
          ),
        ),
      );
    }
  }
  return NavRoute(points, steps, (r['duration'] as num).toDouble(), 'OSRM');
}
