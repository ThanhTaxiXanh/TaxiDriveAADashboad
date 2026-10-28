import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'car_bridge.dart';
import 'layout_config.dart';

class DashboardController extends ChangeNotifier {
  DashboardController({this.connected = true, LayoutConfig? initial})
    : config = initial ?? LayoutConfig(),
      ready = !connected {
    if (connected) {
      subscription = CarBridge.watch().listen(
        (event) {
          diagnostics = event;
          final raw = event['layout'] as String?;
          if (raw != null) {
            try {
              config = LayoutConfig.fromJson(
                jsonDecode(raw) as Map<String, dynamic>,
              );
            } catch (_) {
              error = 'Cấu hình đã hỏng; dùng mặc định. Hãy đặt lại bố cục.';
            }
          }
          panel = event['panel'] as String? ?? 'dashboard';
          ready = true;
          notifyListeners();
        },
        onError: (Object e) {
          error = 'Mất kết nối cầu nối: $e';
          notifyListeners();
        },
      );
    }
  }
  final bool connected;
  LayoutConfig config;
  Map<String, dynamic> diagnostics = {};
  String panel = 'dashboard';
  String? error;
  bool ready;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Future<void> update(LayoutConfig next) async {
    if (!ready) return;
    if (!connected) {
      config = next;
      notifyListeners();
      return;
    }
    try {
      await CarBridge.methods.invokeMethod('saveLayout', {
        'layout': next.toJson(),
      });
    } catch (_) {
      error = 'Không lưu được bố cục. Vui lòng thử lại.';
      notifyListeners();
    }
  }

  Future<void> showPanel(String next) async {
    if (!connected) {
      panel = next;
      notifyListeners();
      return;
    }
    await CarBridge.methods.invokeMethod('showPanel', {'panel': next});
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }
}
