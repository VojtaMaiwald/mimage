import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/utils/constants.dart';
import 'package:mimage/utils/handle.dart';
import 'package:mimage/utils/image_export.dart';
import 'package:mimage/utils/pan_utils.dart';
import 'package:mimage/utils/selection_mode.dart';
import 'package:mimage/widgets/direction_arrow.dart';
import 'package:mimage/widgets/export_overlay.dart';
import 'package:mimage/widgets/image_item.dart';

class Canvas extends StatefulWidget {
  const Canvas({super.key});

  @override
  State<Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<Canvas> {
  final List<CanvasImage> _images = [];
  final ImagePicker _picker = ImagePicker();
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

  bool _isExportMode = false;
  Rect? _exportRectPixels;
  Rect? _dragRawExportRect;

  @override
  void initState() {
    super.initState();
    final Matrix4 initialOffset = Matrix4.translationValues(-Constants.canvasSize / 2 + 200, -Constants.canvasSize / 2 + 300, 0);
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
        _images.add(CanvasImage(path: image.path, position: const Offset(Constants.canvasSize / 2, Constants.canvasSize / 2)));
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

  Future<void> _handleExportImage(bool isPng) async {
    if (_exportRectPixels == null) {
      return;
    }

    final String? savePath = await exportCanvasImages(isPng: isPng, exportRectPixels: _exportRectPixels!, images: _images);

    if (savePath != null && savePath.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved to $savePath')));
    }

    setState(() {
      _isExportMode = false;
      _exportRectPixels = null;
    });
  }

  void _onImagePointerDown(PointerDownEvent event) {
    setState(() {
      _lastPointerDown = event;
    });
  }

  void _onImagePointerUp(PointerUpEvent event, CanvasImage image, int index) {
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
  }

  Widget? _fab() {
    if (_selectedIndex == null && !_isExportMode) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_images.isNotEmpty) ...[
            FloatingActionButton.extended(
              onPressed: () {
                setState(() {
                  _isExportMode = true;
                  if (_images.isNotEmpty) {
                    double minX = double.infinity;
                    double minY = double.infinity;
                    double maxX = double.negativeInfinity;
                    double maxY = double.negativeInfinity;
                    for (final img in _images) {
                      if (img.size == null) {
                        continue;
                      }
                      final left = img.position.dx;
                      final top = img.position.dy;
                      final right = left + img.size!.width;
                      final bottom = top + img.size!.height;
                      if (left < minX) {
                        minX = left;
                      }
                      if (top < minY) {
                        minY = top;
                      }
                      if (right > maxX) {
                        maxX = right;
                      }
                      if (bottom > maxY) {
                        maxY = bottom;
                      }
                    }
                    if (minX != double.infinity) {
                      _exportRectPixels = Rect.fromLTRB(minX, minY, maxX, maxY);
                    } else {
                      final mat = _transformationController.value;
                      final scale = mat.getMaxScaleOnAxis();
                      final dx = -mat.row0[3] / scale;
                      final dy = -mat.row1[3] / scale;
                      _exportRectPixels = Rect.fromLTWH(dx + 100.0 / scale, dy + 100.0 / scale, 500.0 / scale, 500.0 / scale);
                    }
                  }
                });
              },
              icon: const Icon(Icons.download),
              label: const Text('Export'),
              heroTag: 'export',
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton.extended(
            onPressed: _pickImage,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Add Image'),
            heroTag: 'add',
          ),
        ],
      );
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
                minScale: Constants.minScale,
                maxScale: Constants.maxScale,
                constrained: false,
                panEnabled: _selectedIndex == null,
                child: SizedBox(
                  width: Constants.canvasSize,
                  height: Constants.canvasSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      ..._images.asMap().entries.map((entry) {
                        final int index = entry.key;
                        final CanvasImage image = entry.value;
                        final bool isSelected = _selectedIndex == index;

                        return ImageItem(
                          image: image,
                          index: index,
                          isSelected: isSelected,
                          selectionMode: _selectionMode,
                          dragCropRectPixels: _dragCropRectPixels,
                          onPointerDown: _onImagePointerDown,
                          onPointerUp: (event) => _onImagePointerUp(event, image, index),
                          onResizePanStart: (handle, img) {
                            setState(() {
                              _activeHandle = handle;
                              _dragRawPosition = img.position;
                              _dragRawSize = img.size;
                              if (img.size == null) {
                                final BuildContext? imageContext = img.key.currentContext;
                                if (imageContext != null) {
                                  final RenderBox? renderBox = imageContext.findRenderObject() as RenderBox?;
                                  if (renderBox != null) {
                                    _dragRawSize = renderBox.size;
                                    img.size = _dragRawSize;
                                  }
                                }
                              }
                              if (_dragRawSize != null && _dragRawSize!.height != 0) {
                                _dragAspectRatio = _dragRawSize!.width / _dragRawSize!.height;
                              }
                            });
                          },
                          onResizePanUpdate: (details) {
                            setState(() {
                              if (_dragRawSize == null ||
                                  _dragRawPosition == null ||
                                  _originalSize == null ||
                                  _originalSize!.height == 0 ||
                                  _activeHandle == null) {
                                return;
                              }
                              final double ratio = _dragAspectRatio ?? (_originalSize!.width / _originalSize!.height);
                              final snapDist = Constants.snapDistanceBase / _transformationController.value.getMaxScaleOnAxis();

                              final result = PanUtils.calculateImageResize(
                                dragRawPosition: _dragRawPosition!,
                                dragRawSize: _dragRawSize!,
                                delta: details.delta,
                                activeHandle: _activeHandle!,
                                ratio: ratio,
                                images: _images,
                                currentIndex: index,
                                snapDist: snapDist,
                              );

                              _dragRawPosition = result.rawPosition;
                              _dragRawSize = result.rawSize;

                              image
                                ..position = Offset(result.snappedRect.left, result.snappedRect.top)
                                ..size = result.snappedSize;
                            });
                          },
                          onResizePanEnd: () {
                            setState(() {
                              _activeHandle = null;
                            });
                          },
                          onCropPanStart: (handle) {
                            setState(() {
                              _activeHandle = handle;
                              if (_dragCropRectPixels != null) {
                                _dragAspectRatio = _dragCropRectPixels!.width / _dragCropRectPixels!.height;
                              }
                            });
                          },
                          onCropPanUpdate: (details) {
                            setState(() {
                              if (_activeHandle == null || _dragCropRectPixels == null) {
                                return;
                              }
                              final double ratio = _dragAspectRatio ?? (_dragCropRectPixels!.width / _dragCropRectPixels!.height);
                              _dragCropRectPixels = PanUtils.calculateImageCrop(
                                dragCropRectPixels: _dragCropRectPixels!,
                                delta: details.delta,
                                activeHandle: _activeHandle!,
                                ratio: ratio,
                                imageSize: image.size!,
                              );
                            });
                          },
                          onCropPanEnd: () {
                            setState(() {
                              _activeHandle = null;
                            });
                          },
                          onMovePanStart: isSelected && _selectionMode == SelectionMode.move
                              ? (details) => _dragRawPosition = image.position
                              : null,
                          onMovePanUpdate: isSelected && _selectionMode == SelectionMode.move
                              ? (details) {
                                  setState(() {
                                    _dragRawPosition = (_dragRawPosition ?? image.position) + details.delta;
                                    final BuildContext? imageContext = image.key.currentContext;
                                    if (imageContext != null) {
                                      final RenderBox? myRenderBox = imageContext.findRenderObject() as RenderBox?;
                                      if (myRenderBox != null) {
                                        final snapDist = Constants.snapDistanceBase / _transformationController.value.getMaxScaleOnAxis();
                                        image.position = PanUtils.calculateImageMove(
                                          _dragRawPosition! - details.delta,
                                          details.delta,
                                          myRenderBox.size,
                                          _images,
                                          image,
                                          snapDist,
                                        );
                                      }
                                    }
                                  });
                                }
                              : null,
                        );
                      }),
                      if (_isExportMode && _exportRectPixels != null)
                        ExportOverlay(
                          exportRectPixels: _exportRectPixels!,
                          onMoveStart: () => setState(() => _dragRawExportRect = _exportRectPixels),
                          onMoveUpdate: (details) {
                            setState(() {
                              if (_exportRectPixels == null) {
                                return;
                              }
                              final double snapDist = Constants.snapDistanceBase / _transformationController.value.getMaxScaleOnAxis();
                              _dragRawExportRect = _dragRawExportRect ?? _exportRectPixels!;
                              final result = PanUtils.calculateExportMove(
                                dragRawExportRect: _dragRawExportRect!,
                                delta: details.delta,
                                images: _images,
                                snapDist: snapDist,
                              );
                              _exportRectPixels = result.snappedRect;
                              _dragRawExportRect = result.rawRect;
                            });
                          },
                          onMoveEnd: () => setState(() => _dragRawExportRect = null),
                          onPanStart: (handle) {
                            setState(() {
                              _activeHandle = handle;
                              _dragRawExportRect = _exportRectPixels;
                            });
                          },
                          onPanUpdate: (details) {
                            setState(() {
                              if (_exportRectPixels == null || _activeHandle == null) {
                                return;
                              }
                              final double snapDist = Constants.snapDistanceBase / _transformationController.value.getMaxScaleOnAxis();
                              _dragRawExportRect ??= _exportRectPixels;
                              final result = PanUtils.calculateExportPan(
                                dragRawExportRect: _dragRawExportRect!,
                                delta: details.delta,
                                activeHandle: _activeHandle!,
                                images: _images,
                                snapDist: snapDist,
                              );
                              _exportRectPixels = result.snappedRect;
                              _dragRawExportRect = result.rawRect;
                            });
                          },
                          onPanEnd: () {
                            setState(() {
                              _activeHandle = null;
                              _dragRawExportRect = null;
                            });
                          },
                        ),
                    ],
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
                        FilledButton.tonalIcon(
                          onPressed: _declineChanges,
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                        ),
                        FilledButton.icon(onPressed: _acceptChanges, icon: const Icon(Icons.check), label: const Text('Apply')),
                      ],
                    ),
                  ),
                ),
              if (_isExportMode)
                Positioned(
                  bottom: 16.0,
                  left: 16.0,
                  right: 16.0,
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: () {
                            setState(() {
                              _isExportMode = false;
                              _exportRectPixels = null;
                            });
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Cancel'),
                          style: FilledButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                        ),
                        Row(
                          children: [
                            FilledButton.icon(
                              onPressed: () => _handleExportImage(true), // png
                              icon: const Icon(Icons.image),
                              label: const Text('Save PNG'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () => _handleExportImage(false), // jpg
                              icon: const Icon(Icons.image),
                              label: const Text('Save JPG'),
                            ),
                          ],
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
