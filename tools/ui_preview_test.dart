import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:latlong2/latlong.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/sign_painter.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_models.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_widgets.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/map_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_models.dart';
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
  Future<void> preload(WidgetTester tester) async {
    // Load FileImage in the real async zone before any widget creates a
    // pending ImageCache entry in the fake test clock's zone.
    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.runAsync(() async {
      for (final path in [payment.renderedPath, payment.brandPath]) {
        await precacheImage(
          FileImage(File(path)),
          tester.element(find.byType(Scaffold)),
        );
      }
    });
  }

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
      await File(path)
          .writeAsBytes(await renderPaymentQr(payload, verify: false));
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 10, 1200, 200),
          const Radius.circular(30),
        ),
        Paint()..color = const Color(0xff006b55),
      );
      final painter = TextPainter(
        text: const TextSpan(
          text: 'TAXI XANH · LOGO MẪU',
          style: TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 64,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, const Offset(130, 60));
      final picture = recorder.endRecording();
      final logo = await picture.toImage(1200, 240);
      final data = (await logo.toByteData(format: ui.ImageByteFormat.png))!;
      final logoPath = '${temp.path}/brand.png';
      await File(logoPath).writeAsBytes(data.buffer.asUint8List());
      logo.dispose();
      picture.dispose();
      payment = PaymentConfig(
        mode: 'generated',
        bankName: 'MẪU THỬ',
        account: '0000000000',
        holder: 'KHONG CHUYEN TIEN',
        payload: payload,
        renderedPath: path,
        brandPath: logoPath,
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
        await preload(tester);
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
        await tester.pump();
        expect(find.byKey(const ValueKey('payment-brand')), findsOneWidget);
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
    await preload(tester);
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
    await tester.pump();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byKey(const ValueKey('qr-preview')),
      matchesGoldenFile('../build/previews/qr-expanded-sample.png'),
    );
  });
  for (final width in [194.0, 400.0, 600.0]) {
    testWidgets('Navigation geometry fixture $width', (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final nav = NavController(connected: false);
      addTearDown(nav.dispose);
      nav.status = 'Mẫu kiểm tra bố cục';
      nav.route = NavRoute(
        [
          const LatLng(21.281, 106.194),
          const LatLng(21.282, 106.194),
          const LatLng(21.282, 106.196),
        ],
        [const TurnStep(1, 'Rẽ phải · Đường mẫu')],
        100,
        'fixture',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: dashboardTheme(Brightness.dark),
          home: Scaffold(
            body: MapPanel(
              key: const ValueKey('navigation-fixture'),
              navigation: nav,
              loadNetwork: false,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('navigation-fixture')),
        matchesGoldenFile(
          '../build/previews/navigation-geometry-${width.toInt()}.png',
        ),
      );
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('Road sign sheet $brightness', (tester) async {
      tester.view.physicalSize = const Size(600, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: dashboardTheme(brightness),
          home: Scaffold(
            body: RepaintBoundary(
              key: const ValueKey('road-signs'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final entry in roadKinds.entries)
                      SizedBox(
                        width: 126,
                        child: Column(
                          children: [
                            SignIcon(
                              kind: entry.key,
                              value: entry.key == 'speed' ? 80 : null,
                              size: 72,
                            ),
                            Text(
                              entry.value,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    const SpeedBadge(
                      status: RoadStatus(
                        limit: SpeedLimit(50, 'estimate', estimated: true),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(const ValueKey('road-signs')),
        matchesGoldenFile(
          '../build/previews/road-signs-${brightness.name}.png',
        ),
      );
    });
  }
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
