import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/device_mapping_service.dart';
import 'package:touch_bridge/services/mapping_execution_service.dart';

void main() {
  group('MappingExecutionService.resolveButton', () {
    test('저장된 buttonMap 좌표를 우선 사용한다', () {
      const profile = DeviceMappingProfile(
        rows: 4,
        cols: 4,
        originX: 0,
        originY: 0,
        pitchX: 1,
        pitchY: 1,
        buttonMap: {'BT-02': (row: 3, col: 2)},
      );

      final resolved = MappingExecutionService.instance.resolveButton(
        profile: profile,
        buttonId: 'BT-02',
      );

      expect(resolved, (row: 3, col: 2));
    });

    test('저장 좌표가 없으면 3x3 논리 좌표 fallback을 사용한다', () {
      final profile = DeviceMappingProfile.defaultGrid(rows: 3, cols: 3);

      final resolved = MappingExecutionService.instance.resolveButton(
        profile: profile,
        buttonId: 'BT-05',
      );

      expect(resolved, (row: 1, col: 1));
    });

    test('fallback 좌표가 현재 그리드 밖이면 null을 반환한다', () {
      final profile = DeviceMappingProfile.defaultGrid(rows: 2, cols: 2);

      final resolved = MappingExecutionService.instance.resolveButton(
        profile: profile,
        buttonId: 'BT-09',
      );

      expect(resolved, isNull);
    });
  });
}
