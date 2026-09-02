import 'package:flutter/material.dart';

/// Ghost silhouette the user lines up with. A simple guide for v1; live pose
/// validation with voice coaching is the v2 upgrade.
class PoseOverlayPainter extends CustomPainter {
  final bool sideView;
  PoseOverlayPainter({required this.sideView});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    // Body occupies ~80% of frame height, centered.
    final top = h * 0.08;
    final bottom = h * 0.92;
    final bh = bottom - top; // body height in px

    final headR = bh * 0.055;
    final headC = Offset(cx, top + headR);

    canvas.drawCircle(headC, headR, paint);

    final path = Path();
    if (!sideView) {
      final shoulderY = top + bh * 0.16;
      final hipY = top + bh * 0.50;
      final shoulderHalf = bh * 0.115;
      final hipHalf = bh * 0.085;
      // Torso
      path.moveTo(cx - shoulderHalf, shoulderY);
      path.quadraticBezierTo(
          cx - shoulderHalf * 1.05, (shoulderY + hipY) / 2, cx - hipHalf, hipY);
      path.lineTo(cx + hipHalf, hipY);
      path.quadraticBezierTo(
          cx + shoulderHalf * 1.05, (shoulderY + hipY) / 2, cx + shoulderHalf, shoulderY);
      path.close();
      // Arms lifted ~30°
      path.moveTo(cx - shoulderHalf, shoulderY + 6);
      path.lineTo(cx - shoulderHalf - bh * 0.13, top + bh * 0.42);
      path.moveTo(cx + shoulderHalf, shoulderY + 6);
      path.lineTo(cx + shoulderHalf + bh * 0.13, top + bh * 0.42);
      // Legs slightly apart
      path.moveTo(cx - hipHalf * 0.6, hipY);
      path.lineTo(cx - bh * 0.07, bottom);
      path.moveTo(cx + hipHalf * 0.6, hipY);
      path.lineTo(cx + bh * 0.07, bottom);
    } else {
      final shoulderY = top + bh * 0.16;
      final hipY = top + bh * 0.50;
      final depthHalf = bh * 0.07;
      path.moveTo(cx - depthHalf, shoulderY);
      path.quadraticBezierTo(
          cx - depthHalf * 1.3, (shoulderY + hipY) / 2, cx - depthHalf * 0.9, hipY);
      path.lineTo(cx + depthHalf * 0.9, hipY);
      path.quadraticBezierTo(
          cx + depthHalf * 1.15, (shoulderY + hipY) / 2, cx + depthHalf, shoulderY);
      path.close();
      // One visible arm, slightly forward
      path.moveTo(cx, shoulderY + 6);
      path.lineTo(cx + bh * 0.05, top + bh * 0.44);
      // Legs together
      path.moveTo(cx, hipY);
      path.lineTo(cx, bottom);
    }
    canvas.drawPath(path, paint);

    // Head and feet bound lines — these are what the measurement engine
    // actually needs in frame (face→heels calibrates height), so they read
    // stronger than the silhouette, which is only a stance guide.
    final boundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(w * 0.1, top), Offset(w * 0.9, top), boundPaint);
    canvas.drawLine(
        Offset(w * 0.1, bottom), Offset(w * 0.9, bottom), boundPaint);
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter old) =>
      old.sideView != sideView;
}
