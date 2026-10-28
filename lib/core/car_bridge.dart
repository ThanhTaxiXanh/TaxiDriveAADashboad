import 'package:flutter/services.dart';

class CarBridge {
  static const methods = MethodChannel('taxi/dashboard');
  static const events = EventChannel('taxi/dashboard/events');

  static Future<Map<String, dynamic>> snapshot() async =>
      Map<String, dynamic>.from(
        await methods.invokeMapMethod<String, dynamic>('snapshot') ?? {},
      );

  static final _stream = events.receiveBroadcastStream().map((event) => Map<String, dynamic>.from(event as Map)).asBroadcastStream();
  static Stream<Map<String, dynamic>> watch() => _stream;

  static Future<void> reportFrames(int frames, int elapsedMs) => methods
      .invokeMethod('frames', {'frames': frames, 'elapsedMs': elapsedMs});

  static Future<void> share() => methods.invokeMethod('shareLog');
}
