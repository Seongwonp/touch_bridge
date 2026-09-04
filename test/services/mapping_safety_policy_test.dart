import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/mapping_safety_policy.dart';

void main() {
  group('MappingSafetyPolicy', () {
    test('시작과 취소 논리 버튼은 이름이 바뀌어도 위험 버튼이다', () {
      expect(
        MappingSafetyPolicy.classify(buttonId: 'BT-05', label: '동작'),
        MappingButtonRisk.critical,
      );
      expect(
        MappingSafetyPolicy.classify(buttonId: 'BT-06', label: '되돌리기'),
        MappingButtonRisk.critical,
      );
    });

    test('출력·전원·결제 등 기기 상태를 바꾸는 라벨은 추가 확인 대상이다', () {
      for (final label in ['출력', '전원 켜기', '결제', 'Print', 'Confirm']) {
        expect(
          MappingSafetyPolicy.requiresExtraConfirmation(
            buttonId: 'BT-01',
            label: label,
          ),
          isTrue,
          reason: '$label 라벨을 위험 버튼으로 분류해야 한다',
        );
      }
    });

    test('시간 추가 같은 일반 버튼은 표준 확인만 사용한다', () {
      expect(
        MappingSafetyPolicy.classify(buttonId: 'BT-01', label: '10초 추가'),
        MappingButtonRisk.standard,
      );
    });
  });
}
