import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/map_panel.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_models.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_controller.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/road_widgets.dart';
import 'package:taxi_driver_aa_dashboard/features/road_data/sign_painter.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('All vector signs and estimated badge render in $brightness', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: ThemeData(brightness: brightness), home: Scaffold(body: SingleChildScrollView(child: Wrap(children: [for (final kind in roadKinds.keys) SignIcon(kind: kind, value: kind == 'speed' ? 80 : null), const SpeedBadge(status: RoadStatus(limit: SpeedLimit(50,'estimate',estimated:true),overspeed:true))])))));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('ước tính'), findsOneWidget);
      expect(find.byType(SignIcon), findsNWidgets(roadKinds.length + 1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final width in [194.0, 400.0]) {
    testWidgets('Three upcoming signs fit a narrow scrollable overlay $width', (tester) async {
      tester.view.physicalSize = Size(width,464); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final nav = NavController(connected:false); addTearDown(nav.dispose);
      final sample = RoadNearby.fromJson(jsonDecode(File('test/fixtures/roads.generated.json').readAsStringSync()) as Map);
      nav.road.status = RoadStatus(upcoming: [for (var i=0;i<3;i++) UpcomingSign(sample.signs[i],150+i*30)]);
      await tester.pumpWidget(MaterialApp(home:Scaffold(body:MapPanel(navigation:nav,loadNetwork:false))));
      await tester.pump();
      expect(find.byType(RoadWarnings),findsOneWidget);
      expect(find.byTooltip('Theo xe'),findsOneWidget);
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Long press on phone map saves a private pin with direction', (tester) async {
    final nav = NavController(connected:false); addTearDown(nav.dispose);
    final calls = <Map<String,dynamic>>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(RoadController.methods,(call) async {
      if (call.method=='nearby') return File('test/fixtures/roads.generated.json').readAsStringSync();
      if (call.method=='savePin') calls.add(jsonDecode((call.arguments as Map)['json'] as String) as Map<String,dynamic>);
      return null;
    });
    addTearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(RoadController.methods,null));
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:MapPanel(navigation:nav,loadNetwork:false))));
    await tester.pump();
    await tester.longPress(find.byType(FlutterMap));
    await tester.pumpAndSettle();
    expect(find.text('Ghim biển báo'),findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton,'Lưu ghim'));
    await tester.pumpAndSettle();
    expect(calls,hasLength(1));
    expect(calls.single['source'],'user');
    expect(calls.single['bearing'],0);
    expect(calls.single['scope'],300);
    expect(calls.single['id'],startsWith('user_'));
    expect(tester.takeException(),isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
