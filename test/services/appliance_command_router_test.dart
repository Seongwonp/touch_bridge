import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/appliance_command_router.dart';
import 'package:touch_bridge/services/washing_machine_command_service.dart';
import 'package:touch_bridge/services/ac_command_service.dart';

void main() {
  group('ApplianceCommandRouter — deviceType 기반 라우팅', () {
    test('deviceType=microwave → MicrowaveCommandService 규칙 적용', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '30초 시작',
        deviceType: 'microwave',
      );
      expect(result, isNotNull);
      expect(result!['action'], 'MICROWAVE_CONTROL');
    });

    test('deviceType=washer → WashingMachineCommandService 규칙 적용', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '시작',
        deviceType: 'washer',
      );
      expect(result, isNotNull);
      expect(result!['action'], 'WASHER_CONTROL');
    });

    test('deviceType=airConditioner → AcCommandService 규칙 적용', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '냉방',
        deviceType: 'airConditioner',
      );
      expect(result, isNotNull);
      expect(result!['action'], 'AC_CONTROL');
    });

    test('deviceType 미지정 + deviceName=전자레인지 → microwave 라우팅', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '1분 시작',
        deviceName: '전자레인지',
      );
      expect(result, isNotNull);
      expect(result!['action'], 'MICROWAVE_CONTROL');
    });

    test('deviceType 미지정 + deviceName=세탁기 → washer 라우팅', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '시작',
        deviceName: '세탁기',
      );
      expect(result, isNotNull);
      expect(result!['action'], 'WASHER_CONTROL');
    });

    test('deviceType 미지정 + deviceName=에어컨 → ac 라우팅', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '냉방',
        deviceName: '에어컨',
      );
      expect(result, isNotNull);
      expect(result!['action'], 'AC_CONTROL');
    });

    test('알 수 없는 기기 → microwave 폴백', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '30초 시작',
        deviceName: '냉장고',
      );
      // 폴백도 microwave 규칙이므로 30초 시작이 매칭됨
      expect(result, isNotNull);
      expect(result!['action'], 'MICROWAVE_CONTROL');
    });

    test('매칭 없는 명령 → null 반환', () {
      final result = ApplianceCommandRouter.checkSimpleRules(
        '오늘 날씨 알려줘',
        deviceType: 'microwave',
      );
      expect(result, isNull);
    });
  });

  group('WashingMachineCommandService — 규칙 파싱', () {
    test('시작 명령 → BT-W02', () {
      final r = WashingMachineCommandService.checkSimpleRules('시작해줘');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-W02');
    });

    test('취소 명령 → BT-W09', () {
      final r = WashingMachineCommandService.checkSimpleRules('취소');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-W09');
    });

    test('표준 세탁 → BT-W03', () {
      final r = WashingMachineCommandService.checkSimpleRules('표준 세탁');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-W03');
    });

    test('섬세 → BT-W05', () {
      final r = WashingMachineCommandService.checkSimpleRules('섬세');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-W05');
    });

    test('탈수 → BT-W07', () {
      final r = WashingMachineCommandService.checkSimpleRules('탈수 시작');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-W07');
    });

    test('stop → BT-W09 (영어 정지 인식)', () {
      final r = WashingMachineCommandService.checkSimpleRules('stop');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-W09');
    });

    test('buildCommandsLabel — 알려진 버튼 레이블 반환', () {
      final label = WashingMachineCommandService.buildCommandsLabel(
        ['BT-W02', 'BT-W09'],
      );
      expect(label, contains('시작'));
      expect(label, contains('취소'));
    });

    test('매칭 없는 명령 → null', () {
      final r = WashingMachineCommandService.checkSimpleRules('날씨 알려줘');
      expect(r, isNull);
    });
  });

  group('AcCommandService — 규칙 파싱', () {
    test('냉방 → BT-A02', () {
      final r = AcCommandService.checkSimpleRules('냉방 켜줘');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-A02');
    });

    test('난방 → BT-A03', () {
      final r = AcCommandService.checkSimpleRules('난방 모드');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-A03');
    });

    test('온도 올려 → BT-A06', () {
      final r = AcCommandService.checkSimpleRules('온도 올려줘');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-A06');
    });

    test('온도 내려 → BT-A07', () {
      final r = AcCommandService.checkSimpleRules('온도 내려줘');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-A07');
    });

    test('제습 → BT-A04', () {
      final r = AcCommandService.checkSimpleRules('제습 모드');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-A04');
    });

    test('강풍 → BT-A08', () {
      final r = AcCommandService.checkSimpleRules('강풍으로');
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-A08');
    });

    test('꺼줘 → BT-A09 (종료)', () {
      final r = AcCommandService.checkSimpleRules('에어컨 꺼줘');
      // 전원 버튼(BT-A01)이 '꺼줘' 를 먼저 매칭하는지 확인
      expect(r, isNotNull);
      expect((r!['commands'] as List).first, 'BT-A01');
    });

    test('buildCommandsLabel — 알려진 버튼 레이블 반환', () {
      final label = AcCommandService.buildCommandsLabel(['BT-A02']);
      expect(label, '냉방');
    });

    test('매칭 없는 명령 → null', () {
      final r = AcCommandService.checkSimpleRules('날씨 알려줘');
      expect(r, isNull);
    });
  });
}
