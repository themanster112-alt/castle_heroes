import 'package:flutter/material.dart';

/// One continuous trail; the same coordinates drive scenery and game pieces.
class SoloMapPainter extends CustomPainter {
  const SoloMapPainter();

  static const platforms = <Offset>[
    Offset(.30, .89),
    Offset(.23, .83),
    Offset(.20, .77),
    Offset(.26, .71),
    Offset(.34, .65),
    Offset(.36, .59),
    Offset(.30, .53),
    Offset(.23, .47),
    Offset(.20, .41),
    Offset(.25, .35),
    Offset(.32, .30),
    Offset(.35, .25),
    Offset(.42, .21),
    Offset(.50, .18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width, size.height);
    final paint = Paint();
    final bounds = const Rect.fromLTWH(0, 0, 1, 1);
    paint.shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF233E5B), Color(0xFF416958), Color(0xFF172E32)],
    ).createShader(bounds);
    canvas.drawRect(bounds, paint);
    paint.shader = null;

    // Distant peaks, with a single open valley for the trail.
    for (final peak in [const Offset(.12, .05), const Offset(.80, .01)]) {
      final mountain = Path()
        ..moveTo(peak.dx - .35, .30)
        ..lineTo(peak.dx, peak.dy)
        ..lineTo(peak.dx + .35, .30)
        ..close();
      canvas.drawPath(mountain, paint..color = const Color(0xFF314E59));
    }
    canvas.drawOval(
      const Rect.fromLTWH(.56, .34, .60, .50),
      paint..color = const Color(0xFF24484B),
    );
    for (var i = 0; i < 18; i++) {
      final x = i.isEven ? .04 + (i % 3) * .035 : .83 + (i % 3) * .045;
      final y = .25 + (i ~/ 2) * .075;
      canvas.drawRect(
        Rect.fromLTWH(x - .005, y, .01, .045),
        paint..color = const Color(0xFF654C37),
      );
      final tree = Path()
        ..moveTo(x, y - .035)
        ..lineTo(x - .035, y + .025)
        ..lineTo(x + .035, y + .025)
        ..close();
      canvas.drawPath(tree, paint..color = const Color(0xFF183C35));
    }

    final trail = Path()..moveTo(platforms.first.dx, .95);
    for (final point in platforms) {
      trail.lineTo(point.dx, point.dy);
    }
    paint
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = .105
      ..color = const Color(0xFF23302B);
    canvas.drawPath(trail, paint);
    paint
      ..strokeWidth = .078
      ..color = const Color(0xFFB39A65);
    canvas.drawPath(trail, paint);
    paint
      ..strokeWidth = .048
      ..color = const Color(0xFF8E7955);
    canvas.drawPath(trail, paint);
    paint.style = PaintingStyle.fill;

    // The destination is a castle, not a second player's empty lane.
    canvas.drawOval(
      const Rect.fromLTWH(.31, .145, .38, .045),
      paint..color = const Color(0xFF25332F),
    );
    canvas.drawRect(
      const Rect.fromLTWH(.34, .085, .32, .085),
      paint..color = const Color(0xFFB6B4A1),
    );
    for (final x in [.32, .46, .60]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, .065, .08, .10),
          const Radius.circular(.008),
        ),
        paint..color = const Color(0xFFD7CFAC),
      );
      for (var n = 0; n < 3; n++) {
        canvas.drawRect(Rect.fromLTWH(x + n * .03, .052, .02, .025), paint);
      }
      canvas.drawRect(
        Rect.fromLTWH(x + .032, .095, .017, .025),
        paint..color = const Color(0xFF263747),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(.465, .127, .07, .043),
        const Radius.circular(.025),
      ),
      paint..color = const Color(0xFF493C2D),
    );
    canvas.drawRect(
      const Rect.fromLTWH(.497, .015, .006, .038),
      paint..color = const Color(0xFFE5C974),
    );
    canvas.drawPath(
      Path()
        ..moveTo(.503, .015)
        ..lineTo(.565, .025)
        ..lineTo(.503, .039)
        ..close(),
      paint..color = const Color(0xFFE5B94C),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SoloMapPainter oldDelegate) => false;
}
