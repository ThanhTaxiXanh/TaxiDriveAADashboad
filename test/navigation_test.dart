import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_models.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/routing_provider.dart';

const points = [
  LatLng(21.281, 106.194),
  LatLng(21.282, 106.194),
  LatLng(21.282, 106.196),
];
Map<String, dynamic> osrmFixture() => {
  'code': 'Ok',
  'routes': [
    {
      'geometry': {
        'coordinates': [
          for (final p in points) [p.longitude, p.latitude],
        ],
      },
      'duration': 100,
      'legs': [
        {
          'steps': [
            {
              'name': 'Đường thử A',
              'maneuver': {
                'type': 'depart',
                'location': [106.194, 21.281],
              },
            },
            {
              'name': 'Đường thử B',
              'maneuver': {
                'type': 'turn',
                'modifier': 'right',
                'location': [106.194, 21.282],
              },
            },
            {
              'name': '',
              'maneuver': {
                'type': 'arrive',
                'location': [106.196, 21.282],
              },
            },
          ],
        },
      ],
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Route projection advances along bends and rejects off-route geometry',
    () {
      final r = NavRoute(points, [const TurnStep(1, 'Rẽ phải')], 100, 'test');
      final halfway = projectRoute(r, const LatLng(21.2815, 106.194));
      expect(halfway.distance, lessThan(1));
      expect(halfway.along, closeTo(55.6, 1));
      final after = projectRoute(
        r,
        const LatLng(21.282, 106.195),
        previous: halfway.along,
      );
      expect(after.segment, 1);
      expect(after.along, greaterThan(halfway.along));
      expect(after.distance, lessThan(1));
      expect(
        projectRoute(r, const LatLng(21.284, 106.2)).distance,
        greaterThan(50),
      );
      expect(NavRoute.fromJson(r.toJson()).length, closeTo(r.length, .01));
    },
  );
  test(
    'Fresh/accurate fixes gate guidance; heading crosses zero by short arc',
    () {
      final now = DateTime.now();
      NavFix fix(int age, double accuracy) => NavFix.fromJson({
        'lat': 21.281,
        'lon': 106.194,
        'accuracy': accuracy,
        'speed': 0,
        'bearing': 0,
        'time': now.subtract(Duration(seconds: age)).millisecondsSinceEpoch,
      });
      expect(fix(2, 10).usable(now), true);
      expect(fix(11, 10).usable(now), false);
      expect(fix(1, 100).usable(now), false);
      expect(smoothBearing(350, 10), closeTo(356, .001));
      expect(() => coordinate(91, 1), throwsFormatException);
      expect(() => decodePolyline6('_'), throwsFormatException);
    },
  );
  test(
    'Valhalla precision-6 shape, vi locale and fallback maneuver wording',
    () {
      const shape = r'om{qg@_dqpiEo}@??_|B';
      expect(decodePolyline6(shape), points);
      Map fixture(String language) => {
        'trip': {
          'status': 0,
          'language': language,
          'summary': {'time': 100},
          'legs': [
            {
              'shape': shape,
              'maneuvers': [
                {
                  'type': 10,
                  'begin_shape_index': 1,
                  'street_names': ['Đường thử'],
                  'instruction': 'Rẽ phải vào Đường thử.',
                },
              ],
            },
          ],
        },
      };
      expect(
        parseValhalla(fixture('vi-VN')).steps.single.text,
        'Rẽ phải vào Đường thử.',
      );
      expect(
        parseValhalla(fixture('en-US')).steps.single.text,
        'Rẽ phải · Đường thử',
      );
    },
  );
  test(
    'OSRM fallback keeps lon/lat order and translates maneuvers to Vietnamese',
    () {
      final route = parseOsrm(osrmFixture());
      expect(route.points, points);
      expect(route.steps[1].index, 1);
      expect(route.steps[1].text, 'Rẽ phải · Đường thử B');
      expect(vietnameseTurn(26, exit: 3), contains('thứ 3'));
      expect(() => parseOsrm({'code': 'NoRoute'}), throwsFormatException);
    },
  );
  test(
    'HTTPS endpoints reject credentials, queries and unsupported schemes',
    () {
      expect(serverUri('https://example.org/route').host, 'example.org');
      for (final value in [
        'http://example.org',
        '***example.org',
        'https://example.org/?key=x',
        'file:///private',
        'https://example.org/#x',
      ]) {
        expect(() => serverUri(value), throwsFormatException);
      }
    },
  );
  test(
    'Both engines share a native route lease; stale GPS makes no network call',
    () async {
      var claims = 0, requests = 0, published = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NavController.methods, (call) async {
            if (call.method == 'claimRoute')
              return claims++ == 0 ? 'lease' : null;
            if (call.method == 'setRoute') {
              published++;
              return null;
            }
            return null;
          });
      final client = MockClient((request) async {
        requests++;
        return http.Response(jsonEncode(osrmFixture()), 200);
      });
      final one = NavController(connected: false, client: client),
          two = NavController(connected: false, client: client);
      // Valhalla parser intentionally rejects OSRM shape; fallback uses the same
      // mock client. There must be only one engine's request pair.
      for (final c in [one, two]) {
        c.goal = const Place('Điểm thử', LatLng(21.282, 106.196));
        c.fix = NavFix.fromJson({
          'lat': 21.281,
          'lon': 106.194,
          'accuracy': 5,
          'speed': 0,
          'bearing': 0,
          'time': DateTime.now().millisecondsSinceEpoch,
        });
      }
      await Future.wait([one.calculate(), two.calculate()]);
      expect(requests, 2);
      expect(published, 1);
      one.fix = NavFix.fromJson({
        'lat': 21.281,
        'lon': 106.194,
        'accuracy': 5,
        'speed': 0,
        'bearing': 0,
        'time': DateTime.now()
            .subtract(const Duration(seconds: 30))
            .millisecondsSinceEpoch,
      });
      await one.calculate();
      expect(requests, 2);
      one.dispose();
      two.dispose();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NavController.methods, null);
    },
  );
  test(
    'Manual coordinates avoid geocoding network and preserve account-free place data',
    () async {
      final nav = NavController(
        connected: false,
        client: MockClient(
          (_) async => throw StateError('Must not request network'),
        ),
      );
      final result = await nav.search('21.281,106.194');
      expect(result.single.point, points.first);
      nav.dispose();
    },
  );
}
