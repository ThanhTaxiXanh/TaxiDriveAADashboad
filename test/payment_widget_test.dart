import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/core/layout_config.dart';
import 'package:taxi_driver_aa_dashboard/features/dashboard/dashboard_screen.dart';
import 'package:taxi_driver_aa_dashboard/features/payment/payment_config.dart';

void main() {
  testWidgets('QR expands only right column, closes on tap and after ten seconds', (tester) async {
    tester.view.physicalSize = const Size(803, 843);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardFrame(config: LayoutConfig(leftFraction: .75, fontScale: 1.6)))));
    final mapBefore = tester.getRect(find.byKey(const ValueKey('map-panel')));
    await tester.tap(find.byKey(const ValueKey('payment-panel'))); await tester.pump();
    expect(find.byKey(const ValueKey('row-0')), findsNothing);
    expect(tester.getRect(find.byKey(const ValueKey('map-panel'))), mapBefore);
    await tester.pump(const Duration(seconds: 9));
    expect(find.byKey(const ValueKey('row-0')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('row-0')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('payment-panel'))); await tester.pump();
    await tester.tap(find.byKey(const ValueKey('payment-panel'))); await tester.pump();
    expect(find.byKey(const ValueKey('row-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Disabling QR cancels expansion and its timer', (tester) async {
    final key = GlobalKey();
    Widget frame(LayoutConfig config) => MaterialApp(home: Scaffold(body: DashboardFrame(key: key, config: config)));
    await tester.pumpWidget(frame(LayoutConfig()));
    await tester.tap(find.byKey(const ValueKey('payment-panel'))); await tester.pump();
    await tester.pumpWidget(frame(LayoutConfig(rowEnabled: [true, false, true])));
    expect(find.byKey(const ValueKey('payment-panel')), findsNothing);
    expect(find.byKey(const ValueKey('row-0')), findsOneWidget);
    await tester.pump(const Duration(seconds: 11));
    expect(tester.takeException(), isNull);
  });
  test('Payment config retains mode, privacy option and immutable image paths', () {
    const c = PaymentConfig(mode: 'generated', bin: '970436', account: '000123', holder: 'TEST USER', hideAccount: true, renderedPath: '/private/generated.png', centerPath: '/private/center.png');
    final copy = PaymentConfig.fromJson(c.toJson());
    expect(copy.toJson(), c.toJson()); expect(copy.displayPath, c.renderedPath);
    expect(const PaymentConfig().displayPath, isEmpty);
  });
}
