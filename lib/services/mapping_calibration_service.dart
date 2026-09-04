import 'dart:math' as math;

import 'device_mapping_service.dart';

class MappingCalibrationResult {
  const MappingCalibrationResult({
    required this.machinePositions,
    this.errors = const [],
  });

  final Map<String, ({double xMm, double yMm})> machinePositions;
  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

/// 사진 좌표를 장치의 X/Y mm 좌표로 바꾸는 4점 투영 변환 서비스.
///
/// AI는 사진의 정규화 좌표까지만 제공한다. 이 서비스가 보호자가 지정한 패널
/// 모서리 네 점을 기준으로 호모그래피를 계산하고, 작업영역 및 버튼 간격을
/// 검증한 뒤에만 실제 구동에 사용할 좌표를 반환한다.
class MappingCalibrationService {
  const MappingCalibrationService._();

  static MappingCalibrationResult calculate({
    required PanelCalibration calibration,
    required Map<String, ({double x, double y})> buttonPositions,
  }) {
    final errors = <String>[];
    if (!calibration.isComplete) {
      return const MappingCalibrationResult(
        machinePositions: {},
        errors: ['패널 모서리 네 점이 필요합니다.'],
      );
    }

    final source = [
      for (final corner in calibration.corners)
        (x: corner.imageX, y: corner.imageY),
    ];
    final destination = [
      for (final corner in calibration.corners)
        (x: corner.machineXmm, y: corner.machineYmm),
    ];

    if (source.any(
      (point) =>
          !point.x.isFinite ||
          !point.y.isFinite ||
          point.x < 0 ||
          point.x > 1 ||
          point.y < 0 ||
          point.y > 1,
    )) {
      errors.add('사진 모서리 좌표가 이미지 범위를 벗어났습니다.');
    }
    if (destination.any((point) => !point.x.isFinite || !point.y.isFinite)) {
      errors.add('장치 모서리 좌표에 올바르지 않은 숫자가 있습니다.');
    }
    if (!calibration.minimumButtonSpacingMm.isFinite ||
        calibration.minimumButtonSpacingMm <= 0) {
      errors.add('버튼 최소 간격 설정이 올바르지 않습니다.');
    }
    if (!_isConvexOrdered(source)) {
      errors.add('사진 모서리를 좌상단부터 시계 방향으로 다시 지정해 주세요.');
    }
    if (!_isConvexOrdered(destination)) {
      errors.add('장치 모서리 좌표가 겹치거나 순서가 올바르지 않습니다.');
    }
    if (_signedArea(source).sign != _signedArea(destination).sign) {
      errors.add('사진과 장치 모서리의 축 방향이 서로 다릅니다.');
    }
    if (errors.isNotEmpty) {
      return MappingCalibrationResult(
        machinePositions: const {},
        errors: errors,
      );
    }

    final homography = _solveHomography(source, destination);
    if (homography == null) {
      return const MappingCalibrationResult(
        machinePositions: {},
        errors: ['모서리 간격이 너무 좁아 좌표 변환을 계산할 수 없습니다.'],
      );
    }

    final minX = destination.map((p) => p.x).reduce(math.min);
    final maxX = destination.map((p) => p.x).reduce(math.max);
    final minY = destination.map((p) => p.y).reduce(math.min);
    final maxY = destination.map((p) => p.y).reduce(math.max);
    final positions = <String, ({double xMm, double yMm})>{};

    for (final entry in buttonPositions.entries) {
      final point = entry.value;
      if (!point.x.isFinite ||
          !point.y.isFinite ||
          point.x < 0 ||
          point.x > 1 ||
          point.y < 0 ||
          point.y > 1) {
        errors.add('${entry.key}의 사진 좌표가 올바르지 않습니다.');
        continue;
      }
      if (!_isInsideConvexPolygon(point, source)) {
        errors.add('${entry.key}가 사진의 패널 영역 밖에 있습니다.');
        continue;
      }
      final transformed = _transform(homography, point.x, point.y);
      if (transformed == null ||
          transformed.x < minX - 0.001 ||
          transformed.x > maxX + 0.001 ||
          transformed.y < minY - 0.001 ||
          transformed.y > maxY + 0.001) {
        errors.add('${entry.key}가 캘리브레이션 작업영역 밖에 있습니다.');
        continue;
      }
      positions[entry.key] = (xMm: transformed.x, yMm: transformed.y);
    }

    final entries = positions.entries.toList(growable: false);
    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final dx = entries[i].value.xMm - entries[j].value.xMm;
        final dy = entries[i].value.yMm - entries[j].value.yMm;
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance < calibration.minimumButtonSpacingMm) {
          errors.add(
            '${entries[i].key}와 ${entries[j].key}의 실제 좌표가 '
            '${calibration.minimumButtonSpacingMm}mm보다 가깝습니다.',
          );
        }
      }
    }

    if (errors.isNotEmpty) {
      return MappingCalibrationResult(
        machinePositions: const {},
        errors: errors,
      );
    }
    return MappingCalibrationResult(machinePositions: positions);
  }

  static bool _isConvexOrdered(List<({double x, double y})> points) {
    if (points.length != 4) return false;
    double? sign;
    for (var i = 0; i < 4; i++) {
      final a = points[i];
      final b = points[(i + 1) % 4];
      final c = points[(i + 2) % 4];
      final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
      if (cross.abs() < 1e-9) return false;
      final currentSign = cross.sign;
      sign ??= currentSign;
      if (currentSign != sign) return false;
    }
    return true;
  }

  static bool _isInsideConvexPolygon(
    ({double x, double y}) point,
    List<({double x, double y})> polygon,
  ) {
    double? sign;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final cross =
          (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x);
      if (cross.abs() <= 1e-9) continue;
      sign ??= cross.sign;
      if (cross.sign != sign) return false;
    }
    return true;
  }

  static double _signedArea(List<({double x, double y})> points) {
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      sum += current.x * next.y - next.x * current.y;
    }
    return sum / 2;
  }

  static List<double>? _solveHomography(
    List<({double x, double y})> source,
    List<({double x, double y})> destination,
  ) {
    final matrix = List.generate(8, (_) => List<double>.filled(9, 0));
    for (var i = 0; i < 4; i++) {
      final x = source[i].x;
      final y = source[i].y;
      final targetX = destination[i].x;
      final targetY = destination[i].y;
      matrix[i * 2]
        ..[0] = x
        ..[1] = y
        ..[2] = 1
        ..[6] = -targetX * x
        ..[7] = -targetX * y
        ..[8] = targetX;
      matrix[i * 2 + 1]
        ..[3] = x
        ..[4] = y
        ..[5] = 1
        ..[6] = -targetY * x
        ..[7] = -targetY * y
        ..[8] = targetY;
    }

    for (var column = 0; column < 8; column++) {
      var pivot = column;
      for (var row = column + 1; row < 8; row++) {
        if (matrix[row][column].abs() > matrix[pivot][column].abs()) {
          pivot = row;
        }
      }
      if (matrix[pivot][column].abs() < 1e-10) return null;
      final swap = matrix[column];
      matrix[column] = matrix[pivot];
      matrix[pivot] = swap;

      final divisor = matrix[column][column];
      for (var j = column; j < 9; j++) {
        matrix[column][j] /= divisor;
      }
      for (var row = 0; row < 8; row++) {
        if (row == column) continue;
        final factor = matrix[row][column];
        for (var j = column; j < 9; j++) {
          matrix[row][j] -= factor * matrix[column][j];
        }
      }
    }
    return [for (var row = 0; row < 8; row++) matrix[row][8]];
  }

  static ({double x, double y})? _transform(
    List<double> h,
    double x,
    double y,
  ) {
    final denominator = h[6] * x + h[7] * y + 1;
    if (denominator.abs() < 1e-10) return null;
    final resultX = (h[0] * x + h[1] * y + h[2]) / denominator;
    final resultY = (h[3] * x + h[4] * y + h[5]) / denominator;
    if (!resultX.isFinite || !resultY.isFinite) return null;
    return (x: resultX, y: resultY);
  }
}
