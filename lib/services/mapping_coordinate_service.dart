import 'package:flutter/painting.dart';

class MappingCoordinateService {
  const MappingCoordinateService._();

  static Rect fittedImageRect({required Size containerSize, Size? imageSize}) {
    if (containerSize.width <= 0 || containerSize.height <= 0) {
      return Rect.zero;
    }
    if (imageSize == null || imageSize.width <= 0 || imageSize.height <= 0) {
      return Offset.zero & containerSize;
    }

    final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
    final dx = (containerSize.width - fitted.destination.width) / 2;
    final dy = (containerSize.height - fitted.destination.height) / 2;
    return Offset(dx, dy) & fitted.destination;
  }

  static Offset? normalizedFromLocal({
    required Offset localPosition,
    required Rect imageRect,
  }) {
    if (imageRect.width <= 0 || imageRect.height <= 0) return null;
    if (!imageRect.contains(localPosition)) return null;

    return Offset(
      ((localPosition.dx - imageRect.left) / imageRect.width).clamp(0.0, 1.0),
      ((localPosition.dy - imageRect.top) / imageRect.height).clamp(0.0, 1.0),
    );
  }

  static Offset localFromNormalized({
    required Offset normalized,
    required Rect imageRect,
  }) {
    return Offset(
      imageRect.left + normalized.dx.clamp(0.0, 1.0) * imageRect.width,
      imageRect.top + normalized.dy.clamp(0.0, 1.0) * imageRect.height,
    );
  }
}
