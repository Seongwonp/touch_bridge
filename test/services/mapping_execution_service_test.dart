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

  group('MappingExecutionService XYZ G-code', () {
    test('buttonMap 좌표를 X/Y mm와 Z 누름 시퀀스로 변환한다', () {
      const profile = DeviceMappingProfile(
        rows: 3,
        cols: 3,
        originX: 10,
        originY: 20,
        pitchX: 7,
        pitchY: 5,
        travelHeightZ: 4,
        pressDepthZ: -1.25,
        travelFeed: 1500,
        pressFeed: 180,
        dwellSeconds: 0.3,
        buttonMap: {'BT-02': (row: 2, col: 1)},
      );

      final service = MappingExecutionService.instance;
      final resolved = service.resolveButton(
        profile: profile,
        buttonId: 'BT-02',
      );

      expect(resolved, isNotNull);
      final x = service.calculateX(profile: profile, col: resolved!.col);
      final y = service.calculateY(profile: profile, row: resolved.row);
      final gcode = service.buildPressGcode(profile: profile, x: x, y: y);

      expect(x, 17);
      expect(y, 30);
      expect(gcode, [
        'G90',
        'G21',
        'G0 Z4 F180',
        'G0 X17 Y30 F1500',
        'G1 Z-1.25 F180',
        'G4 P0.3',
        'G0 Z4 F180',
      ]);
    });
  });

  group('MappingExecutionResult.userMessage (사용자 문구 정직화)', () {
    test('매핑 미등록 실패는 버튼 등록 요청을 안내하고 내부 ID를 노출하지 않는다', () {
      const result = MappingExecutionResult(
        ok: false,
        message: 'BT-02 버튼의 매핑을 찾지 못했습니다.',
        buttonId: 'BT-02',
      );
      expect(result.userMessage, contains('등록'));
      expect(result.userMessage, isNot(contains('BT-02')));
    });

    test('전송 실패(좌표는 있음)는 연결 확인/재시도를 안내한다', () {
      const result = MappingExecutionResult(
        ok: false,
        message: '명령 전송 중 오류가 발생했습니다.',
        row: 1,
        col: 1,
      );
      expect(result.userMessage, contains('다시 시도'));
    });

    test('전송 성공을 "완료"로 단언하지 않고 기술용어를 노출하지 않는다', () {
      const result = MappingExecutionResult(ok: true, message: '시퀀스 명령 전송 완료');
      expect(result.userMessage, isNot(contains('G-code')));
      expect(result.userMessage, isNot(contains('XYZ')));
      expect(result.userMessage, isNot(contains('완료')));
    });

    test('dry-run은 준비 상태로 안내한다', () {
      const result = MappingExecutionResult(
        ok: true,
        message: 'dry-run 시퀀스 생성 완료',
        dryRun: true,
      );
      expect(result.userMessage, contains('준비'));
    });
  });
}
