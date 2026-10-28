import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
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
            account: 'ABC0123456789012345',
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
  testWidgets('Transparent PNG stays transparent and decodes on a white mat', (tester) async {
    await tester.runAsync(() async {
      final payload = const VietQr(bin: '970436', account: '0123456789').build();
      final png = await renderPaymentQr(payload, verify: false);
      final source = img.decodePng(png)!.convert(numChannels: 4);
      for (final p in source) {
        if (p.r > 245 && p.g > 245 && p.b > 245) { p..r = 0..g = 0..b = 0..a = 0; }
      }
      final transparent = img.encodePng(source);
      expect(decodeQrBytes(transparent), payload);
      final folder = await Directory.systemTemp.createTemp('alpha-qr-test-');
      try {
        final file = File('${folder.path}/transparent.png');
        await file.writeAsBytes(transparent);
        final normalized = img.decodePng(await normalizePickedImage(file.path, logo: true))!;
        expect(normalized.getPixel(0, 0).a, 0);
        expect(normalized.width, 1024);
      } finally { await folder.delete(recursive: true); }
    });
  });
  test('Unreadable source image returns null', () {
    expect(decodeQrBytes(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
