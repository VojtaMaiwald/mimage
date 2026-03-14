import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/widgets/direction_arrow.dart';

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
  Offset? _dragRawPosition;

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

  Widget stackItem(CanvasImage image, int index, BuildContext context, {required bool isSelected}) {
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
          if (_lastPointerDown != null && event.pointer == _lastPointerDown!.pointer && event.position == _lastPointerDown!.position) {
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
          onPanStart: isSelected ? (details) => _dragRawPosition = image.position : null,
          onPanUpdate: isSelected ? (details) => onImagePanUpdate(image, details, index) : null,
          child: DecoratedBox(
            key: image.key,
            decoration: isSelected
                ? BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary, width: 4.0))
                : const BoxDecoration(),
            child: IgnorePointer(ignoring: _selectedIndex != null && !isSelected, child: Image.file(File(image.path))),
          ),
        ),
      ),
    );
  }

  void onImagePanUpdate(CanvasImage image, DragUpdateDetails details, int index) {
    return setState(() {
      _dragRawPosition = (_dragRawPosition ?? image.position) + details.delta;
      Offset newPosition = _dragRawPosition!;

      final myContext = image.key.currentContext;
      if (myContext != null) {
        final myRenderBox = myContext.findRenderObject() as RenderBox?;
        if (myRenderBox != null) {
          final mySize = myRenderBox.size;
          final double snapDist = 20.0 / _transformationController.value.getMaxScaleOnAxis();

          double? bestDx;
          double? bestDy;
          double minDiffX = snapDist;
          double minDiffY = snapDist;

          for (var i = 0; i < _images.length; i++) {
            if (i == index) {
              continue;
            }
            final otherImage = _images[i];
            final otherContext = otherImage.key.currentContext;
            if (otherContext != null) {
              final otherRenderBox = otherContext.findRenderObject() as RenderBox?;
              if (otherRenderBox != null) {
                final otherSize = otherRenderBox.size;

                final myLeft = newPosition.dx;
                final myRight = newPosition.dx + mySize.width;
                final myTop = newPosition.dy;
                final myBottom = newPosition.dy + mySize.height;

                final otherLeft = otherImage.position.dx;
                final otherRight = otherImage.position.dx + otherSize.width;
                final otherTop = otherImage.position.dy;
                final otherBottom = otherImage.position.dy + otherSize.height;

                final xCandidates = {
                  otherLeft - mySize.width: (myRight - otherLeft).abs(), // My right to other left
                  otherRight: (myLeft - otherRight).abs(), // My left to other right
                  otherLeft: (myLeft - otherLeft).abs(), // My left to other left
                  otherRight - mySize.width: (myRight - otherRight).abs(), // My right to other right
                };

                for (final entry in xCandidates.entries) {
                  if (entry.value < minDiffX) {
                    minDiffX = entry.value;
                    bestDx = entry.key;
                  }
                }

                final yCandidates = {
                  otherTop - mySize.height: (myBottom - otherTop).abs(), // My bottom to other top
                  otherBottom: (myTop - otherBottom).abs(), // My top to other bottom
                  otherTop: (myTop - otherTop).abs(), // My top to other top
                  otherBottom - mySize.height: (myBottom - otherBottom).abs(), // My bottom to other bottom
                };

                for (final entry in yCandidates.entries) {
                  if (entry.value < minDiffY) {
                    minDiffY = entry.value;
                    bestDy = entry.key;
                  }
                }
              }
            }
          }

          if (bestDx != null) {
            newPosition = Offset(bestDx, newPosition.dy);
          }
          if (bestDy != null) {
            newPosition = Offset(newPosition.dx, bestDy);
          }
        }
      }

      image.position = newPosition;
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
                minScale: 0.01,
                maxScale: 20.0,
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

                      return stackItem(image, index, context, isSelected: isSelected);
                    }).toList(),
                  ),
                ),
              ),
              DirectionArrow(transformationController: _transformationController, images: _images, constraints: constraints),
              if (_selectedIndex != null)
                Positioned(
                  top: 16.0,
                  left: 16.0,
                  right: 16.0,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FloatingActionButton(
                          heroTag: 'declineBtn',
                          onPressed: _declineChanges,
                          backgroundColor: Colors.redAccent,
                          child: const Icon(Icons.close, color: Colors.white),
                        ),
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
