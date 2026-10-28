import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/vehicle_marker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/map_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_models.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets(
    'Recenter works after browsing with stale GPS and no active route',
    (tester) async {
      final oldFix = {
        'lat': 21.281,
        'lon': 106.194,
        'accuracy': 80,
        'speed': 0,
        'bearing': 0,
        'time': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      };
      final nav = NavController(connected: false)..revision = 0;
      nav.fix = NavFix.fromJson(oldFix);
      addTearDown(nav.dispose);
      var refreshes = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NavController.location, (call) async {
            refreshes++;
            return null;
          });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            NavController.methods,
            (call) async => call.method == 'snapshot'
                ? jsonEncode({
                    'routeRevision': 0,
                    'running': true,
                    'fix': oldFix,
                  })
                : null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(NavController.location, null);
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(NavController.methods, null);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MapPanel(navigation: nav, loadNetwork: false)),
        ),
      );
      await tester.pump();
      expect(find.byType(VehicleMarker), findsOneWidget);
      expect(
        tester.widget<VehicleMarker>(find.byType(VehicleMarker)).fresh,
        false,
      );
      expect(nav.active, false);
      final camera = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      await tester.tap(find.byTooltip('Phóng to bản đồ'));
      camera.move(const LatLng(21.3, 106.3), 13);
      await tester.pump();
      expect(camera.camera.center.longitude, closeTo(106.3, .00001));
      await tester.tap(find.byTooltip('Theo xe'));
      await tester.pump();
      expect(camera.camera.center.latitude, closeTo(21.281, .00001));
      expect(camera.camera.center.longitude, closeTo(106.194, .00001));
      expect(refreshes, 1);
      expect(
        nav.precise,
        false,
      ); // Camera recovery does not enable stale guidance.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final size in [
    const Size(194, 464),
    const Size(450, 720),
    const Size(600, 843),
  ]) {
    testWidgets('Map controls/attribution fit narrow car column $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nav = NavController(connected: false);
      nav.route = NavRoute(
        [const LatLng(21.281, 106.194), const LatLng(21.282, 106.196)],
        [const TurnStep(1, 'Rẽ phải')],
        60,
        'fixture',
      );
      addTearDown(nav.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MapPanel(navigation: nav, car: true, loadNetwork: false),
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('OpenStreetMap'), findsOneWidget);
      expect(find.byTooltip('Phóng to bản đồ'), findsOneWidget);
      await tester.tap(find.byTooltip('Phóng to bản đồ'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
