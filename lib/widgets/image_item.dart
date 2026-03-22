import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/utils/constants.dart';
import 'package:mimage/utils/handle.dart';
import 'package:mimage/utils/selection_mode.dart';
import 'package:mimage/widgets/crop_handle.dart';
import 'package:mimage/widgets/resize_handle.dart';

class ImageItem extends StatelessWidget {
  const ImageItem({
    required this.image,
    required this.index,
    required this.isSelected,
    required this.selectionMode,
    required this.dragCropRectPixels,
    required this.onPointerDown,
    required this.onPointerUp,
    required this.onResizePanStart,
    required this.onResizePanUpdate,
    required this.onResizePanEnd,
    required this.onCropPanStart,
    required this.onCropPanUpdate,
    required this.onCropPanEnd,
    this.onMovePanStart,
    this.onMovePanUpdate,
    super.key,
  });

  final CanvasImage image;
  final int index;
  final bool isSelected;
  final SelectionMode selectionMode;
  final Rect? dragCropRectPixels;

  final void Function(PointerDownEvent event) onPointerDown;
  final void Function(PointerUpEvent event) onPointerUp;

  final void Function(Handle handle, CanvasImage image) onResizePanStart;
  final void Function(DragUpdateDetails details) onResizePanUpdate;
  final void Function() onResizePanEnd;

  final void Function(Handle handle) onCropPanStart;
  final void Function(DragUpdateDetails details) onCropPanUpdate;
  final void Function() onCropPanEnd;

  final void Function(DragStartDetails details)? onMovePanStart;
  final void Function(DragUpdateDetails details)? onMovePanUpdate;

  @override
  Widget build(BuildContext context) {
    final bool showHandles = isSelected && selectionMode == SelectionMode.resize;

    final double minDim = image.size != null ? math.min(image.size!.width, image.size!.height) : Constants.minImageDimFallback;
    final double handleSize = showHandles
        ? (minDim * Constants.handleSizeRatio).clamp(Constants.handleSizeMin, Constants.handleSizeMax)
        : 0.0;
    final double handlePadding = showHandles ? handleSize / 2 : 0.0;
    final double borderWidth = isSelected
        ? (minDim * Constants.borderWidthRatio).clamp(Constants.borderWidthMin, Constants.borderWidthMax)
        : 0.0;
    final double handleBorderSize = (minDim * Constants.handleBorderSizeRatio).clamp(
      Constants.handleBorderSizeMin,
      Constants.handleBorderSizeMax,
    );

    final Widget imageContent = Listener(
      onPointerDown: onPointerDown,
      onPointerUp: onPointerUp,
      child: DecoratedBox(
        key: image.key,
        position: DecorationPosition.foreground,
        decoration: isSelected && selectionMode != SelectionMode.crop
            ? BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: borderWidth),
              )
            : const BoxDecoration(),
        child: IgnorePointer(
          ignoring: !isSelected,
          child: image.size != null
              ? SizedBox(
                  width: image.size!.width,
                  height: image.size!.height,
                  child: Builder(
                    builder: (context) {
                      final crop = image.cropRect;
                      if (crop == null) {
                        return Image.file(File(image.path), fit: BoxFit.fill);
                      }
                      final fullWidth = image.size!.width / crop.width;
                      final fullHeight = image.size!.height / crop.height;
                      return ClipRect(
                        child: OverflowBox(
                          maxWidth: fullWidth,
                          maxHeight: fullHeight,
                          alignment: Alignment.topLeft,
                          child: FractionalTranslation(
                            translation: Offset(-crop.left, -crop.top),
                            child: SizedBox(
                              width: fullWidth,
                              height: fullHeight,
                              child: Image.file(File(image.path), fit: BoxFit.fill),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                )
              : Builder(
                  builder: (context) {
                    return Image.file(File(image.path));
                  },
                ),
        ),
      ),
    );

    Widget content = imageContent;

    final bool showCropHandles = isSelected && selectionMode == SelectionMode.crop && dragCropRectPixels != null && image.size != null;

    if (showHandles) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: EdgeInsets.all(handlePadding), child: imageContent),
          ResizeHandle(
            handle: Handle.topLeft,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            top: 0,
            left: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
          ResizeHandle(
            handle: Handle.topCenter,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            top: 0,
            left: 0,
            right: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
          ResizeHandle(
            handle: Handle.topRight,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            top: 0,
            right: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
          ResizeHandle(
            handle: Handle.centerLeft,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            top: 0,
            left: 0,
            bottom: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
          ResizeHandle(
            handle: Handle.centerRight,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            top: 0,
            right: 0,
            bottom: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
          ResizeHandle(
            handle: Handle.bottomLeft,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            left: 0,
            bottom: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
          ResizeHandle(
            handle: Handle.bottomCenter,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            left: 0,
            right: 0,
            bottom: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
          ResizeHandle(
            handle: Handle.bottomRight,
            image: image,
            handleSize: handleSize,
            handleBorderSize: handleBorderSize,
            right: 0,
            bottom: 0,
            onPanStart: onResizePanStart,
            onPanUpdate: onResizePanUpdate,
            onPanEnd: onResizePanEnd,
          ),
        ],
      );
    } else if (showCropHandles) {
      final cropR = dragCropRectPixels!;
      final double cropMinDim = math.min(cropR.width, cropR.height);
      double handleLength = (minDim * Constants.cropOverlayLengthRatio).clamp(
        Constants.cropOverlayLengthMin,
        Constants.cropOverlayLengthMax,
      );
      handleLength = math.min(handleLength, cropMinDim / 3);
      final double handleThickness = math.max(Constants.cropOverlayThicknessMin, handleLength * Constants.cropOverlayThicknessRatio);
      final Color barrierColor = Colors.black.withValues(alpha: 0.85);

      content = Stack(
        clipBehavior: Clip.none,
        children: [
          imageContent,
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: cropR.top,
            child: Container(color: barrierColor),
          ),
          Positioned(
            top: cropR.bottom,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(color: barrierColor),
          ),
          Positioned(
            top: cropR.top,
            bottom: image.size!.height - cropR.bottom,
            left: 0,
            width: cropR.left,
            child: Container(color: barrierColor),
          ),
          Positioned(
            top: cropR.top,
            bottom: image.size!.height - cropR.bottom,
            right: 0,
            width: image.size!.width - cropR.right,
            child: Container(color: barrierColor),
          ),
          CropHandle(
            handle: Handle.topLeft,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
          CropHandle(
            handle: Handle.topCenter,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
          CropHandle(
            handle: Handle.topRight,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
          CropHandle(
            handle: Handle.centerLeft,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
          CropHandle(
            handle: Handle.centerRight,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
          CropHandle(
            handle: Handle.bottomLeft,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
          CropHandle(
            handle: Handle.bottomCenter,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
          CropHandle(
            handle: Handle.bottomRight,
            image: image,
            dragCropRectPixels: dragCropRectPixels!,
            thickness: handleThickness,
            length: handleLength,
            borderWidth: handleBorderSize,
            onPanStart: onCropPanStart,
            onPanUpdate: onCropPanUpdate,
            onPanEnd: onCropPanEnd,
          ),
        ],
      );
    }

    return Positioned(
      left: image.position.dx - handlePadding,
      top: image.position.dy - handlePadding,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onPanStart: onMovePanStart,
        onPanUpdate: onMovePanUpdate,
        child: content,
      ),
    );
  }
}
