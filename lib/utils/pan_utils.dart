import 'dart:ui';

import 'package:mimage/utils/canvas_image.dart';
import 'package:mimage/utils/constants.dart';
import 'package:mimage/utils/handle.dart';

class PanUtils {
  static Offset calculateImageMove(
    Offset currentPosition,
    Offset delta,
    Size mySize,
    List<CanvasImage> images,
    CanvasImage currentImage,
    double snapDist,
  ) {
    Offset newPosition = currentPosition + delta;

    double? bestDx;
    double? bestDy;
    double minDiffX = snapDist;
    double minDiffY = snapDist;

    for (final CanvasImage otherImage in images) {
      if (otherImage == currentImage) {
        continue;
      }
      final Size? otherSize = otherImage.size;
      if (otherSize != null) {
        final double myLeft = newPosition.dx;
        final double myRight = newPosition.dx + mySize.width;
        final double myTop = newPosition.dy;
        final double myBottom = newPosition.dy + mySize.height;

        final double otherLeft = otherImage.position.dx;
        final double otherRight = otherImage.position.dx + otherSize.width;
        final double otherTop = otherImage.position.dy;
        final double otherBottom = otherImage.position.dy + otherSize.height;

        final Map<double, double> xCandidates = {
          otherLeft - mySize.width: (myRight - otherLeft).abs(),
          otherRight: (myLeft - otherRight).abs(),
          otherLeft: (myLeft - otherLeft).abs(),
          otherRight - mySize.width: (myRight - otherRight).abs(),
        };

        for (final MapEntry<double, double> entry in xCandidates.entries) {
          if (entry.value < minDiffX) {
            minDiffX = entry.value;
            bestDx = entry.key;
          }
        }

        final Map<double, double> yCandidates = {
          otherTop - mySize.height: (myBottom - otherTop).abs(),
          otherBottom: (myTop - otherBottom).abs(),
          otherTop: (myTop - otherTop).abs(),
          otherBottom - mySize.height: (myBottom - otherBottom).abs(),
        };

        for (final MapEntry<double, double> entry in yCandidates.entries) {
          if (entry.value < minDiffY) {
            minDiffY = entry.value;
            bestDy = entry.key;
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

    return newPosition;
  }

  static ({Rect snappedRect, Size snappedSize, Offset rawPosition, Size rawSize}) calculateImageResize({
    required Offset dragRawPosition,
    required Size dragRawSize,
    required Offset delta,
    required Handle activeHandle,
    required double ratio,
    required List<CanvasImage> images,
    required int currentIndex,
    required double snapDist,
  }) {
    final bool isTop = activeHandle.isTop;
    final bool isBottom = activeHandle.isBottom;
    final bool isLeft = activeHandle.isLeft;
    final bool isRight = activeHandle.isRight;

    final bool prop = activeHandle.isCorner;

    final double dx = delta.dx;
    final double dy = delta.dy;

    Size newRawSize = dragRawSize;
    Offset newRawPosition = dragRawPosition;

    if (isRight) {
      newRawSize = Size(newRawSize.width + dx, newRawSize.height);
    }
    if (isLeft) {
      newRawSize = Size(newRawSize.width - dx, newRawSize.height);
      newRawPosition = Offset(newRawPosition.dx + dx, newRawPosition.dy);
    }
    if (isBottom) {
      newRawSize = Size(newRawSize.width, newRawSize.height + dy);
    }
    if (isTop) {
      newRawSize = Size(newRawSize.width, newRawSize.height - dy);
      newRawPosition = Offset(newRawPosition.dx, newRawPosition.dy + dy);
    }

    double rawW = newRawSize.width;
    double rawH = newRawSize.height;
    double rawL = newRawPosition.dx;
    double rawT = newRawPosition.dy;

    if (prop) {
      final double dot = rawW * ratio + rawH * 1.0;
      final double lenSq = ratio * ratio + 1.0;
      final double t = dot / lenSq;

      double newW = t * ratio;
      double newH = t * 1.0;

      if (newW < Constants.minStretchLimit || newH < Constants.minStretchLimit) {
        if (newW < Constants.minStretchLimit) {
          newW = Constants.minStretchLimit;
          newH = Constants.minStretchLimit / ratio;
        }
        if (newH < Constants.minStretchLimit) {
          newH = Constants.minStretchLimit;
          newW = Constants.minStretchLimit * ratio;
        }
      }

      if (isLeft) {
        rawL += rawW - newW;
      }
      if (isTop) {
        rawT += rawH - newH;
      }

      rawW = newW;
      rawH = newH;
    } else {
      if (rawW < Constants.minStretchLimit) {
        if (isLeft) {
          rawL -= Constants.minStretchLimit - rawW;
        }
        rawW = Constants.minStretchLimit;
      }
      if (rawH < Constants.minStretchLimit) {
        if (isTop) {
          rawT -= Constants.minStretchLimit - rawH;
        }
        rawH = Constants.minStretchLimit;
      }
    }

    double? bestEdgeX;
    double? bestEdgeY;
    double minDiffX = snapDist;
    double minDiffY = snapDist;

    for (var i = 0; i < images.length; i++) {
      if (i == currentIndex) {
        continue;
      }
      final CanvasImage otherImage = images[i];
      final Size? otherSize = otherImage.size;
      if (otherSize != null) {
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

    return (
      snappedRect: Rect.fromLTWH(rawL, rawT, rawW, rawH),
      snappedSize: Size(rawW, rawH),
      rawPosition: newRawPosition,
      rawSize: newRawSize,
    );
  }

  static Rect calculateImageCrop({
    required Rect dragCropRectPixels,
    required Offset delta,
    required Handle activeHandle,
    required double ratio,
    required Size imageSize,
  }) {
    final bool isTop = activeHandle.isTop;
    final bool isBottom = activeHandle.isBottom;
    final bool isLeft = activeHandle.isLeft;
    final bool isRight = activeHandle.isRight;

    final bool prop = activeHandle.isCorner;

    final double dx = delta.dx;
    final double dy = delta.dy;

    double cropL = dragCropRectPixels.left;
    double cropT = dragCropRectPixels.top;
    double cropR = dragCropRectPixels.right;
    double cropB = dragCropRectPixels.bottom;

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

    if (cropL < 0) {
      cropL = 0;
    }
    if (cropT < 0) {
      cropT = 0;
    }
    if (cropR > imageSize.width) {
      cropR = imageSize.width;
    }
    if (cropB > imageSize.height) {
      cropB = imageSize.height;
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

    if (cropW < Constants.minCropLimit) {
      if (isLeft) {
        cropL = cropR - Constants.minCropLimit;
      } else {
        cropR = cropL + Constants.minCropLimit;
      }
    }
    if (cropH < Constants.minCropLimit) {
      if (isTop) {
        cropT = cropB - Constants.minCropLimit;
      } else {
        cropB = cropT + Constants.minCropLimit;
      }
    }

    return Rect.fromLTRB(cropL, cropT, cropR, cropB);
  }

  static ({Rect snappedRect, Rect rawRect}) calculateExportPan({
    required Rect dragRawExportRect,
    required Offset delta,
    required Handle activeHandle,
    required List<CanvasImage> images,
    required double snapDist,
  }) {
    final bool isTop = activeHandle.isTop;
    final bool isBottom = activeHandle.isBottom;
    final bool isLeft = activeHandle.isLeft;
    final bool isRight = activeHandle.isRight;

    final double dx = delta.dx;
    final double dy = delta.dy;

    double rawL = dragRawExportRect.left;
    double rawT = dragRawExportRect.top;
    double rawR = dragRawExportRect.right;
    double rawB = dragRawExportRect.bottom;

    if (isRight) {
      rawR += dx;
    }
    if (isLeft) {
      rawL += dx;
    }
    if (isBottom) {
      rawB += dy;
    }
    if (isTop) {
      rawT += dy;
    }

    double? bestEdgeX;
    double? bestEdgeY;
    double minDiffX = snapDist;
    double minDiffY = snapDist;

    for (final CanvasImage otherImage in images) {
      if (otherImage.size != null) {
        final double otherLeft = otherImage.position.dx;
        final double otherRight = otherImage.position.dx + otherImage.size!.width;
        final double otherTop = otherImage.position.dy;
        final double otherBottom = otherImage.position.dy + otherImage.size!.height;

        if (isRight) {
          final d1 = (rawR - otherLeft).abs();
          final d2 = (rawR - otherRight).abs();
          if (d1 < minDiffX) {
            minDiffX = d1;
            bestEdgeX = otherLeft;
          }
          if (d2 < minDiffX) {
            minDiffX = d2;
            bestEdgeX = otherRight;
          }
        } else if (isLeft) {
          final d1 = (rawL - otherLeft).abs();
          final d2 = (rawL - otherRight).abs();
          if (d1 < minDiffX) {
            minDiffX = d1;
            bestEdgeX = otherLeft;
          }
          if (d2 < minDiffX) {
            minDiffX = d2;
            bestEdgeX = otherRight;
          }
        }
        if (isBottom) {
          final d1 = (rawB - otherTop).abs();
          final d2 = (rawB - otherBottom).abs();
          if (d1 < minDiffY) {
            minDiffY = d1;
            bestEdgeY = otherTop;
          }
          if (d2 < minDiffY) {
            minDiffY = d2;
            bestEdgeY = otherBottom;
          }
        } else if (isTop) {
          final d1 = (rawT - otherTop).abs();
          final d2 = (rawT - otherBottom).abs();
          if (d1 < minDiffY) {
            minDiffY = d1;
            bestEdgeY = otherTop;
          }
          if (d2 < minDiffY) {
            minDiffY = d2;
            bestEdgeY = otherBottom;
          }
        }
      }
    }

    if (bestEdgeX != null) {
      if (isRight) {
        rawR = bestEdgeX;
      } else if (isLeft) {
        rawL = bestEdgeX;
      }
    }
    if (bestEdgeY != null) {
      if (isBottom) {
        rawB = bestEdgeY;
      } else if (isTop) {
        rawT = bestEdgeY;
      }
    }

    if (rawR - rawL < Constants.minStretchLimit) {
      if (isLeft) {
        rawL = rawR - Constants.minStretchLimit;
      } else {
        rawR = rawL + Constants.minStretchLimit;
      }
    }
    if (rawB - rawT < Constants.minStretchLimit) {
      if (isTop) {
        rawT = rawB - Constants.minStretchLimit;
      } else {
        rawB = rawT + Constants.minStretchLimit;
      }
    }

    final Rect rawRect = Rect.fromLTRB(
      dragRawExportRect.left + (isLeft ? dx : 0),
      dragRawExportRect.top + (isTop ? dy : 0),
      dragRawExportRect.right + (isRight ? dx : 0),
      dragRawExportRect.bottom + (isBottom ? dy : 0),
    );

    return (snappedRect: Rect.fromLTRB(rawL, rawT, rawR, rawB), rawRect: rawRect);
  }

  static ({Rect snappedRect, Rect rawRect}) calculateExportMove({
    required Rect dragRawExportRect,
    required Offset delta,
    required List<CanvasImage> images,
    required double snapDist,
  }) {
    Rect newRect = dragRawExportRect.translate(delta.dx, delta.dy);

    double? bestDx;
    double? bestDy;
    double minDiffX = snapDist;
    double minDiffY = snapDist;

    for (final CanvasImage otherImage in images) {
      if (otherImage.size != null) {
        final double otherLeft = otherImage.position.dx;
        final double otherRight = otherImage.position.dx + otherImage.size!.width;
        final double otherTop = otherImage.position.dy;
        final double otherBottom = otherImage.position.dy + otherImage.size!.height;

        final Map<double, double> xCandidates = {
          otherLeft - newRect.width: (newRect.right - otherLeft).abs(),
          otherRight: (newRect.left - otherRight).abs(),
          otherLeft: (newRect.left - otherLeft).abs(),
          otherRight - newRect.width: (newRect.right - otherRight).abs(),
        };

        for (final entry in xCandidates.entries) {
          if (entry.value < minDiffX) {
            minDiffX = entry.value;
            bestDx = entry.key;
          }
        }

        final Map<double, double> yCandidates = {
          otherTop - newRect.height: (newRect.bottom - otherTop).abs(),
          otherBottom: (newRect.top - otherBottom).abs(),
          otherTop: (newRect.top - otherTop).abs(),
          otherBottom - newRect.height: (newRect.bottom - otherBottom).abs(),
        };

        for (final entry in yCandidates.entries) {
          if (entry.value < minDiffY) {
            minDiffY = entry.value;
            bestDy = entry.key;
          }
        }
      }
    }

    if (bestDx != null) {
      newRect = Rect.fromLTWH(bestDx, newRect.top, newRect.width, newRect.height);
    }
    if (bestDy != null) {
      newRect = Rect.fromLTWH(newRect.left, bestDy, newRect.width, newRect.height);
    }

    return (snappedRect: newRect, rawRect: dragRawExportRect.translate(delta.dx, delta.dy));
  }
}
