import 'package:flutter/material.dart';
import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/utils/constants.dart';
import 'package:mimage/utils/handle.dart';
import 'package:mimage/widgets/crop_handle_painter.dart';

class CropHandle extends StatelessWidget {
  const CropHandle({
    required this.handle,
    required this.image,
    required this.dragCropRectPixels,
    required this.thickness,
    required this.length,
    required this.borderWidth,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    super.key,
  });

  final Handle handle;
  final CanvasImage image;
  final Rect dragCropRectPixels;
  final double thickness;
  final double length;
  final double borderWidth;
  final void Function(Handle handle) onPanStart;
  final void Function(DragUpdateDetails details) onPanUpdate;
  final void Function() onPanEnd;

  @override
  Widget build(BuildContext context) {
    final cropR = dragCropRectPixels;

    double centerDx = 0;
    double centerDy = 0;

    switch (handle) {
      case Handle.topLeft:
        centerDx = cropR.left;
        centerDy = cropR.top;
      case Handle.topCenter:
        centerDx = cropR.left + cropR.width / 2;
        centerDy = cropR.top;
      case Handle.topRight:
        centerDx = cropR.right;
        centerDy = cropR.top;
      case Handle.centerLeft:
        centerDx = cropR.left;
        centerDy = cropR.top + cropR.height / 2;
      case Handle.centerRight:
        centerDx = cropR.right;
        centerDy = cropR.top + cropR.height / 2;
      case Handle.bottomLeft:
        centerDx = cropR.left;
        centerDy = cropR.bottom;
      case Handle.bottomCenter:
        centerDx = cropR.left + cropR.width / 2;
        centerDy = cropR.bottom;
      case Handle.bottomRight:
        centerDx = cropR.right;
        centerDy = cropR.bottom;
    }

    final double hitSize = length + Constants.cropHandleHitSizeExtension; // Enlarge hit area
    final double halfHit = hitSize / 2;
    final Color handleColor = Theme.of(context).colorScheme.primary;

    return Positioned(
      top: centerDy - halfHit,
      left: centerDx - halfHit,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => onPanStart(handle),
        onPanUpdate: onPanUpdate,
        onPanEnd: (_) => onPanEnd(),
        child: CustomPaint(
          size: Size(hitSize, hitSize),
          painter: CropHandlePainter(
            handle: handle,
            thickness: thickness,
            length: length,
            handleColor: handleColor,
            borderWidth: borderWidth,
          ),
        ),
      ),
    );
  }
}
