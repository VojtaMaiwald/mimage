import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/utils/handle.dart';
import 'package:mimage/utils/selection_mode.dart';
import 'package:mimage/widgets/crop_handle_painter.dart';
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
  Rect? _originalCropRect;
  Offset? _dragRawPosition;
  Size? _dragRawSize;
  Rect? _dragCropRectPixels;
  double? _dragAspectRatio;
  Handle? _activeHandle;

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
      if (_selectedIndex != null && _dragCropRectPixels != null) {
        final image = _images[_selectedIndex!];
        if (image.size != null) {
          final double oldCW = image.cropRect?.width ?? 1.0;
          final double oldCH = image.cropRect?.height ?? 1.0;
          final double oldCL = image.cropRect?.left ?? 0.0;
          final double oldCT = image.cropRect?.top ?? 0.0;

          final double dx = _dragCropRectPixels!.left;
          final double dy = _dragCropRectPixels!.top;
          final double w = _dragCropRectPixels!.width;
          final double h = _dragCropRectPixels!.height;

          // New fractional crop rect
          final double fLeft = dx / image.size!.width;
          final double fTop = dy / image.size!.height;
          final double fRight = (dx + w) / image.size!.width;
          final double fBottom = (dy + h) / image.size!.height;

          image
            ..cropRect = Rect.fromLTRB(oldCL + fLeft * oldCW, oldCT + fTop * oldCH, oldCL + fRight * oldCW, oldCT + fBottom * oldCH)
            ..position = image.position + Offset(dx, dy)
            ..size = Size(w, h);
        }
      }

      _selectedIndex = null;
      _originalPosition = null;
      _originalSize = null;
      _originalCropRect = null;
      _dragCropRectPixels = null;
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
        _images[_selectedIndex!].cropRect = _originalCropRect;
      }
      _selectedIndex = null;
      _originalPosition = null;
      _originalSize = null;
      _originalCropRect = null;
      _dragCropRectPixels = null;
      _selectionMode = SelectionMode.move;
    });
  }

  Widget _buildHandle(
    Handle handle,
    CanvasImage image,
    int index,
    double handleSize,
    double handleBorderSize,
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
              _activeHandle = handle;
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
              _activeHandle = null;
            });
          },
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
    );
  }

  Widget _buildCropHandle(
    BuildContext context,
    Handle handle,
    CanvasImage image,
    int index,
    double thickness,
    double length,
    double borderWidth,
  ) {
    if (_dragCropRectPixels == null) {
      return const SizedBox();
    }
    final cropR = _dragCropRectPixels!;

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

    final double hitSize = length + 60.0; // Enlarge hit area
    final double halfHit = hitSize / 2;
    final Color handleColor = Theme.of(context).colorScheme.primary;
    // Using passed borderWidth directly instead of thickness / 2

    return Positioned(
      top: centerDy - halfHit,
      left: centerDx - halfHit,
      width: hitSize,
      height: hitSize,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (details) {
          setState(() {
            _activeHandle = handle;
            if (_dragCropRectPixels != null) {
              _dragAspectRatio = _dragCropRectPixels!.width / _dragCropRectPixels!.height;
            }
          });
        },
        onPanUpdate: (details) => onImagePanUpdate(image, details, index),
        onPanEnd: (_) {
          setState(() {
            _activeHandle = null;
          });
        },
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

  Widget stackItem(CanvasImage image, int index, BuildContext context, {required bool isSelected}) {
    final bool showHandles = isSelected && _selectionMode == SelectionMode.resize;

    // Dynamic handle and border sizing based on image dimension
    final double minDim = image.size != null ? math.min(image.size!.width, image.size!.height) : 200.0;
    final double handleSize = showHandles ? (minDim * 0.1).clamp(20.0, 100.0) : 0.0;
    final double handlePadding = showHandles ? handleSize / 2 : 0.0;
    final double borderWidth = isSelected ? (minDim * 0.02).clamp(5.0, 40.0) : 0.0;
    final double handleBorderSize = (minDim * 0.015).clamp(3.0, 15.0);

    final Widget imageContent = Listener(
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
              _originalSize = null;
              _originalCropRect = null;
              _dragCropRectPixels = null;
            } else {
              _selectedIndex = index;
              _originalPosition = image.position;
              _originalSize = image.size;
              _originalCropRect = image.cropRect;
              if (image.size != null) {
                _dragCropRectPixels = Rect.fromLTWH(0, 0, image.size!.width, image.size!.height);
              }

              if (image.size == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final BuildContext? imageContext = image.key.currentContext;
                  if (imageContext != null) {
                    final RenderBox? renderBox = imageContext.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      setState(() {
                        image.size = renderBox.size;
                        _originalSize = image.size;
                        if (_selectionMode == SelectionMode.crop) {
                          _dragCropRectPixels = Rect.fromLTWH(0, 0, image.size!.width, image.size!.height);
                        }
                      });
                    }
                  }
                });
              }
            }
          });
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
                    final crop = image.cropRect;
                    if (crop == null) {
                      return Image.file(File(image.path));
                    }
                    // For initial render without size, just render the image. The size will be caught next frame.
                    return Image.file(File(image.path));
                  },
                ),
        ),
      ),
    );

    Widget content = imageContent;

    final bool showCropHandles = isSelected && _selectionMode == SelectionMode.crop && _dragCropRectPixels != null && image.size != null;

    if (showHandles) {
      content = Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(padding: EdgeInsets.all(handlePadding), child: imageContent),
          _buildHandle(Handle.topLeft, image, index, handleSize, handleBorderSize, 0, 0, null, null),
          _buildHandle(Handle.topCenter, image, index, handleSize, handleBorderSize, 0, 0, 0, null),
          _buildHandle(Handle.topRight, image, index, handleSize, handleBorderSize, 0, null, 0, null),
          _buildHandle(Handle.centerLeft, image, index, handleSize, handleBorderSize, 0, 0, null, 0),
          _buildHandle(Handle.centerRight, image, index, handleSize, handleBorderSize, 0, null, 0, 0),
          _buildHandle(Handle.bottomLeft, image, index, handleSize, handleBorderSize, null, 0, null, 0),
          _buildHandle(Handle.bottomCenter, image, index, handleSize, handleBorderSize, null, 0, 0, 0),
          _buildHandle(Handle.bottomRight, image, index, handleSize, handleBorderSize, null, null, 0, 0),
        ],
      );
    } else if (showCropHandles) {
      final cropR = _dragCropRectPixels!;
      final double cropMinDim = math.min(cropR.width, cropR.height);
      double handleLength = (minDim * 0.2).clamp(20.0, 200.0);
      handleLength = math.min(handleLength, cropMinDim / 3);
      final double handleThickness = math.max(4.0, handleLength * 0.25);
      final Color barrierColor = Colors.black.withValues(alpha: 0.5);

      content = Stack(
        clipBehavior: Clip.none,
        children: [
          imageContent,
          // Barriers
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

          _buildCropHandle(context, Handle.topLeft, image, index, handleThickness, handleLength, handleBorderSize),
          _buildCropHandle(context, Handle.topCenter, image, index, handleThickness, handleLength, handleBorderSize),
          _buildCropHandle(context, Handle.topRight, image, index, handleThickness, handleLength, handleBorderSize),
          _buildCropHandle(context, Handle.centerLeft, image, index, handleThickness, handleLength, handleBorderSize),
          _buildCropHandle(context, Handle.centerRight, image, index, handleThickness, handleLength, handleBorderSize),
          _buildCropHandle(context, Handle.bottomLeft, image, index, handleThickness, handleLength, handleBorderSize),
          _buildCropHandle(context, Handle.bottomCenter, image, index, handleThickness, handleLength, handleBorderSize),
          _buildCropHandle(context, Handle.bottomRight, image, index, handleThickness, handleLength, handleBorderSize),
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
    } else if (_selectionMode == SelectionMode.resize && _activeHandle != null) {
      setState(() {
        if (_dragRawSize == null || _dragRawPosition == null || _originalSize == null || _originalSize!.height == 0) {
          return;
        }

        final bool isTop = _activeHandle!.isTop;
        final bool isBottom = _activeHandle!.isBottom;
        final bool isLeft = _activeHandle!.isLeft;
        final bool isRight = _activeHandle!.isRight;

        final bool prop = _activeHandle!.isCorner;

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
    } else if (_selectionMode == SelectionMode.crop && _activeHandle != null && _dragCropRectPixels != null) {
      setState(() {
        final bool isTop = _activeHandle!.isTop;
        final bool isBottom = _activeHandle!.isBottom;
        final bool isLeft = _activeHandle!.isLeft;
        final bool isRight = _activeHandle!.isRight;

        final bool prop = _activeHandle!.isCorner;
        final double ratio = _dragAspectRatio ?? (_dragCropRectPixels!.width / _dragCropRectPixels!.height);

        final double dx = details.delta.dx;
        final double dy = details.delta.dy;

        double cropL = _dragCropRectPixels!.left;
        double cropT = _dragCropRectPixels!.top;
        double cropR = _dragCropRectPixels!.right;
        double cropB = _dragCropRectPixels!.bottom;

        if (isRight) {
          cropR += dx;
        }
        if (isLeft) {
          cropL += dx;
        }
        if (isBottom) {
          cropB += dy;
        }
        if (isTop) {
          cropT += dy;
        }

        double cropW = cropR - cropL;
        double cropH = cropB - cropT;

        if (prop) {
          // Project Unconstrained dimension to original aspect ratio line
          final double dot = cropW * ratio + cropH * 1.0;
          final double lenSq = ratio * ratio + 1.0;
          final double t = dot / lenSq;

          final double newW = t * ratio;
          final double newH = t * 1.0;

          if (isLeft) {
            cropL += cropW - newW;
          }
          if (isTop) {
            cropT += cropH - newH;
          }

          cropW = newW;
          cropH = newH;
          cropR = cropL + cropW;
          cropB = cropT + cropH;
        }

        // Clamp inside the original image bounding box (0,0, image.size.width, image.size.height)
        if (cropL < 0) {
          cropL = 0;
        }
        if (cropT < 0) {
          cropT = 0;
        }
        if (cropR > image.size!.width) {
          cropR = image.size!.width;
        }
        if (cropB > image.size!.height) {
          cropB = image.size!.height;
        }

        if (isLeft) {
          cropW = cropR - cropL;
        }
        if (isRight) {
          cropW = cropR - cropL;
        }
        if (isTop) {
          cropH = cropB - cropT;
        }
        if (isBottom) {
          cropH = cropB - cropT;
        }

        // Ensure aspect ratio holds after clamping if prop is true
        if (prop) {
          if (cropW / ratio > cropH) {
            cropW = cropH * ratio;
            if (isLeft) {
              cropL = cropR - cropW;
            } else {
              cropR = cropL + cropW;
            }
          } else {
            cropH = cropW / ratio;
            if (isTop) {
              cropT = cropB - cropH;
            } else {
              cropB = cropT + cropH;
            }
          }
        }

        // enforce min width
        if (cropW < 20) {
          if (isLeft) {
            cropL = cropR - 20;
          } else {
            cropR = cropL + 20;
          }
        }
        if (cropH < 20) {
          if (isTop) {
            cropT = cropB - 20;
          } else {
            cropB = cropT + 20;
          }
        }

        _dragCropRectPixels = Rect.fromLTRB(cropL, cropT, cropR, cropB);
      });
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
                        style: SegmentedButton.styleFrom(backgroundColor: Theme.of(context).scaffoldBackgroundColor),
                        segments: SelectionMode.values.map((mode) {
                          return ButtonSegment(value: mode, icon: Icon(mode.icon), label: Text(mode.description));
                        }).toList(),
                        selected: {_selectionMode},
                        onSelectionChanged: (Set newSelection) {
                          setState(() {
                            _selectionMode = newSelection.first;
                            if (_selectionMode == SelectionMode.crop && _selectedIndex != null) {
                              final image = _images[_selectedIndex!];
                              if (image.size != null) {
                                _dragCropRectPixels = Rect.fromLTWH(0, 0, image.size!.width, image.size!.height);
                              }
                            } else {
                              _dragCropRectPixels = null;
                            }
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
