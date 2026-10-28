import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taxi_driver_aa_dashboard/features/payment/qr_codec.dart';
import 'package:taxi_driver_aa_dashboard/features/payment/vietqr.dart';

void main() {
  testWidgets(
    'Real qr_flutter raster decodes exactly with and without round center logo',
    (tester) async {
      await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 128, 128),
          Paint()..color = Colors.red,
        );
        canvas.drawCircle(
          const Offset(64, 64),
          35,
          Paint()..color = Colors.yellow,
        );
        final picture = recorder.endRecording();
        final logo = await picture.toImage(128, 128);
        final data = (await logo.toByteData(format: ui.ImageByteFormat.png))!;
        final logoBytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        for (final qr in [
          const VietQr(bin: '970436', account: '0123456789'),
          const VietQr(
            bin: '970422',
            account: '001234567890',
            amount: '250000',
            note: 'Cuốc xe sân bay',
          ),
          const VietQr(
            bin: '970416',
            account: 'ABC01234567890123456',
            amount: '999999999999',
            note: '12345678901234567890123456789012345678901234567890',
          ),
        ]) {
          for (final overlay in [null, logoBytes]) {
            final payload = qr.build();
            final png = await renderPaymentQr(
              payload,
              logoBytes: overlay,
              verify: false,
            );
            expect(decodeQrBytes(png), payload);
          }
        }
        logo.dispose();
        picture.dispose();
      });
    },
  );
  test('Unreadable source image returns null', () {
    expect(decodeQrBytes(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
