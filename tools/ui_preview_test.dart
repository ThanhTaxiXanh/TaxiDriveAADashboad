import 'dart:convert';
import 'dart:io';
import 'package:taxi_driver_aa_dashboard/features/payment/payment_config.dart';
import 'package:taxi_driver_aa_dashboard/features/payment/payment_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/payment/qr_codec.dart';
import 'package:taxi_driver_aa_dashboard/features/payment/vietqr.dart';
import 'package:flutter/material.dart';
import 'package:taxi_driver_aa_dashboard/features/calendar/calendar_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/calendar/event_item.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/core/layout_config.dart';
import 'package:taxi_driver_aa_dashboard/core/dashboard_theme.dart';
import 'package:taxi_driver_aa_dashboard/features/dashboard/dashboard_screen.dart';

void main() {
  late List<EventItem> events;
  late Directory temp;
  late PaymentConfig payment;
  setUpAll(() async {
    final loader = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await loader.load();
    events = EventArchive.fromJson(
      jsonDecode(await rootBundle.loadString('assets/events_vn.json')),
    ).events;
  });
  tearDownAll(() async => temp.delete(recursive: true));
  testWidgets('Prepare offline QR sample', (tester) async {
    await tester.runAsync(() async {
      temp = await Directory.systemTemp.createTemp('taxi-qr-preview-');
      final payload = const VietQr(
        bin: '970436',
        account: '0000000000',
        amount: '10000',
        note: 'MA THU KHONG CHUYEN TIEN',
      ).build();
      final path = '${temp.path}/sample.png';
      await File(
        path,
      ).writeAsBytes(await renderPaymentQr(payload, verify: false));
      payment = PaymentConfig(
        mode: 'generated',
        bankName: 'MẪU THỬ',
        account: '0000000000',
        holder: 'KHONG CHUYEN TIEN',
        payload: payload,
        renderedPath: path,
      );
    });
  });
  for (final size in [
    const Size(1280, 720),
    const Size(1920, 720),
    const Size(803, 843),
  ]) {
    for (var variant = 0; variant < 3; variant++) {
      testWidgets('Preview ${size.width} $variant', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final config = variant == 0
            ? LayoutConfig()
            : variant == 1
            ? LayoutConfig(rowWeights: [2, 1, 1], leftFraction: .45)
            : LayoutConfig(
                fontScale: 1.6,
                leftFraction: .75,
                rowWeights: [.1, 10, .1],
              );
        await tester.pumpWidget(
          MaterialApp(
            theme: dashboardTheme(Brightness.dark),
            home: Scaffold(
              body: DashboardFrame(
                key: const ValueKey('preview'),
                config: config,
                today: DateTime.utc(2026, 10, 28),
                events: events,
                payment: payment,
              ),
            ),
          ),
        );
        await tester.runAsync(() async {
          await precacheImage(
            FileImage(File(payment.renderedPath)),
            tester.element(find.byType(DashboardFrame)),
          );
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('preview')),
          matchesGoldenFile(
            '../build/previews/dashboard-${size.width.toInt()}x${size.height.toInt()}-$variant.png',
          ),
        );
      });
    }
  }
  testWidgets('Expanded QR sample', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: dashboardTheme(Brightness.dark),
        home: Scaffold(
          body: PaymentPanel(
            key: const ValueKey('qr-preview'),
            config: payment,
            expanded: true,
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await precacheImage(
        FileImage(File(payment.renderedPath)),
        tester.element(find.byType(PaymentPanel)),
      );
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('qr-preview')),
      matchesGoldenFile('../build/previews/qr-expanded-sample.png'),
    );
  });
  for (var page = 0; page < 3; page++) {
    testWidgets('Calendar full page $page', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dashboardTheme(Brightness.dark),
          home: Scaffold(
            body: CalendarPanel(
              key: const ValueKey('calendar-preview'),
              today: DateTime.utc(2026, 10, 28),
              events: events,
              expanded: true,
              initialPage: page,
              onCollapse: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('calendar-preview')),
        matchesGoldenFile('../build/previews/calendar-page-$page.png'),
      );
    });
  }
}
