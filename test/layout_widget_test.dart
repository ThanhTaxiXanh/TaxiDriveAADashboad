import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/core/layout_config.dart';
import 'package:taxi_driver_aa_dashboard/core/dashboard_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/dashboard/dashboard_screen.dart';
import 'package:taxi_driver_aa_dashboard/features/settings/layout_settings.dart';

void main() {
  for (final size in [
    const Size(1280, 720),
    const Size(1920, 720),
    const Size(803, 843),
    const Size(800, 480),
  ]) {
    testWidgets('Two columns and bounded rows at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final config in [
        LayoutConfig(),
        LayoutConfig(
          leftFraction: .75,
          fontScale: 1.6,
          rowWeights: [.1, 10, .1],
        ),
        LayoutConfig(rowEnabled: [false, true, false]),
        LayoutConfig(rowEnabled: [false, false, false]),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: DashboardFrame(config: config)),
          ),
        );
        expect(find.byKey(const ValueKey('map-panel')), findsOneWidget);
        for (var i = 0; i < 3; i++) {
          expect(
            find.byKey(ValueKey('row-$i')),
            config.rowEnabled[i] ? findsOneWidget : findsNothing,
          );
        }
        expect(tester.takeException(), isNull);
      }
    });
  }
  testWidgets('Phone toggle and reset change controller', (tester) async {
    final controller = DashboardController(connected: false);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (_, _) => LayoutSettings(controller: controller),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(controller.config.rowEnabled[0], false);
    final reset = find.text('Đặt lại mặc định');
    await tester.scrollUntilVisible(reset, 400);
    await tester.tap(reset);
    await tester.pump();
    expect(controller.config.rowEnabled, [true, true, true]);
  });
}
