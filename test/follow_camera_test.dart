import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/follow_camera.dart';
import 'package:taxi_driver_aa_dashboard/features/navigation/nav_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Speed opens the view; an approaching turn restores close detail', () {
    double zoom(double speed, {double? turn, bool active = true}) => FollowCamera.zoom(speedKmh: speed, navigating: active, turnMeters: turn);
    expect(zoom(0), greaterThan(zoom(60)));
    expect(zoom(60), greaterThan(zoom(100)));
    expect(zoom(100, turn: 40), greaterThan(zoom(100, turn: 600)));
    expect(zoom(100, turn: 600), greaterThan(zoom(100, turn: 1500)));
    expect(zoom(100, turn: 40, active: false), zoom(100));
    for (final speed in [-1.0, 0.0, 30.0, 80.0, 140.0, double.nan]) {
      for (final turn in [0.0, 150.0, 350.0, 700.0, 2000.0, double.infinity]) {
        expect(zoom(speed, turn: turn), inInclusiveRange(15.5, 18.5));
      }
    }
    expect(FollowCamera.pitch, 60);
  });
  test('Recenter resumes following after repeated browsing', () {
    final camera = FollowCamera();
    camera.browse();
    expect(camera.following, false);
    camera.recenter();
    expect(camera.following, true);
    camera.browse();
    camera.recenter();
    expect(camera.following, true);
  });
  test('First shared gesture is a baseline; later changes apply once', () {
    final nav = NavController(connected: false)..revision = 0;
    addTearDown(nav.dispose);
    final data = <String, dynamic>{'routeRevision': 0, 'gesture': 18, 'scale': 1.5, 'fix': {'lat': 21.281, 'lon': 106.194, 'accuracy': 8, 'speed': 5, 'bearing': 270, 'time': DateTime.now().millisecondsSinceEpoch}};
    nav.accept(data);
    expect(nav.gesture, 0);
    expect(nav.bearing, 270);
    nav.accept({...data, 'gesture': 19});
    expect(nav.gesture, 1);
    nav.accept({...data, 'gesture': 19});
    expect(nav.gesture, 1);
  });
  test('Car recenter requests the shared GPS service, not a phone permission dialog', () async {
    final nav = NavController(connected: false, car: true)..revision = 0;
    addTearDown(nav.dispose);
    final called = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(NavController.methods, (MethodCall call) async {
      called.add(call.method);
      return call.method == 'snapshot' ? jsonEncode({'routeRevision': 0, 'carConnected': true, 'backgroundLocation': true}) : null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(NavController.methods, null));
    await nav.locate();
    expect(called, ['requestLocation', 'snapshot']);
    expect(nav.carConnected, true);
    expect(nav.backgroundLocation, true);
  });
}
