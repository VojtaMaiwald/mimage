import 'package:flutter/material.dart';

enum SelectionMode {
  move,
  resize,
  crop;

  String get description => switch (this) {
    SelectionMode.crop => 'Crop',
    SelectionMode.resize => 'Resize',
    SelectionMode.move => 'Move',
  };

  IconData get icon => switch (this) {
    SelectionMode.crop => Icons.crop_rounded,
    SelectionMode.resize => Icons.photo_size_select_large_rounded,
    SelectionMode.move => Icons.open_with_rounded,
  };
}
