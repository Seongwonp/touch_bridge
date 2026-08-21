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

  /// 정규화 좌표(0~1)의 버튼들이 rows×cols 그리드로 양자화될 때 **같은 셀에
  /// 겹치는** 그룹을 찾아낸다.
  ///
  /// 물리 좌표는 결국 (row, col) 셀 단위로 계산되므로, 서로 다른 두 버튼이 같은
  /// 셀에 떨어지면 하드웨어는 같은 지점을 누른다 — "시작" 자리에서 "취소"가
  /// 눌리는 최악의 오작동. 저장 전에 이 함수로 검출해 보호자에게 고지해야 한다.
  ///
  /// 반환: 셀별로 2개 이상 몰린 버튼 라벨 그룹 목록(입력 순서 유지).
  /// 빈 목록이면 충돌 없음.
  static List<List<String>> detectCellCollisions({
    required List<({String label, double x, double y})> points,
    required int rows,
    required int cols,
  }) {
    if (rows <= 0 || cols <= 0) return const [];
    final byCell = <int, List<String>>{};
    for (final p in points) {
      final row = (p.y.clamp(0.0, 1.0) * rows).floor().clamp(0, rows - 1);
      final col = (p.x.clamp(0.0, 1.0) * cols).floor().clamp(0, cols - 1);
      byCell.putIfAbsent(row * cols + col, () => []).add(p.label);
    }
    return [
      for (final group in byCell.values)
        if (group.length >= 2) group,
    ];
  }
}
