import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mimage/utils/constants.dart';
import 'package:mimage/utils/handle.dart';
import 'package:mimage/widgets/export_handle.dart';

class ExportOverlay extends StatelessWidget {
  const ExportOverlay({
    required this.exportRectPixels,
    required this.onMoveStart,
    required this.onMoveUpdate,
    required this.onMoveEnd,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    super.key,
  });

  final Rect exportRectPixels;
  final void Function() onMoveStart;
  final void Function(DragUpdateDetails details) onMoveUpdate;
  final void Function() onMoveEnd;
  final void Function(Handle handle) onPanStart;
  final void Function(DragUpdateDetails details) onPanUpdate;
  final void Function() onPanEnd;

  @override
  Widget build(BuildContext context) {
    final cropR = exportRectPixels;
    final double cropMinDim = math.min(cropR.width, cropR.height);

    double handleLength = (cropMinDim * Constants.cropOverlayLengthRatio).clamp(
      Constants.cropOverlayLengthMin,
      Constants.cropOverlayLengthMax,
    );
    handleLength = math.min(handleLength, cropMinDim / 3);
    final double handleThickness = math.max(Constants.cropOverlayThicknessMin, handleLength * Constants.cropOverlayThicknessRatio);
    final double handleBorderSize = math.max(Constants.cropOverlayBorderSizeMin, handleThickness * Constants.cropOverlayBorderSizeRatio);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: cropR.left,
          top: cropR.top,
          width: cropR.width,
          height: cropR.height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => onMoveStart(),
            onPanUpdate: onMoveUpdate,
            onPanEnd: (_) => onMoveEnd(),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.secondary, width: handleBorderSize),
                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
        ExportHandle(
          handle: Handle.topCenter,
          exportRectPixels: exportRectPixels,
          thickness: handleThickness,
          length: handleLength,
          borderWidth: handleBorderSize,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
        ),
        ExportHandle(
          handle: Handle.centerLeft,
          exportRectPixels: exportRectPixels,
          thickness: handleThickness,
          length: handleLength,
          borderWidth: handleBorderSize,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
        ),
        ExportHandle(
          handle: Handle.centerRight,
          exportRectPixels: exportRectPixels,
          thickness: handleThickness,
          length: handleLength,
          borderWidth: handleBorderSize,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
        ),
        ExportHandle(
          handle: Handle.bottomCenter,
          exportRectPixels: exportRectPixels,
          thickness: handleThickness,
          length: handleLength,
          borderWidth: handleBorderSize,
          onPanStart: onPanStart,
          onPanUpdate: onPanUpdate,
          onPanEnd: onPanEnd,
        ),
      ],
    );
  }
}
