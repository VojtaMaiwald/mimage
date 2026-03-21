import 'package:flutter/material.dart';

class CanvasImage {
  CanvasImage({
    required this.path,
    this.position = Offset.zero,
    this.size,
    this.cropRect,
  });
  final String path;
  Offset position;
  Size? size;
  Rect? cropRect;
  final GlobalKey key = GlobalKey();
}
