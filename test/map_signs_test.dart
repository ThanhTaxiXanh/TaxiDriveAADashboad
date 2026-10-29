import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/map_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/map_road_sign.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_models.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_models.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/sign_painter.dart';

void main() {
  RoadSign sign(String id, String kind, {double longitude = 106.194}) =>
      RoadSign(
        id: id,
        kind: kind,
        value: kind == 'speed' ? 60 : null,
        point: LatLng(21.281, longitude),
        source: 'osm',
      );

  testWidgets('GPU frame overlay shows actual signs, culls and caps widgets', (
    tester,
  ) async {
    final signs = [
      sign('speed', 'speed'),
      sign('noLeft', 'noLeft', longitude: 106.195),
      sign('offscreen', 'noEntry', longitude: 108),
    ];
    Offset project(LatLng point) =>
        Offset(120 + (point.longitude - 106.194) * 100000, 120);
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 300,
          child: MapSignOverlay(
            signs: signs,
            viewport: const Size(400, 300),
            project: project,
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('road-sign-speed')), findsOneWidget);
    expect(find.byKey(const ValueKey('road-sign-noLeft')), findsOneWidget);
    expect(find.byKey(const ValueKey('road-sign-offscreen')), findsNothing);
    expect(find.byType(SignIcon), findsNWidgets(2));
    final icon = tester.widget<SignIcon>(
      find.descendant(
        of: find.byKey(const ValueKey('road-sign-speed')),
        matching: find.byType(SignIcon),
      ),
    );
    expect(icon.kind, 'speed');
    expect(icon.value, 60);
    expect(icon.estimated, false);
    final marker = tester.widget<MapRoadSign>(find.byType(MapRoadSign).first);
    expect(marker.onTap, isNull); // Car overlays pass map gestures through.
    await tester.pumpWidget(
      MaterialApp(
        home: MapSignOverlay(
          signs: [for (var i = 0; i < 200; i++) sign('node$i', 'noEntry')],
          viewport: const Size(400, 300),
          project: (_) => const Offset(120, 120),
        ),
      ),
    );
    expect(find.byType(MapRoadSign), findsOneWidget);
    expect(find.text('+199'), findsOneWidget);
    final group = tester.widget<MapRoadSignGroup>(
      find.byType(MapRoadSignGroup),
    );
    expect(group.group.signs, hasLength(200));
    expect(group.group.width, lessThanOrEqualTo(192));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final gpu in [false, true]) {
    testWidgets('Colocated ${gpu ? 'GPU' : '2D'} signs use a bounded group', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(194, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final signs = [
        for (final kind in roadKinds.keys) sign('dense-$kind', kind),
      ];
      final nav = NavController(connected: false);
      addTearDown(nav.dispose);
      nav.road.nearby = RoadNearby(signs: signs);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: gpu
                ? MapSignOverlay(
                    signs: signs,
                    viewport: const Size(194, 600),
                    project: (_) => const Offset(192, 4),
                    onTap: (_) {},
                  )
                : MapPanel(navigation: nav, loadNetwork: false),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MapRoadSignGroup), findsOneWidget);
      expect(find.byType(MapRoadSign), findsNWidgets(3));
      expect(find.text('+10'), findsOneWidget);
      final group = tester.widget<MapRoadSignGroup>(
        find.byType(MapRoadSignGroup),
      );
      expect(group.group.signs, hasLength(13));
      expect(tester.getSize(find.byType(MapRoadSignGroup)).width, 192);
      if (gpu) {
        final rectangle = tester.getRect(find.byType(MapRoadSignGroup));
        expect(rectangle.left, greaterThanOrEqualTo(0));
        expect(rectangle.right, lessThanOrEqualTo(194));
        await tester.tap(find.text('+10'));
        await tester.pumpAndSettle();
        expect(find.text('13 bản ghi tại vị trí này'), findsOneWidget);
        final list = tester.widget<ListView>(find.byType(ListView));
        expect(list.childrenDelegate.estimatedChildCount, 13);
        expect(find.text('Lưu ghim'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('Inferred rule points are distinct from physical sign records', (
    tester,
  ) async {
    final inferred = RoadSign(
      id: 'w1',
      kind: 'speed',
      value: 80,
      point: const LatLng(21.281, 106.194),
      source: 'osm',
      note: 'Đầu đoạn OSM · không xác nhận vị trí biển',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: MapRoadSign(sign: inferred)),
      ),
    );
    expect(find.text('Đoạn'), findsOneWidget);
    expect(tester.widget<SignIcon>(find.byType(SignIcon)).estimated, true);
    expect(isInferredMapSign(sign('n1', 'speed')), false);
    final both = RoadSign(
      id: 'both',
      kind: 'noPark',
      point: inferred.point,
      source: 'osm',
      note: 'OSM · hai chiều',
    );
    expect(mapSignDirection(both), contains('hai chiều'));
    expect(mapSignDirection(both), isNot(contains('chưa xác định')));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    '2D shows nearby OSM signs without heading or active navigation',
    (tester) async {
      final nav = NavController(connected: false);
      addTearDown(nav.dispose);
      nav.fix = NavFix.fromJson({
        'lat': 21.281,
        'lon': 106.194,
        'accuracy': 5,
        'speed': 0,
        'bearing': 0,
        'time': DateTime.now().millisecondsSinceEpoch,
      });
      final signs = [
        sign('n1', 'speed', longitude: 106.1928),
        sign('n2', 'noLeft', longitude: 106.195),
      ];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(RoadController.methods, (call) async {
            if (call.method == 'nearby')
              return jsonEncode({
                'signs': signs.map((s) => s.toJson()).toList(),
              });
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(RoadController.methods, null),
      );
      nav.road.update(fix: nav.fix, heading: 0, headingKnown: false);
      await nav.road.query();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MapPanel(navigation: nav, loadNetwork: false)),
        ),
      );
      await tester.pump();
      expect(nav.hasHeading, false);
      expect(nav.active, false);
      expect(nav.road.status.upcoming, isEmpty);
      expect(find.byKey(const ValueKey('road-sign-n1')), findsOneWidget);
      expect(find.byKey(const ValueKey('road-sign-n2')), findsOneWidget);
      final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
      expect(map.children.whereType<MarkerLayer>(), isNotEmpty);
      await tester.tap(find.byKey(const ValueKey('road-sign-n1')));
      await tester.pumpAndSettle();
      expect(find.text('Nguồn: OpenStreetMap'), findsOneWidget);
      expect(
        find.textContaining('chưa xác định hướng áp dụng'),
        findsOneWidget,
      );
      expect(find.text('Lưu ghim'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
