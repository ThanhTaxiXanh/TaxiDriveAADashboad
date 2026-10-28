import 'package:flutter/material.dart';

class VehicleMarker extends StatelessWidget {
  const VehicleMarker({
    super.key,
    this.headingRadians = 0,
    this.fresh = true,
    this.size = 54,
  });
  final double headingRadians, size;
  final bool fresh;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Transform.rotate(
      angle: headingRadians,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _VehicleArrow(fresh)),
      ),
    ),
  );
}

class _VehicleArrow extends CustomPainter {
  const _VehicleArrow(this.fresh);
  final bool fresh;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5, size.height * .1)
      ..cubicTo(
        size.width * .46,
        size.height * .07,
        size.width * .43,
        size.height * .1,
        size.width * .4,
        size.height * .15,
      )
      ..lineTo(size.width * .13, size.height * .77)
      ..quadraticBezierTo(
        size.width * .08,
        size.height * .9,
        size.width * .23,
        size.height * .85,
      )
      ..lineTo(size.width * .5, size.height * .75)
      ..lineTo(size.width * .77, size.height * .85)
      ..quadraticBezierTo(
        size.width * .92,
        size.height * .9,
        size.width * .87,
        size.height * .77,
      )
      ..lineTo(size.width * .6, size.height * .15)
      ..quadraticBezierTo(
        size.width * .55,
        size.height * .08,
        size.width * .5,
        size.height * .1,
      )
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: .7), 5, true);
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fresh
              ? const [Color(0xff5cceff), Color(0xff2454ef)]
              : const [Color(0xffc2c9ce), Color(0xff6a737e)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_VehicleArrow oldDelegate) => fresh != oldDelegate.fresh;
}
