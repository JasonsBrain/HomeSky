// =============================================================================
//  logo.dart – the Homesky mark: a striped synthwave sun setting behind a
//  roof. Drawn in code, so it's sharp at any size and needs no image files.
// =============================================================================

import 'package:flutter/material.dart';

import '../theme.dart';

class HomeskyLogo extends StatelessWidget {
  const HomeskyLogo({super.key, this.size = 30, this.background = HS.header});

  final double size;

  /// Must match whatever is behind the logo (it "cuts" the sun under the roof).
  final Color background;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Homesky',
        image: true,
        child: CustomPaint(size: Size.square(size), painter: _LogoPainter(background)),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.background);
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    // The design is drawn on a 140 × 140 grid, then scaled to the real size.
    canvas.scale(size.width / 140, size.height / 140);

    // 1) Striped sun: coloured bands clipped to a circle.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: const Offset(70, 70), radius: 50)));
    void band(double top, double height, Color color) =>
        canvas.drawRect(Rect.fromLTWH(0, top, 140, height), Paint()..color = color);
    band(24, 44, HS.pink);
    band(72, 14, HS.purple);
    band(90, 9, HS.mLight);
    band(103, 5, HS.cyan);
    canvas.restore();

    // 2) Hide the bottom of the sun behind the house.
    final house = Path()
      ..moveTo(0, 118)
      ..lineTo(70, 58)
      ..lineTo(140, 118)
      ..lineTo(140, 140)
      ..lineTo(0, 140)
      ..close();
    canvas.drawPath(house, Paint()..color = background);

    // 3) The roof line.
    final roof = Path()
      ..moveTo(14, 116)
      ..lineTo(70, 68)
      ..lineTo(126, 116);
    canvas.drawPath(
      roof,
      Paint()
        ..color = HS.mLight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.background != background;
}
