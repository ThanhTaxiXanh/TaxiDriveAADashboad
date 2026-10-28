import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/calendar/calendar_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/calendar/event_item.dart';
import 'package:taxi_driver_aa_dashboard/features/dashboard/dashboard_screen.dart';
import 'package:taxi_driver_aa_dashboard/core/layout_config.dart';

void main() {
  testWidgets('Calendar pages cycle; full month and selected lunar dates render', (tester) async {
    tester.view.physicalSize = const Size(400, 800); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final events = EventArchive.fromJson(jsonDecode(File('assets/events_vn.json').readAsStringSync())).events;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: CalendarPanel(today: DateTime.utc(2026, 10, 28), events: events))));
    expect(find.textContaining('Bính Ngọ'), findsOneWidget);
    expect(find.textContaining('Nhà giáo Việt Nam'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('calendar-cycle'))); await tester.pump();
    expect(find.text('Lưới tháng'), findsOneWidget);
    expect(find.text('T2'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('calendar-cycle'))); await tester.pump();
    expect(find.text('Sự kiện gần nhất'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Small calendar has a click target to expand, without long press', (tester) async {
    var expanded = -1;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SizedBox(width: 194, height: 64, child: CalendarPanel(today: DateTime.utc(2026, 10, 28), fontScale: 1.6, onExpand: (page) => expanded = page)))));
    await tester.tap(find.byTooltip('Mở lịch đầy đủ')); await tester.pump();
    expect(expanded, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Calendar expands only right column and collapse restores rows', (tester) async {
    tester.view.physicalSize = const Size(803, 843); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: DashboardFrame(config: LayoutConfig(leftFraction: .75, fontScale: 1.6), today: DateTime.utc(2026, 10, 28))))));
    await tester.tap(find.byTooltip('Mở lịch đầy đủ')); await tester.pump();
    expect(find.byKey(const ValueKey('map-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-1')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('calendar-cycle'))); await tester.pump();
    expect(find.text('T2'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Thu gọn lịch')); await tester.pump();
    expect(find.byKey(const ValueKey('row-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
