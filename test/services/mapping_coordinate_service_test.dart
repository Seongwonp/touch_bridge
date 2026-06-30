import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/mapping_coordinate_service.dart';

void main() {
  group('MappingCoordinateService', () {
    test('세로 컨테이너 안에 가로 이미지를 contain으로 중앙 배치한다', () {
      final rect = MappingCoordinateService.fittedImageRect(
        containerSize: const Size(300, 600),
        imageSize: const Size(400, 200),
      );

      expect(rect.left, 0);
      expect(rect.width, 300);
      expect(rect.height, 150);
      expect(rect.top, 225);
    });

    test('이미지 밖 레터박스 터치는 null로 무시한다', () {
      final rect = MappingCoordinateService.fittedImageRect(
        containerSize: const Size(300, 600),
        imageSize: const Size(400, 200),
      );

      final normalized = MappingCoordinateService.normalizedFromLocal(
        localPosition: const Offset(150, 100),
        imageRect: rect,
      );

      expect(normalized, isNull);
    });

    test('이미지 안 터치는 normalized 좌표로 변환한다', () {
      final rect = MappingCoordinateService.fittedImageRect(
        containerSize: const Size(300, 600),
        imageSize: const Size(400, 200),
      );

      final normalized = MappingCoordinateService.normalizedFromLocal(
        localPosition: const Offset(150, 300),
        imageRect: rect,
      );

      expect(normalized?.dx, closeTo(0.5, 0.0001));
      expect(normalized?.dy, closeTo(0.5, 0.0001));
    });

    test('normalized 좌표를 같은 이미지 rect의 로컬 좌표로 되돌린다', () {
      final rect = MappingCoordinateService.fittedImageRect(
        containerSize: const Size(300, 600),
        imageSize: const Size(400, 200),
      );

      final local = MappingCoordinateService.localFromNormalized(
        normalized: const Offset(0.5, 0.5),
        imageRect: rect,
      );

      expect(local.dx, closeTo(150, 0.0001));
      expect(local.dy, closeTo(300, 0.0001));
    });
  });
}
