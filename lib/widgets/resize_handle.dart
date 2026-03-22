import 'package:flutter/material.dart';
import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/utils/constants.dart';
import 'package:mimage/utils/handle.dart';

class ResizeHandle extends StatelessWidget {
  const ResizeHandle({
    required this.handle,
    required this.image,
    required this.handleSize,
    required this.handleBorderSize,
    required this.onPanStart,
    required this.onPanEnd,
    required this.onPanUpdate,
    this.top,
    this.left,
    this.right,
    this.bottom,
    super.key,
  });

  final Handle handle;
  final CanvasImage image;
  final double handleSize;
  final double handleBorderSize;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final void Function(Handle handle, CanvasImage image) onPanStart;
  final void Function() onPanEnd;
  final void Function(DragUpdateDetails details) onPanUpdate;

  @override
  Widget build(BuildContext context) {
    final double? pTop = (top == 0 && bottom != 0) ? -Constants.hitboxPadding : top;
    final double? pBottom = (bottom == 0 && top != 0) ? -Constants.hitboxPadding : bottom;
    final double? pLeft = (left == 0 && right != 0) ? -Constants.hitboxPadding : left;
    final double? pRight = (right == 0 && left != 0) ? -Constants.hitboxPadding : right;

    return Positioned(
      top: pTop,
      left: pLeft,
      right: pRight,
      bottom: pBottom,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => onPanStart(handle, image),
          onPanUpdate: onPanUpdate,
          onPanEnd: (_) => onPanEnd(),
          child: Container(
            padding: const EdgeInsets.all(Constants.hitboxPadding),
            color: Colors.transparent,
            child: Container(
              width: handleSize,
              height: handleSize,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: handleBorderSize),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
