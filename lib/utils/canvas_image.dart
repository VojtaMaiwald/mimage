import 'package:flutter/material.dart';

class CanvasImage {
  CanvasImage({required this.path, this.position = Offset.zero});
  final String path;
  Offset position;
  final GlobalKey key = GlobalKey();
}
