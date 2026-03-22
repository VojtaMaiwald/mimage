import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mimage/utils/canvas_image.dart';

class DirectionArrow extends StatelessWidget {
  const DirectionArrow({required this.transformationController, required this.images, required this.constraints, super.key});

  final TransformationController transformationController;
  final List<CanvasImage> images;
  final BoxConstraints constraints;

  double get _arrowSize => 96.0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: transformationController,
      builder: (context, child) {
        if (images.isEmpty) {
          return const SizedBox.shrink();
        }

        double cx = 0;
        double cy = 0;
        for (final img in images) {
          cx += img.position.dx;
          cy += img.position.dy;
        }
        cx /= images.length;
        cy /= images.length;

        // Approximate center offset since images are drawn from top-left.
        cx += 200;
        cy += 200;

        final matrix = transformationController.value;
        final scale = matrix.getMaxScaleOnAxis();
        final tx = matrix.getTranslation().x;
        final ty = matrix.getTranslation().y;

        final screenX = cx * scale + tx;
        final screenY = cy * scale + ty;

        final vw = constraints.maxWidth;
        final vh = constraints.maxHeight;

        final double height = MediaQuery.sizeOf(context).height;
        final double width = MediaQuery.sizeOf(context).width;

        // Off-screen check (within bounds + margin)
        if (screenX >= -(width / 2) && screenX <= vw + (width / 2) && screenY >= -(height / 2) && screenY <= vh + (height / 2)) {
          return const SizedBox.shrink();
        }

        final vx = vw / 2;
        final vy = vh / 2;
        final dx = screenX - vx;
        final dy = screenY - vy;
        final angle = math.atan2(dy, dx);

        return Align(
          child: Transform.rotate(
            angle: angle,
            child: Padding(
              padding: EdgeInsets.only(left: MediaQuery.sizeOf(context).shortestSide - _arrowSize),
              child: Icon(
                Icons.keyboard_double_arrow_right_rounded,
                size: _arrowSize,
                color: Theme.of(context).colorScheme.primary,
                //shadows: const [Shadow(color: Colors.white, blurRadius: 10)],
              ),
            ),
          ),
        );
      },
    );
  }
}
