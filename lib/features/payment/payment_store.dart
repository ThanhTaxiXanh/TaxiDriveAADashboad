import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/car_bridge.dart';
import 'payment_config.dart';

class PaymentStore extends ChangeNotifier {
  PaymentStore({this.connected = true, bool phone = false}) {
    if (connected) {
      subscription = CarBridge.watch().listen((event) {
        final next = event['paymentRevision'] as int? ?? 0;
        if (revision != next) {
          revision = next;
          unawaited(reload());
        }
      });
      unawaited(reload());
      if (phone) recovery = recover();
    }
  }
  final bool connected;
  PaymentConfig config = const PaymentConfig();
  bool ready = false, closed = false;
  String? error;
  int revision = -1, generation = 0;
  StreamSubscription<Map<String, dynamic>>? subscription;
  Future<void>? recovery;
  XFile? recovered;
  String? recoveredRole;
  Future<void> recover() async {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (closed) return;
      if (lost.files?.isNotEmpty == true) {
        recovered = lost.files!.first;
        recoveredRole =
            await CarBridge.methods.invokeMethod<String>(
              'getPaymentPickRole',
            ) ??
            'original';
      }
    } catch (_) {
      /* Picker failure never exposes file names or account data in logs. */
    }
  }

  Future<void> reload() async {
    final token = ++generation;
    try {
      final raw = await CarBridge.methods.invokeMethod<String>('getPayment');
      final value = PaymentConfig.fromJson(
        jsonDecode(raw!) as Map<String, dynamic>,
      );
      if (closed || token != generation) return;
      config = value;
      ready = true;
      error = null;
      notifyListeners();
    } catch (_) {
      if (!closed && token == generation) {
        error = 'Không đọc được QR; hãy mở lại ứng dụng.';
        notifyListeners();
      }
    }
  }

  Future<String> writeImage(Uint8List bytes) async => (await CarBridge.methods
      .invokeMethod<String>('writePaymentImage', {'bytes': bytes}))!;
  Future<void> save(PaymentConfig config) async {
    await CarBridge.methods.invokeMethod('savePayment', {
      'json': jsonEncode(config.toJson()),
    });
    await reload();
  }

  Future<void> clear() async {
    await CarBridge.methods.invokeMethod('clearPayment');
    await reload();
  }

  Future<void> setPickRole(String? role) =>
      CarBridge.methods.invokeMethod('setPaymentPickRole', {'role': role});
  @override
  void dispose() {
    closed = true;
    subscription?.cancel();
    super.dispose();
  }
}
