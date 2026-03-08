import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CanvasImage {
  CanvasImage({required this.path, this.position = Offset.zero});
  final String path;
  Offset position;
}

class Canvas extends StatefulWidget {
  const Canvas({super.key});

  @override
  State<Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<Canvas> {
  final List<CanvasImage> _images = [];
  final ImagePicker _picker = ImagePicker();
  final double canvasSize = 10000.0;
  final TransformationController _transformationController = TransformationController();

  int? _selectedIndex;
  Offset? _originalPosition;

  PointerDownEvent? _lastPointerDown;

  @override
  void initState() {
    super.initState();
    // Center the viewport on the large canvas
    final initialOffset = Matrix4.translationValues(-canvasSize / 2 + 200, -canvasSize / 2 + 300, 0);
    _transformationController.value = initialOffset;
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        // Place new images roughly where the camera is initially looking
        _images.add(CanvasImage(path: image.path, position: Offset(canvasSize / 2, canvasSize / 2)));
      });
    }
  }

  void _acceptChanges() {
    setState(() {
      _selectedIndex = null;
      _originalPosition = null;
    });
  }

  void _declineChanges() {
    setState(() {
      if (_selectedIndex != null && _originalPosition != null) {
        _images[_selectedIndex!].position = _originalPosition!;
      }
      _selectedIndex = null;
      _originalPosition = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(double.infinity),

                minScale: 0.1,
                maxScale: 10.0,
                constrained: false,
                panEnabled: _selectedIndex == null,
                child: SizedBox(
                  width: canvasSize,
                  height: canvasSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: _images.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final CanvasImage image = entry.value;
                      final bool isSelected = _selectedIndex == index;

                      return Positioned(
                        left: image.position.dx,
                        top: image.position.dy,
                        child: Listener(
                          onPointerDown: (event) {
                            setState(() {
                              _lastPointerDown = event;
                            });
                          },
                          onPointerUp: (event) {
                            if (_lastPointerDown != null &&
                                event.pointer == _lastPointerDown!.pointer &&
                                event.position == _lastPointerDown!.position) {
                              setState(() {
                                if (_selectedIndex == index) {
                                  _selectedIndex = null;
                                  _originalPosition = null;
                                } else {
                                  _selectedIndex = index;
                                  _originalPosition = image.position;
                                }
                              });
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.deferToChild,
                            onPanUpdate: isSelected
                                ? (details) {
                                    setState(() {
                                      image.position += details.delta;
                                    });
                                  }
                                : null,
                            child: DecoratedBox(
                              decoration: isSelected
                                  ? BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4.0))
                                  : const BoxDecoration(),
                              child: IgnorePointer(ignoring: _selectedIndex != null && !isSelected, child: Image.file(File(image.path))),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _transformationController,
                builder: (context, child) {
                  if (_images.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  double cx = 0;
                  double cy = 0;
                  for (final img in _images) {
                    cx += img.position.dx;
                    cy += img.position.dy;
                  }
                  cx /= _images.length;
                  cy /= _images.length;

                  // Approximate center offset since images are drawn from top-left.
                  cx += 200;
                  cy += 200;

                  final matrix = _transformationController.value;
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
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Transform.rotate(
                        angle: angle,
                        child: Icon(
                          Icons.arrow_forward,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                          shadows: const [Shadow(color: Colors.white, blurRadius: 10)],
                        ),
                      ),
                    ),
                  );
                },
              ),
              if (_selectedIndex != null)
                Positioned(
                  top: 16.0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton(
                          heroTag: 'declineBtn',
                          onPressed: _declineChanges,
                          backgroundColor: Colors.redAccent,
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
                        const SizedBox(width: 32),
                        FloatingActionButton(
                          heroTag: 'acceptBtn',
                          onPressed: _acceptChanges,
                          backgroundColor: Colors.green,
                          child: const Icon(Icons.check, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _selectedIndex == null
          ? SafeArea(
              child: FloatingActionButton(onPressed: _pickImage, tooltip: 'Pick Image', child: const Icon(Icons.add_photo_alternate)),
            )
          : null,
    );
  }
}
