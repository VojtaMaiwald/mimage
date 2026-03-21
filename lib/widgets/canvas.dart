import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/utils/resize_handle.dart';
import 'package:mimage/utils/selection_mode.dart';
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
  SelectionMode _selectionMode = SelectionMode.move;
  Offset? _originalPosition;
  Size? _originalSize;
  Offset? _dragRawPosition;
  Size? _dragRawSize;
  double? _dragAspectRatio;
  ResizeHandle? _activeResizeHandle;

  PointerDownEvent? _lastPointerDown;

  @override
  void initState() {
    super.initState();
    // Center the viewport on the large canvas
    final Matrix4 initialOffset = Matrix4.translationValues(-canvasSize / 2 + 200, -canvasSize / 2 + 300, 0);
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
      _originalSize = null;
      _selectionMode = SelectionMode.move;
    });
  }

  void _declineChanges() {
    setState(() {
      if (_selectedIndex != null) {
        if (_originalPosition != null) {
          _images[_selectedIndex!].position = _originalPosition!;
        }
        if (_originalSize != null) {
          _images[_selectedIndex!].size = _originalSize;
        }
      }
      _selectedIndex = null;
      _originalPosition = null;
      _originalSize = null;
      _selectionMode = SelectionMode.move;
    });
  }

  Widget _buildResizeHandle(
    ResizeHandle handle,
    CanvasImage image,
    int index,
    double handleSize,
    double? top,
    double? left,
    double? right,
    double? bottom,
  ) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            setState(() {
              _activeResizeHandle = handle;
              _dragRawPosition = image.position;
              _dragRawSize = image.size;

              if (image.size == null) {
                final BuildContext? imageContext = image.key.currentContext;
                if (imageContext != null) {
                  final RenderBox? renderBox = imageContext.findRenderObject() as RenderBox?;
                  if (renderBox != null) {
                    _dragRawSize = renderBox.size;
                    image.size = _dragRawSize;
                  }
                }
              }
              if (_dragRawSize != null && _dragRawSize!.height != 0) {
                _dragAspectRatio = _dragRawSize!.width / _dragRawSize!.height;
              }
            });
          },
          onPanUpdate: (details) => onImagePanUpdate(image, details, index),
          onPanEnd: (_) {
            setState(() {
              _activeResizeHandle = null;
            });
          },
          child: Container(
            width: handleSize,
            height: handleSize,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: math.max(2.0, handleSize * 0.1)),
            ),
          ),
        ),
      ),
    );
  }

  Widget stackItem(CanvasImage image, int index, BuildContext context, {required bool isSelected}) {
    final bool showResizeHandles = isSelected && _selectionMode == SelectionMode.resize;

    // Dynamic handle and border sizing based on image dimension
    final double minDim = image.size != null ? math.min(image.size!.width, image.size!.height) : 200.0;
    final double handleSize = showResizeHandles ? (minDim * 0.1).clamp(20.0, 100.0) : 0.0;
    final double handlePadding = showResizeHandles ? handleSize / 2 : 0.0;
    final double borderWidth = isSelected ? (minDim * 0.02).clamp(5.0, 40.0) : 0.0;

    final Widget imageContent = Listener(
      onPointerDown: (event) {
        setState(() {
          _lastPointerDown = event;
        });
      },
      onPointerUp: (event) {
        if (_selectionMode == SelectionMode.move || _selectionMode == SelectionMode.resize) {
          if (_lastPointerDown != null && event.pointer == _lastPointerDown!.pointer && event.position == _lastPointerDown!.position) {
            setState(() {
              if (_selectedIndex == index) {
                _selectedIndex = null;
                _originalPosition = null;
                _originalSize = null;
              } else {
                _selectedIndex = index;
                _originalPosition = image.position;
                _originalSize = image.size;

                if (image.size == null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    final BuildContext? imageContext = image.key.currentContext;
                    if (imageContext != null) {
                      final RenderBox? renderBox = imageContext.findRenderObject() as RenderBox?;
                      if (renderBox != null) {
                        setState(() {
                          image.size = renderBox.size;
                          _originalSize = image.size;
                        });
                      }
                    }
                  });
                }
              }
            });
          }
        }
      },
      child: DecoratedBox(
        key: image.key,
        position: DecorationPosition.foreground,
        decoration: isSelected
            ? BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.primary, width: borderWidth),
              )
            : const BoxDecoration(),
        child: IgnorePointer(
          ignoring: _selectedIndex != null && !isSelected,
          child: image.size != null
              ? SizedBox(
                  width: image.size!.width,
                  height: image.size!.height,
                  child: Image.file(File(image.path), fit: BoxFit.fill),
                )
              : Image.file(File(image.path)),
        ),
      ),
    );

    Widget content = imageContent;

    if (showResizeHandles) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: EdgeInsets.all(handlePadding), child: imageContent),
          _buildResizeHandle(ResizeHandle.topLeft, image, index, handleSize, 0, 0, null, null),
          _buildResizeHandle(ResizeHandle.topCenter, image, index, handleSize, 0, 0, 0, null),
          _buildResizeHandle(ResizeHandle.topRight, image, index, handleSize, 0, null, 0, null),
          _buildResizeHandle(ResizeHandle.centerLeft, image, index, handleSize, 0, 0, null, 0),
          _buildResizeHandle(ResizeHandle.centerRight, image, index, handleSize, 0, null, 0, 0),
          _buildResizeHandle(ResizeHandle.bottomLeft, image, index, handleSize, null, 0, null, 0),
          _buildResizeHandle(ResizeHandle.bottomCenter, image, index, handleSize, null, 0, 0, 0),
          _buildResizeHandle(ResizeHandle.bottomRight, image, index, handleSize, null, null, 0, 0),
        ],
      );
    }

    return Positioned(
      left: image.position.dx - handlePadding,
      top: image.position.dy - handlePadding,
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onPanStart: isSelected && _selectionMode == SelectionMode.move ? (details) => _dragRawPosition = image.position : null,
        onPanUpdate: isSelected && _selectionMode == SelectionMode.move ? (details) => onImagePanUpdate(image, details, index) : null,
        child: content,
      ),
    );
  }

  void onImagePanUpdate(CanvasImage image, DragUpdateDetails details, int index) {
    if (_selectionMode == SelectionMode.move) {
      setState(() {
        _dragRawPosition = (_dragRawPosition ?? image.position) + details.delta;
        Offset newPosition = _dragRawPosition!;

        final BuildContext? imageContext = image.key.currentContext;
        if (imageContext != null) {
          final RenderBox? myRenderBox = imageContext.findRenderObject() as RenderBox?;
          if (myRenderBox != null) {
            final Size mySize = myRenderBox.size;
            final double snapDist = 20.0 / _transformationController.value.getMaxScaleOnAxis();

            double? bestDx;
            double? bestDy;
            double minDiffX = snapDist;
            double minDiffY = snapDist;

            for (final CanvasImage otherImage in _images) {
              if (otherImage == image) {
                continue;
              }
              final BuildContext? otherImageContext = otherImage.key.currentContext;
              if (otherImageContext != null) {
                final RenderBox? otherRenderBox = otherImageContext.findRenderObject() as RenderBox?;
                if (otherRenderBox != null) {
                  final Size otherSize = otherRenderBox.size;

                  final double myLeft = newPosition.dx;
                  final double myRight = newPosition.dx + mySize.width;
                  final double myTop = newPosition.dy;
                  final double myBottom = newPosition.dy + mySize.height;

                  final double otherLeft = otherImage.position.dx;
                  final double otherRight = otherImage.position.dx + otherSize.width;
                  final double otherTop = otherImage.position.dy;
                  final double otherBottom = otherImage.position.dy + otherSize.height;

                  final Map<double, double> xCandidates = {
                    otherLeft - mySize.width: (myRight - otherLeft).abs(), // My right to other left
                    otherRight: (myLeft - otherRight).abs(), // My left to other right
                    otherLeft: (myLeft - otherLeft).abs(), // My left to other left
                    otherRight - mySize.width: (myRight - otherRight).abs(), // My right to other right
                  };

                  for (final MapEntry<double, double> entry in xCandidates.entries) {
                    if (entry.value < minDiffX) {
                      minDiffX = entry.value;
                      bestDx = entry.key;
                    }
                  }

                  final Map<double, double> yCandidates = {
                    otherTop - mySize.height: (myBottom - otherTop).abs(), // My bottom to other top
                    otherBottom: (myTop - otherBottom).abs(), // My top to other bottom
                    otherTop: (myTop - otherTop).abs(), // My top to other top
                    otherBottom - mySize.height: (myBottom - otherBottom).abs(), // My bottom to other bottom
                  };

                  for (final MapEntry<double, double> entry in yCandidates.entries) {
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
    } else if (_selectionMode == SelectionMode.resize && _activeResizeHandle != null) {
      setState(() {
        if (_dragRawSize == null || _dragRawPosition == null || _originalSize == null || _originalSize!.height == 0) {
          return;
        }

        final bool isTop = _activeResizeHandle!.isTop;
        final bool isBottom = _activeResizeHandle!.isBottom;
        final bool isLeft = _activeResizeHandle!.isLeft;
        final bool isRight = _activeResizeHandle!.isRight;

        final bool prop = _activeResizeHandle!.isCorner;

        // Use aspect ratio captured at start of the drag, fallback to original if missing
        final double ratio = _dragAspectRatio ?? (_originalSize!.width / _originalSize!.height);

        final double dx = details.delta.dx;
        final double dy = details.delta.dy;

        // Iteratively accumulate unconstrained drag delta
        if (isRight) {
          _dragRawSize = Size(_dragRawSize!.width + dx, _dragRawSize!.height);
        }
        if (isLeft) {
          _dragRawSize = Size(_dragRawSize!.width - dx, _dragRawSize!.height);
          _dragRawPosition = Offset(_dragRawPosition!.dx + dx, _dragRawPosition!.dy);
        }
        if (isBottom) {
          _dragRawSize = Size(_dragRawSize!.width, _dragRawSize!.height + dy);
        }
        if (isTop) {
          _dragRawSize = Size(_dragRawSize!.width, _dragRawSize!.height - dy);
          _dragRawPosition = Offset(_dragRawPosition!.dx, _dragRawPosition!.dy + dy);
        }

        double rawW = _dragRawSize!.width;
        double rawH = _dragRawSize!.height;
        double rawL = _dragRawPosition!.dx;
        double rawT = _dragRawPosition!.dy;

        if (prop) {
          // Treat the original aspect ratio as a 2D line starting from 0,0
          // Project the cursor's unconstrained new dimension (rawW, rawH) onto this line
          // Vector A = (ratio, 1.0) and Vector B = (rawW, rawH)
          final double dot = rawW * ratio + rawH * 1.0;
          final double lenSq = ratio * ratio + 1.0;
          final double t = dot / lenSq;

          double newW = t * ratio;
          double newH = t * 1.0;

          // Handle clamping downscale beyond 20px while preserving ratio
          if (newW < 20 || newH < 20) {
            if (newW < 20) {
              newW = 20;
              newH = 20 / ratio;
            }
            if (newH < 20) {
              newH = 20;
              newW = 20 * ratio;
            }
          }

          // Adjust position iteratively
          if (isLeft) {
            rawL += rawW - newW;
          }
          if (isTop) {
            rawT += rawH - newH;
          }

          rawW = newW;
          rawH = newH;
        } else {
          // Check manual free-stretch min boundary
          if (rawW < 20) {
            if (isLeft) {
              rawL -= 20 - rawW;
            }
            rawW = 20;
          }
          if (rawH < 20) {
            if (isTop) {
              rawT -= 20 - rawH;
            }
            rawH = 20;
          }
        }

        final double snapDist = 20.0 / _transformationController.value.getMaxScaleOnAxis();
        double? bestEdgeX;
        double? bestEdgeY;
        double minDiffX = snapDist;
        double minDiffY = snapDist;

        for (var i = 0; i < _images.length; i++) {
          if (i == index) {
            continue;
          }
          final otherImage = _images[i];
          final BuildContext? otherImageContext = otherImage.key.currentContext;
          if (otherImageContext != null) {
            final RenderBox? otherRenderBox = otherImageContext.findRenderObject() as RenderBox?;
            if (otherRenderBox != null) {
              final Size otherSize = otherRenderBox.size;
              final double otherLeft = otherImage.position.dx;
              final double otherRight = otherImage.position.dx + otherSize.width;
              final double otherTop = otherImage.position.dy;
              final double otherBottom = otherImage.position.dy + otherSize.height;

              final double myRight = rawL + rawW;
              final double myBottom = rawT + rawH;

              final Map<double, double> xCandidates = {};
              if (isRight) {
                xCandidates[otherLeft] = (myRight - otherLeft).abs();
                xCandidates[otherRight] = (myRight - otherRight).abs();
              } else if (isLeft) {
                xCandidates[otherLeft] = (rawL - otherLeft).abs();
                xCandidates[otherRight] = (rawL - otherRight).abs();
              }

              for (final entry in xCandidates.entries) {
                if (entry.value < minDiffX) {
                  minDiffX = entry.value;
                  bestEdgeX = entry.key;
                }
              }

              final Map<double, double> yCandidates = {};
              if (isBottom) {
                yCandidates[otherTop] = (myBottom - otherTop).abs();
                yCandidates[otherBottom] = (myBottom - otherBottom).abs();
              } else if (isTop) {
                yCandidates[otherTop] = (rawT - otherTop).abs();
                yCandidates[otherBottom] = (rawT - otherBottom).abs();
              }

              for (final entry in yCandidates.entries) {
                if (entry.value < minDiffY) {
                  minDiffY = entry.value;
                  bestEdgeY = entry.key;
                }
              }
            }
          }
        }

        if (prop && bestEdgeX != null && bestEdgeY != null) {
          if (minDiffX < minDiffY) {
            bestEdgeY = null;
          } else {
            bestEdgeX = null;
          }
        }

        if (bestEdgeX != null) {
          if (isRight) {
            rawW = bestEdgeX - rawL;
          } else if (isLeft) {
            rawW = (rawL + rawW) - bestEdgeX;
            rawL = bestEdgeX;
          }
          if (prop) {
            final double oldH = rawH;
            rawH = rawW / ratio;
            if (isTop) {
              rawT += oldH - rawH;
            }
            bestEdgeY = null;
          }
        }

        if (bestEdgeY != null) {
          if (isBottom) {
            rawH = bestEdgeY - rawT;
          } else if (isTop) {
            rawH = (rawT + rawH) - bestEdgeY;
            rawT = bestEdgeY;
          }
          if (prop) {
            final double oldW = rawW;
            rawW = rawH * ratio;
            if (isLeft) {
              rawL += oldW - rawW;
            }
          }
        }

        // Apply
        image
          ..position = Offset(rawL, rawT)
          ..size = Size(rawW, rawH);
      });
    } else if (_selectionMode == SelectionMode.crop) {
      // Placeholder for future crop logic
    }
  }

  Widget? _fab() {
    if (_selectedIndex == null) {
      return FloatingActionButton(onPressed: _pickImage, tooltip: 'Pick Image', child: const Icon(Icons.add_photo_alternate));
    }
    return null;
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
              if (_selectedIndex != null)
                Positioned(
                  bottom: 16.0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Center(
                      child: SegmentedButton<SelectionMode>(
                        segments: SelectionMode.values.map((mode) {
                          return ButtonSegment(value: mode, icon: Icon(mode.icon), label: Text(mode.description));
                        }).toList(),
                        selected: {_selectionMode},
                        onSelectionChanged: (Set newSelection) {
                          setState(() {
                            _selectionMode = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: _fab(),
    );
  }
}
