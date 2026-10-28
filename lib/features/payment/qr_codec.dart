import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

// Decoding runs off the UI isolate. No payload is printed or sent over HTTP.
String? decodeQrBytes(Uint8List bytes) {
  try {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    final rgba = image
        .convert(numChannels: 4)
        .getBytes(order: img.ChannelOrder.abgr);
    final source = RGBLuminanceSource(
      image.width,
      image.height,
      rgba.buffer.asInt32List(rgba.offsetInBytes, rgba.lengthInBytes ~/ 4),
    );
    for (final binarizer in [
      HybridBinarizer(source),
      GlobalHistogramBinarizer(source),
    ]) {
      try {
        return QRCodeReader().decode(BinaryBitmap(binarizer)).text;
      } catch (_) {
        /* Try the other binarizer. */
      }
    }
  } catch (_) {
    /* An unreadable image remains usable in original-image mode. */
  }
  return null;
}

Future<Uint8List> normalizePickedImage(String path, {bool logo = false}) async {
  final file = File(path);
  if (await file.length() > 20 * 1024 * 1024)
    throw const FormatException('Ảnh tối đa 20 MB');
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    await file.readAsBytes(),
  );
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  ui.Codec? codec;
  ui.Image? image;
  try {
    final maxSide = logo ? 768 : 2048;
    final factor = math.min(
      1.0,
      maxSide / math.max(descriptor.width, descriptor.height),
    );
    codec = await descriptor.instantiateCodec(
      targetWidth: math.max(1, (descriptor.width * factor).round()),
      targetHeight: math.max(1, (descriptor.height * factor).round()),
    );
    image = (await codec.getNextFrame()).image;
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final data = bytes!.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    if (data.length > 8 * 1024 * 1024)
      throw const FormatException(
        'Ảnh sau xử lý quá lớn; hãy chọn ảnh gọn hơn',
      );
    return data;
  } finally {
    image?.dispose();
    codec?.dispose();
    descriptor.dispose();
    buffer.dispose();
  }
}

class PaymentQrPainter extends CustomPainter {
  PaymentQrPainter(this.payload, {this.logo}) {
    final result = QrValidator.validate(
      data: payload,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.H,
    );
    if (!result.isValid) throw const FormatException('Nội dung QR quá dài');
    painter = QrPainter.withQr(qr: result.qrCode!, gapless: true);
    modules = result.qrCode!.moduleCount;
  }
  final String payload;
  final ui.Image? logo;
  late final QrPainter painter;
  late final int modules;
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final module =
        side / (modules + 8); // Four complete white modules on every edge.
    final codeSide = module * modules;
    canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
    canvas.save();
    canvas.translate((size.width - codeSide) / 2, (size.height - codeSide) / 2);
    painter.paint(canvas, Size.square(codeSide));
    canvas.restore();
    if (logo != null) {
      final center = Offset(size.width / 2, size.height / 2);
      final radius =
          codeSide * .085; // Including white rim: 17%, below the 20% limit.
      canvas.drawCircle(center, radius, Paint()..color = Colors.white);
      final inside = Rect.fromCircle(center: center, radius: radius * .82);
      canvas.save();
      canvas.clipPath(Path()..addOval(inside));
      paintImage(
        canvas: canvas,
        rect: inside,
        image: logo!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(PaymentQrPainter oldDelegate) =>
      payload != oldDelegate.payload || logo != oldDelegate.logo;
}

Future<Uint8List> renderPaymentQr(
  String payload, {
  Uint8List? logoBytes,
  bool verify = true,
}) async {
  ui.Codec? codec;
  ui.Image? logo;
  ui.Image? image;
  ui.Picture? picture;
  try {
    if (logoBytes != null) {
      codec = await ui.instantiateImageCodec(logoBytes);
      logo = (await codec.getNextFrame()).image;
    }
    final recorder = ui.PictureRecorder();
    PaymentQrPainter(
      payload,
      logo: logo,
    ).paint(Canvas(recorder), const Size.square(1024));
    picture = recorder.endRecording();
    image = await picture.toImage(1024, 1024);
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    if (verify && await compute(decodeQrBytes, bytes) != payload)
      throw const FormatException(
        'QR chưa giải mã được; thử bỏ logo giữa hoặc rút ngắn nội dung',
      );
    return bytes;
  } finally {
    image?.dispose();
    picture?.dispose();
    logo?.dispose();
    codec?.dispose();
  }
}
