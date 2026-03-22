import 'package:flutter/material.dart';
import 'package:mimage/utils/handle.dart';

class CropHandlePainter extends CustomPainter {
  CropHandlePainter({
    required this.handle,
    required this.thickness,
    required this.length,
    required this.handleColor,
    required this.borderWidth,
  });

  final Handle handle;
  final double thickness;
  final double length;
  final Color handleColor;
  final double borderWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final Offset center = Offset(size.width / 2, size.height / 2);

    // We want the inner corner to align to `center` exactly.
    // The handle extends outward depending on whether it is left/right/top/bottom
    if (handle.isCorner) {
      final bool isTop = handle == Handle.topLeft || handle == Handle.topRight;
      final bool isLeft = handle == Handle.topLeft || handle == Handle.bottomLeft;

      final double xDir = isLeft ? 1.0 : -1.0;
      final double yDir = isTop ? 1.0 : -1.0;

      // We will trace the outer hull of the L-shape and then round the path or simply draw two stroked lines that overlap.
      // Easiest and most robust for rounded caps + rounded inner join is to use purely stroke paints on a skeleton path!

      final Paint skeletonBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness + (borderWidth * 2)
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.round;

      final Paint skeletonFillPaint = Paint()
        ..color = handleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.round;

      // The skeleton goes from the end of the vertical leg, to the corner, to the end of the horizontal leg
      // We align the skeleton exactly to the center, so the stroke is centered on the crop boundaries
      // just like the edge handles.

      final double skelX0 = center.dx;
      final double skelY0 = center.dy;
      final double skelXLong = center.dx + (length * xDir);
      final double skelYLong = center.dy + (length * yDir);

      final Path skelPath = Path()
        ..moveTo(skelX0, skelYLong)
        ..lineTo(skelX0, skelY0)
        ..lineTo(skelXLong, skelY0);

      canvas
        ..drawPath(skelPath, skeletonBorderPaint)
        ..drawPath(skelPath, skeletonFillPaint);
    } else {
      final bool isHorizontal = handle == Handle.topCenter || handle == Handle.bottomCenter;

      final Paint skeletonBorderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness + (borderWidth * 2)
        ..strokeCap = StrokeCap.round;

      final Paint skeletonFillPaint = Paint()
        ..color = handleColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;

      final Path skelPath = Path();
      if (isHorizontal) {
        skelPath
          ..moveTo(center.dx - length / 2, center.dy)
          ..lineTo(center.dx + length / 2, center.dy);
      } else {
        skelPath
          ..moveTo(center.dx, center.dy - length / 2)
          ..lineTo(center.dx, center.dy + length / 2);
      }

      canvas
        ..drawPath(skelPath, skeletonBorderPaint)
        ..drawPath(skelPath, skeletonFillPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CropHandlePainter oldDelegate) {
    return oldDelegate.handle != handle ||
        oldDelegate.thickness != thickness ||
        oldDelegate.length != length ||
        oldDelegate.handleColor != handleColor ||
        oldDelegate.borderWidth != borderWidth;
  }
}
