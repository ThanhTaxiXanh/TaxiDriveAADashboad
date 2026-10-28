import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/dashboard/spike_screen.dart';

void main() {
  for (final size in [
    const Size(1280, 720),
    const Size(1920, 720),
    const Size(800, 480),
  ]) {
    testWidgets('Vietnamese text and touch counter at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: SpikeScreen(preview: true)),
      );
      expect(
        find.text('Tiếng Việt: Âm lịch · Đường phố · Nguyễn'),
        findsOneWidget,
      );
      await tester.tap(find.text('Chạm thử: 0'));
      await tester.pump();
      expect(find.text('Chạm thử: 1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
