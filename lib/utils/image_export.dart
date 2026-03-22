import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img_pkg;
import 'package:mimage/utils/canvas_image.dart';

Future<String?> exportCanvasImages({required bool isPng, required Rect exportRectPixels, required List<CanvasImage> images}) async {
  final Rect area = exportRectPixels;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder, Rect.fromLTWH(0, 0, area.width, area.height))..translate(-area.left, -area.top);

  if (!isPng) {
    canvas.drawRect(area, Paint()..color = Colors.black);
  }

  for (final imageInfo in images) {
    if (imageInfo.size == null) {
      continue;
    }
    final destRect = Rect.fromLTWH(imageInfo.position.dx, imageInfo.position.dy, imageInfo.size!.width, imageInfo.size!.height);
    if (!area.overlaps(destRect)) {
      continue;
    }

    final data = await File(imageInfo.path).readAsBytes();
    final uiImage = await decodeImageFromList(data);

    final crop = imageInfo.cropRect ?? const Rect.fromLTWH(0, 0, 1, 1);
    final srcRect = Rect.fromLTRB(
      crop.left * uiImage.width,
      crop.top * uiImage.height,
      crop.right * uiImage.width,
      crop.bottom * uiImage.height,
    );
    canvas.drawImageRect(uiImage, srcRect, destRect, Paint());
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(area.width.toInt(), area.height.toInt());

  List<int>? bytes;
  if (isPng) {
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      bytes = byteData.buffer.asUint8List();
    }
  } else {
    final rawData = await img.toByteData();
    if (rawData != null) {
      final decodedImg = img_pkg.Image.fromBytes(width: img.width, height: img.height, bytes: rawData.buffer, numChannels: 4);
      bytes = img_pkg.encodeJpg(decodedImg);
    }
  }

  if (bytes != null) {
    final String ext = isPng ? 'png' : 'jpg';

    return FileSaver.instance.saveAs(
      name: 'export_${DateTime.now().millisecondsSinceEpoch}',
      fileExtension: ext,
      bytes: Uint8List.fromList(bytes),
      mimeType: isPng ? MimeType.png : MimeType.jpeg,
    );
  }

  return null;
}
