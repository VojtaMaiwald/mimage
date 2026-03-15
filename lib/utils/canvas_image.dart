import 'package:flutter/material.dart';

class CanvasImage {
  CanvasImage({required this.path, this.position = Offset.zero, this.size});
  final String path;
  Offset position;
  Size? size;
  final GlobalKey key = GlobalKey();
}
