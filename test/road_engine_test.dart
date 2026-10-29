import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_models.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_engine.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_models.dart';

void main() {
  final fixture = RoadNearby.fromJson(
    jsonDecode(File('test/fixtures/roads.generated.json').readAsStringSync())
        as Map,
  );
  final route = NavRoute(
    [
      const LatLng(21.281, 106.194),
      const LatLng(21.291, 106.194),
      const LatLng(21.291, 106.204),
    ],
    [],
    120,
    'fixture',
  );
  final now = DateTime.utc(2026, 10, 29, 12);
  NavFix fix(
    LatLng point, {
    double speed = 15,
    double heading = 0,
    int seconds = 0,
    double accuracy = 5,
  }) => NavFix.fromJson({
    'lat': point.latitude,
    'lon': point.longitude,
    'speed': speed,
    'bearing': heading,
    'time': now.add(Duration(seconds: seconds)).millisecondsSinceEpoch,
    'accuracy': accuracy,
  });
  test('Three speed layers, directional maxspeed and scoped user override', () {
    const p = LatLng(21.285, 106.194);
    final match = matchRoad(fixture.roads, p, 0)!;
    final pin = RoadSign(
      id: 'user_test',
      point: const LatLng(21.284, 106.194),
      kind: 'speed',
      value: 30,
      bearing: 0,
      way: 100,
      along: meters(
        const LatLng(21.281, 106.194),
        const LatLng(21.284, 106.194),
      ),
      scope: 300,
    );
    SpeedLimit resolve(
      MatchedRoad? m,
      List<RoadSign> pins, {
      double heading = 0,
      LatLng position = p,
    }) => resolveLimit(
      m,
      pins: pins,
      position: position,
      heading: heading,
      urbanHint: true,
    );
    expect(resolve(match, [pin]).value, 30);
    expect(resolve(match, [pin]).source, 'user');
    expect(resolve(match, []).value, 60);
    expect(resolve(match, []).estimated, false);
    final reverse = matchRoad(fixture.roads, p, 180)!;
    expect(resolve(reverse, [pin], heading: 180).value, 40);
    const far = LatLng(21.29, 106.194);
    expect(
      resolve(matchRoad(fixture.roads, far, 0), [pin], position: far).value,
      60,
    );
    final untagged = RoadEdge(200, match.edge.geometry, {'highway': 'primary'});
    final estimate = resolve(matchRoad([untagged], p, 0), []);
    expect(estimate.value, 50);
    expect(estimate.estimated, true);
    expect(estimate.label, 'ước tính');
    expect(
      resolve(
        matchRoad(fixture.roads, const LatLng(21.291, 106.201), 90),
        [],
        heading: 90,
        position: const LatLng(21.291, 106.201),
      ).value,
      isNull,
    );
  });
  test('Article 6–9 table; no motorway blanket 120 and no inference from two-way lane count', () {
    for (final entry in {
      'car': (90, 80),
      'heavy': (80, 70),
      'bus': (70, 60),
      'towing': (60, 50),
    }.entries) {
      expect(
        legalEstimate(
          entry.key,
          urban: false,
          dividedOrTwoLanesOneWay: true,
          motorway: false,
        ),
        entry.value.$1,
      );
      expect(
        legalEstimate(
          entry.key,
          urban: false,
          dividedOrTwoLanesOneWay: false,
          motorway: false,
        ),
        entry.value.$2,
      );
      expect(
        legalEstimate(
          entry.key,
          urban: true,
          dividedOrTwoLanesOneWay: true,
          motorway: false,
        ),
        60,
      );
      expect(
        legalEstimate(
          entry.key,
          urban: true,
          dividedOrTwoLanesOneWay: false,
          motorway: false,
        ),
        50,
      );
      expect(
        legalEstimate(
          entry.key,
          urban: false,
          dividedOrTwoLanesOneWay: true,
          motorway: true,
        ),
        isNull,
      );
    }
    for (final e in {
      'special': 40,
      'quadPassenger': 30,
      'quadCargo': 50,
    }.entries) {
      expect(
        legalEstimate(
          e.key,
          urban: true,
          dividedOrTwoLanesOneWay: true,
          motorway: false,
        ),
        e.value,
      );
    }
    final geometry = fixture.roads.first.geometry;
    SpeedLimit evaluate(Map<String, String> tags, {String vehicle = 'car'}) =>
        resolveLimit(
          matchRoad(
            [RoadEdge(200, geometry, tags)],
            const LatLng(21.285, 106.194),
            0,
          ),
          pins: [],
          position: const LatLng(21.285, 106.194),
          heading: 0,
          urbanHint: false,
          vehicle: vehicle,
        );
    expect(evaluate({'highway': 'primary', 'lanes': '4'}).value, 80);
    expect(
      evaluate({'highway': 'primary', 'lanes': '2', 'oneway': 'yes'}).value,
      90,
    );
    expect(
      evaluate({'highway': 'motorway', 'lanes': '3', 'oneway': 'yes'}).value,
      isNull,
    );
    expect(
      evaluate({
        'highway': 'primary',
        'maxspeed': '80',
        'maxspeed:lanes': '60|80',
      }).value,
      isNull,
    );
    expect(
      evaluate({
        'highway': 'primary',
        'maxspeed': '80',
        'maxspeed:bus:conditional': '60 @ (wet)',
      }).value,
      80,
    );
    expect(
      evaluate({
        'highway': 'primary',
        'maxspeed': '80',
        'maxspeed:bus': '60',
      }, vehicle: 'bus').value,
      60,
    );
    expect(parseMaxspeed('30 mph'), 48);
    expect(parseMaxspeed('60;80'), isNull);
    expect(parseMaxspeed('signals'), isNull);
  });
  test('Car estimates distinguish a physical divider from paint and two-way lane counts', () {
    const position = LatLng(21.285, 106.194);
    SpeedLimit evaluate(Map<String, String> tags, {required bool urban}) =>
        resolveLimit(
          matchRoad(
            [
              RoadEdge(200, fixture.roads.first.geometry, {
                'highway': 'primary',
                ...tags,
              }),
            ],
            position,
            0,
          ),
          pins: [],
          position: position,
          heading: 0,
          urbanHint: urban,
        );
    for (final urban in [true, false]) {
      for (final tags in [
        {'dual_carriageway': 'yes'},
        {'divider': 'barrier'},
        {'divider': 'kerb', 'lanes': '2'},
        {'oneway': 'yes', 'lanes:motor_vehicle': '2'},
      ]) {
        final limit = evaluate(tags, urban: urban);
        expect(limit.value, urban ? 60 : 90, reason: '$tags, urban=$urban');
        expect(limit.estimated, true);
        expect(limit.reason, contains(urban ? 'trong khu' : 'ngoài khu'));
      }
      for (final tags in [
        <String, String>{},
        {'lanes': '4', 'lanes:forward': '2', 'lanes:backward': '2'},
        {'divider': 'solid_line', 'lanes': '4'},
        {'divider': 'double_solid_line'},
        {'divider': 'solid_area'},
        {'divider': 'yes'},
        {'oneway': 'yes', 'lanes': '1'},
        {'oneway': 'yes', 'lanes': '2', 'lanes:motor_vehicle': '1'},
      ]) {
        expect(
          evaluate(tags, urban: urban).value,
          urban ? 50 : 80,
          reason: '$tags, urban=$urban',
        );
      }
      final posted = evaluate({
        'divider': 'barrier',
        'maxspeed': '40',
      }, urban: urban);
      expect(posted.value, 40);
      expect(posted.source, 'osm');
      expect(posted.estimated, false);
    }
  });
  test('Applicable vehicle and direction take precedence over broader conditional limits', () {
    const position = LatLng(21.285, 106.194);
    SpeedLimit evaluate(Map<String, String> tags, {double heading = 0}) =>
        resolveLimit(
          matchRoad(
            [
              RoadEdge(200, fixture.roads.first.geometry, {
                'highway': 'primary',
                ...tags,
              }),
            ],
            position,
            heading,
          ),
          pins: [],
          position: position,
          heading: heading,
          urbanHint: true,
        );
    expect(
      evaluate({
        'maxspeed:motorcar': '60',
        'maxspeed:conditional': '40 @ (wet)',
      }).value,
      60,
    );
    expect(
      evaluate({'maxspeed:forward': '60', 'maxspeed:conditional': '40 @ (wet)'})
          .value,
      60,
    );
    expect(
      evaluate({
        'maxspeed': '60',
        'maxspeed:backward:conditional': '40 @ (wet)',
      }).value,
      60,
    );
    expect(
      evaluate({
        'maxspeed': '60',
        'maxspeed:backward:conditional': '40 @ (wet)',
      }, heading: 180).value,
      isNull,
    );
    expect(
      evaluate({
        'maxspeed:motorcar': '60',
        'maxspeed:motorcar:conditional': '40 @ (wet)',
      }).value,
      isNull,
    );
    expect(
      evaluate({
        'maxspeed:motorcar:forward': '60',
        'maxspeed:motorcar:lanes:forward:conditional': '40|60 @ (wet)',
      }).value,
      isNull,
    );
    expect(
      evaluate({
        'maxspeed:motorcar:forward': '60',
        'maxspeed:lanes:forward': '40|60',
      }).value,
      60,
    );
  });
  test('Posted limits change with road segment and the nearest passed pin has bounded scope', () {
    const start = LatLng(21.281, 106.194);
    const boundary = LatLng(21.286, 106.194);
    const end = LatLng(21.291, 106.194);
    final roads = [
      RoadEdge(100, NavRoute([start, boundary], [], 0, 'before'), {
        'highway': 'primary',
        'divider': 'barrier',
        'maxspeed': '60',
        'maxspeed:backward': '50',
      }),
      RoadEdge(200, NavRoute([boundary, end], [], 0, 'after'), {
        'highway': 'primary',
        'divider': 'barrier',
        'maxspeed': '40',
        'maxspeed:backward': '30',
      }),
    ];
    RoadSign pin(
      String id,
      double lat,
      int value, {
      int way = 100,
      double scope = 300,
    }) => RoadSign(
      id: id,
      point: LatLng(lat, 106.194),
      kind: 'speed',
      value: value,
      bearing: 0,
      way: way,
      along: meters(way == 100 ? start : boundary, LatLng(lat, 106.194)),
      scope: scope,
    );
    final pins = [
      pin('user_old', 21.284, 30),
      pin('user_near', 21.2848, 20, scope: 50),
      pin('user_ahead', 21.2858, 10),
      pin('user_other_road', 21.2849, 10, way: 999),
    ];
    SpeedLimit evaluate(
      double lat, {
      double heading = 0,
      bool withPins = false,
    }) {
      final point = LatLng(lat, 106.194);
      return resolveLimit(
        matchRoad(roads, point, heading),
        pins: withPins ? pins : [],
        position: point,
        heading: heading,
        urbanHint: false,
      );
    }

    expect(evaluate(21.285).value, 60);
    expect(evaluate(21.287).value, 40);
    expect(evaluate(21.287, heading: 180).value, 30);
    expect(evaluate(21.285, withPins: true).value, 20);
    expect(evaluate(21.2854, withPins: true).value, 30);
    expect(evaluate(21.285, heading: 180, withPins: true).value, 50);
    expect(evaluate(21.287, withPins: true).value, 40);
    expect(evaluate(21.29, withPins: true).source, 'osm');
  });
  test('GPX replay: along-route distances, turn directions, pass hysteresis and stale GPS', () {
    final engine = RoadEngine();
    final points =
        RegExp(r'<trkpt lat="([^"]+)" lon="([^"]+)">([\s\S]*?)</trkpt>')
            .allMatches(File('test/fixtures/look_ahead.gpx').readAsStringSync())
            .toList();
    final statuses = <RoadStatus>[];
    for (var i = 0; i < points.length; i++) {
      final sample = points[i], body = sample[3]!;
      final speed = double.parse(
        RegExp(r'<speed>([^<]+)</speed>').firstMatch(body)![1]!,
      );
      final heading = double.parse(
        RegExp(r'<bearing>([^<]+)</bearing>').firstMatch(body)![1]!,
      );
      final position = LatLng(
        double.parse(sample[1]!),
        double.parse(sample[2]!),
      );
      final result = engine.evaluate(
        fix: fix(position, speed: speed, heading: heading, seconds: i),
        heading: heading,
        headingKnown: true,
        nearby: fixture,
        route: route,
        version: 'route1',
        now: now.add(Duration(seconds: i)),
      );
      statuses.add(result);
      expect(result.upcoming.length, lessThanOrEqualTo(3));
      expect(
        result.upcoming.any((x) => x.sign.kind == 'noLeft'),
        false,
        reason: 'Opposite-direction sign must never appear',
      );
      for (var j = 1; j < result.upcoming.length; j++) {
        expect(
          result.upcoming[j].distance,
          greaterThanOrEqualTo(result.upcoming[j - 1].distance),
        );
      }
    }
    expect(
      statuses[0].upcoming.first.distance,
      closeTo(
        meters(const LatLng(21.282, 106.194), const LatLng(21.286, 106.194)),
        1,
      ),
    );
    expect(statuses[2].upcoming.any((x) => x.sign.kind == 'speed'), true);
    expect(statuses[3].upcoming.any((x) => x.sign.id.startsWith('n2:')), false);
    expect(
      statuses[4].upcoming.map((x) => x.sign.kind),
      containsAll(['stop', 'noRight']),
    );
    expect(statuses[0].overspeed, false);
    expect(statuses[1].overspeed, true);
    final stale = engine.evaluate(
      fix: fix(const LatLng(21.285, 106.194)),
      heading: 0,
      headingKnown: true,
      nearby: fixture,
      route: route,
      now: now.add(const Duration(seconds: 12)),
    );
    expect(stale.upcoming, isEmpty);
    expect(stale.overspeed, false);
    expect(stale.limit.value, isNull);
    final weak = engine.evaluate(
      fix: fix(const LatLng(21.285, 106.194), accuracy: 40),
      heading: 0,
      headingKnown: true,
      nearby: fixture,
      now: now,
    );
    expect(weak.limit.value, isNull);
    final other = RoadEngine();
    other.evaluate(
      fix: fix(const LatLng(21.2864, 106.194)),
      heading: 0,
      headingKnown: true,
      nearby: fixture,
      route: route,
      now: now,
    );
    final jitter = other.evaluate(
      fix: fix(const LatLng(21.28599, 106.194)),
      heading: 0,
      headingKnown: true,
      nearby: fixture,
      route: route,
      now: now,
    );
    expect(jitter.upcoming.any((x) => x.sign.id.startsWith('n2:')), false);
  });
  test('Free cone keeps pass hysteresis and rearms after a gradual U-turn', () {
    final engine = RoadEngine();
    final pins = [
      RoadSign(
        id: 'user_both',
        point: const LatLng(21.282, 106.194),
        kind: 'camera',
      ),
    ];
    RoadStatus sample(double lat, double heading) => engine.evaluate(
      fix: fix(LatLng(lat, 106.194), heading: heading),
      heading: heading,
      headingKnown: true,
      nearby: const RoadNearby(),
      pins: pins,
      now: now,
    );
    expect(sample(21.281, 0).upcoming, hasLength(1));
    expect(sample(21.2823, 0).upcoming, isEmpty);
    expect(sample(21.28199, 0).upcoming, isEmpty);
    for (final heading in [54.0, 92.0, 118.0, 137.0]) {
      sample(21.283, heading);
    }
    expect(sample(21.283, 170).upcoming, hasLength(1));
  });
  test('Free driving excludes oncoming road and ambiguous parallel roads', () {
    final straight = fixture.roads.first;
    final oneWay = RoadEdge(100, straight.geometry, {
      ...straight.tags,
      'oneway': 'yes',
    });
    expect(matchRoad([oneWay], const LatLng(21.285, 106.194), 180), isNull);
    final parallel = RoadEdge(
      200,
      NavRoute(
        [const LatLng(21.281, 106.19408), const LatLng(21.291, 106.19408)],
        [],
        0,
        'parallel',
      ),
      {'highway': 'primary', 'maxspeed': '80'},
    );
    expect(
      matchRoad([straight, parallel], const LatLng(21.285, 106.19404), 0),
      isNull,
    );
    final result = RoadEngine().evaluate(
      fix: fix(const LatLng(21.285, 106.194)),
      heading: 0,
      headingKnown: true,
      nearby: fixture,
      now: now,
    );
    expect(result.upcoming.any((x) => x.sign.bearing == 180), false);
    expect(result.upcoming.any((x) => x.sign.id.startsWith('n2:')), true);
    final conePins = [
      RoadSign(
        id: 'user_front',
        point: const LatLng(21.282, 106.194),
        kind: 'camera',
        bearing: 0,
      ),
      RoadSign(
        id: 'user_behind',
        point: const LatLng(21.28, 106.194),
        kind: 'camera',
        bearing: 0,
      ),
      RoadSign(
        id: 'user_side',
        point: const LatLng(21.282, 106.196),
        kind: 'camera',
        bearing: 0,
      ),
    ];
    final cone = RoadEngine().evaluate(
      fix: fix(const LatLng(21.281, 106.194)),
      heading: 0,
      headingKnown: true,
      nearby: const RoadNearby(),
      pins: conePins,
      now: now,
    );
    expect(cone.upcoming.map((x) => x.sign.id), ['user_front']);
  });
}
