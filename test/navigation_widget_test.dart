import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/map_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_models.dart';
import 'package:latlong2/latlong.dart';

void main() {
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
