import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Encapsulates the fitted display geometry of an image or document inside a container.
///
/// Ensures mathematical consistency between:
/// 1. The actual displayed image Rect inside the container (accounting for letterboxing)
/// 2. User selection coordinates mapped to normalized [0.0, 1.0] image space
/// 3. Normalized coordinates mapped back to UI overlay Rect
/// 4. Backend pixel mapping: px = normalized * sourceDimension
class ImageDisplayGeometry {
  final Size sourceSize;
  final Size containerSize;
  final BoxFit fit;
  final Alignment alignment;

  late final Size fittedSize;
  late final Rect imageRect;
  late final double scaleX;
  late final double scaleY;

  ImageDisplayGeometry({
    required this.sourceSize,
    required this.containerSize,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  }) {
    if (sourceSize.width <= 0 ||
        sourceSize.height <= 0 ||
        containerSize.width <= 0 ||
        containerSize.height <= 0) {
      fittedSize = containerSize;
      imageRect = Rect.fromLTWH(0, 0, math.max(0, containerSize.width), math.max(0, containerSize.height));
      scaleX = 1.0;
      scaleY = 1.0;
      return;
    }

    final FittedSizes fitted = applyBoxFit(fit, sourceSize, containerSize);
    fittedSize = fitted.destination;

    // Calculate letterboxing offset according to alignment (default center)
    final double diffX = containerSize.width - fittedSize.width;
    final double diffY = containerSize.height - fittedSize.height;
    final double left = (diffX * (alignment.x + 1.0) / 2.0);
    final double top = (diffY * (alignment.y + 1.0) / 2.0);

    imageRect = Rect.fromLTWH(
      math.max(0.0, left),
      math.max(0.0, top),
      fittedSize.width,
      fittedSize.height,
    );

    scaleX = fittedSize.width / sourceSize.width;
    scaleY = fittedSize.height / sourceSize.height;
  }

  /// Converts a pointer local position inside the container to a normalized Offset [0.0, 1.0]
  /// strictly relative to the displayed image rectangle.
  Offset pointerToNormalized(Offset localPosition) {
    if (imageRect.width <= 0 || imageRect.height <= 0) return Offset.zero;

    final double clampedX = localPosition.dx.clamp(imageRect.left, imageRect.right);
    final double clampedY = localPosition.dy.clamp(imageRect.top, imageRect.bottom);

    final double normX = ((clampedX - imageRect.left) / imageRect.width).clamp(0.0, 1.0);
    final double normY = ((clampedY - imageRect.top) / imageRect.height).clamp(0.0, 1.0);

    return Offset(normX, normY);
  }

  /// Converts a drag selection (start and current local positions)
  /// into a normalized Rect [0.0, 1.0] relative to the imageRect.
  Rect selectionToNormalizedRect(Offset start, Offset current) {
    if (imageRect.width <= 0 || imageRect.height <= 0) return Rect.zero;

    final double clampedStartX = start.dx.clamp(imageRect.left, imageRect.right);
    final double clampedStartY = start.dy.clamp(imageRect.top, imageRect.bottom);
    final double clampedCurrX = current.dx.clamp(imageRect.left, imageRect.right);
    final double clampedCurrY = current.dy.clamp(imageRect.top, imageRect.bottom);

    final double minX = math.min(clampedStartX, clampedCurrX);
    final double minY = math.min(clampedStartY, clampedCurrY);
    final double maxX = math.max(clampedStartX, clampedCurrX);
    final double maxY = math.max(clampedStartY, clampedCurrY);

    final double normX = ((minX - imageRect.left) / imageRect.width).clamp(0.0, 1.0);
    final double normY = ((minY - imageRect.top) / imageRect.height).clamp(0.0, 1.0);
    final double normW = ((maxX - minX) / imageRect.width).clamp(0.0, 1.0 - normX);
    final double normH = ((maxY - minY) / imageRect.height).clamp(0.0, 1.0 - normY);

    return Rect.fromLTWH(normX, normY, normW, normH);
  }

  /// Converts a normalized Rect [0.0, 1.0] back to local container pixel coordinates
  /// for rendering overlays at the exact screen position of the image.
  Rect normalizedToLocalRect(double normX, double normY, double normW, double normH) {
    final double left = imageRect.left + (normX * imageRect.width);
    final double top = imageRect.top + (normY * imageRect.height);
    final double width = math.max(0.0, normW * imageRect.width);
    final double height = math.max(0.0, normH * imageRect.height);

    return Rect.fromLTWH(left, top, width, height);
  }

  /// Converts normalized coordinates to backend source image pixel coordinates.
  Rect normalizedToSourcePixels(double normX, double normY, double normW, double normH) {
    final double pxX = normX * sourceSize.width;
    final double pxY = normY * sourceSize.height;
    final double pxW = math.max(0.0, normW * sourceSize.width);
    final double pxH = math.max(0.0, normH * sourceSize.height);

    return Rect.fromLTWH(pxX, pxY, pxW, pxH);
  }
}
