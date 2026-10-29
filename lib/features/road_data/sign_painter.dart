import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'road_models.dart';

class SignIcon extends StatelessWidget {
  const SignIcon({
    super.key,
    required this.kind,
    this.value,
    this.estimated = false,
    this.size = 54,
  });
  final String kind;
  final int? value;
  final bool estimated;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${roadKinds[kind] ?? kind} ${value ?? ''}${estimated ? ' ước tính' : ''}',
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SignPainter(kind, value, estimated)),
    ),
  );
}

class _SignPainter extends CustomPainter {
  const _SignPainter(this.kind, this.value, this.estimated);
  final String kind;
  final int? value;
  final bool estimated;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xffe02020);
    final black = Paint()
      ..color = Colors.black
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    void text(String value, Color color, double fontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            fontFamily: 'NotoSans',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 90);
      painter.paint(
        canvas,
        Offset(50 - painter.width / 2, 50 - painter.height / 2),
      );
    }

    if (kind == 'camera') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(4, 4, 92, 92),
          const Radius.circular(15),
        ),
        Paint()..color = const Color(0xff1765bd),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(19, 35, 62, 39),
          const Radius.circular(5),
        ),
        Paint()..color = Colors.white,
      );
      canvas.drawRect(
        const Rect.fromLTWH(29, 26, 22, 10),
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        const Offset(51, 54),
        13,
        Paint()..color = const Color(0xff1765bd),
      );
    } else if (kind == 'stop') {
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final angle = (22.5 + i * 45) * math.pi / 180;
        final p = Offset(50 + 46 * math.cos(angle), 50 + 46 * math.sin(angle));
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xffdb2020));
      canvas.drawPath(
        path,
        stroke
          ..color = Colors.white
          ..strokeWidth = 3,
      );
      text('STOP', Colors.white, 24);
    } else if (kind == 'giveWay' || kind == 'calming') {
      final inverted = kind == 'giveWay';
      final path = Path()
        ..moveTo(50, inverted ? 92 : 7)
        ..lineTo(7, inverted ? 12 : 87)
        ..lineTo(93, inverted ? 12 : 87)
        ..close();
      canvas.drawPath(
        path,
        Paint()..color = inverted ? Colors.white : const Color(0xffffd62e),
      );
      canvas.drawPath(path, stroke);
      if (!inverted)
        canvas.drawPath(
          Path()
            ..moveTo(25, 70)
            ..quadraticBezierTo(50, 30, 75, 70)
            ..close(),
          Paint()..color = Colors.black,
        );
    } else {
      final blue = kind == 'noStop' || kind == 'noPark';
      canvas.drawCircle(
        const Offset(50, 50),
        44,
        Paint()
          ..color = blue
              ? const Color(0xff1546b0)
              : kind == 'noEntry'
              ? const Color(0xffe02020)
              : Colors.white,
      );
      if (estimated || value == null && kind == 'speed') {
        stroke.color = const Color(0xff727c88);
        stroke.strokeWidth = 5;
        for (var i = 0; i < 12; i++) {
          canvas.drawArc(
            const Rect.fromLTWH(6, 6, 88, 88),
            i * math.pi / 6,
            math.pi / 10,
            false,
            stroke,
          );
        }
      } else {
        canvas.drawCircle(const Offset(50, 50), 44, stroke);
      }
      if (kind == 'speed') {
        text(
          value?.toString() ?? '—',
          Colors.black,
          value != null && value! >= 100 ? 38 : 45,
        );
      } else if (kind == 'noEntry') {
        canvas.drawRect(
          const Rect.fromLTWH(20, 41, 60, 18),
          Paint()..color = Colors.white,
        );
      } else if (kind == 'noCar') {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(23, 41, 54, 24),
            const Radius.circular(4),
          ),
          Paint()..color = Colors.black,
        );
        canvas.drawPath(
          Path()
            ..moveTo(29, 42)
            ..lineTo(36, 29)
            ..lineTo(65, 29)
            ..lineTo(72, 42)
            ..close(),
          black..strokeWidth = 5,
        );
        canvas.drawCircle(
          const Offset(32, 67),
          6,
          Paint()..color = Colors.black,
        );
        canvas.drawCircle(
          const Offset(68, 67),
          6,
          Paint()..color = Colors.black,
        );
      } else if (kind == 'noLeft' || kind == 'noRight') {
        canvas.save();
        if (kind == 'noRight') {
          canvas.translate(100, 0);
          canvas.scale(-1, 1);
        }
        canvas.drawPath(
          Path()
            ..moveTo(60, 77)
            ..lineTo(60, 40)
            ..lineTo(28, 40)
            ..moveTo(43, 25)
            ..lineTo(28, 40)
            ..lineTo(43, 55),
          black,
        );
        canvas.restore();
      } else if (kind == 'noUturn') {
        canvas.drawPath(
          Path()
            ..moveTo(69, 76)
            ..lineTo(69, 39)
            ..cubicTo(69, 18, 34, 18, 34, 39)
            ..lineTo(34, 65)
            ..moveTo(21, 51)
            ..lineTo(34, 65)
            ..lineTo(47, 51),
          black,
        );
      } else if (kind == 'noStraight') {
        canvas.drawPath(
          Path()
            ..moveTo(50, 77)
            ..lineTo(50, 24)
            ..moveTo(34, 42)
            ..lineTo(50, 24)
            ..lineTo(66, 42),
          black,
        );
      }
      if (kind.startsWith('no') && kind != 'noEntry') {
        stroke.color = const Color(0xffe02020);
        stroke.strokeWidth = 8;
        canvas.drawLine(const Offset(20, 20), const Offset(80, 80), stroke);
        if (kind == 'noStop')
          canvas.drawLine(const Offset(80, 20), const Offset(20, 80), stroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SignPainter oldDelegate) =>
      kind != oldDelegate.kind ||
      value != oldDelegate.value ||
      estimated != oldDelegate.estimated;
}
