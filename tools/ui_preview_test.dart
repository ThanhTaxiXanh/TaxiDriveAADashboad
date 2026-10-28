import 'dart:convert';
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
  setUpAll(() async {
    final loader = FontLoader('NotoSans')
      ..addFont(rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
    await loader.load();
    events = EventArchive.fromJson(
      jsonDecode(await rootBundle.loadString('assets/events_vn.json')),
    ).events;
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
              ),
            ),
          ),
        );
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
