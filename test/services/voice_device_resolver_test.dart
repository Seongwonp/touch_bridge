import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/voice_device_resolver.dart';

void main() {
  group('별명(aliases) 매칭', () {
    const washerWithAlias = RegisteredVoiceDevice(
      id: 'washer-1',
      name: '세탁기',
      aliases: ['우리집 세탁기', '큰 세탁기'],
    );
    const microwavePlain = RegisteredVoiceDevice(
      id: 'microwave-1',
      name: '전자레인지',
    );

    test('별명으로 불러도 해당 기기를 선택하고 별명을 명령에서 제거한다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '우리집 세탁기 표준 코스 시작',
        devices: const [washerWithAlias, microwavePlain],
      );

      expect(result.device?.id, 'washer-1');
      expect(result.commandText, '표준 코스 시작');
      expect(result.needsClarification, isFalse);
    });

    test('두 번째 별명도 동일하게 동작한다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '큰 세탁기 시작',
        devices: const [washerWithAlias, microwavePlain],
      );

      expect(result.device?.id, 'washer-1');
      expect(result.commandText, '시작');
    });

    test('서로 다른 기기가 이름/별명으로 함께 언급되면 되묻는다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '우리집 세탁기랑 전자레인지 시작',
        devices: const [washerWithAlias, microwavePlain],
      );

      expect(result.needsClarification, isTrue);
    });

    test('별명이 없는 기존 기기 JSON도 안전하게 파싱된다', () {
      final device = RegisteredVoiceDevice.fromJson({
        'id': 'x',
        'name': '기기',
      });
      expect(device.aliases, isEmpty);

      final withAliases = RegisteredVoiceDevice.fromJson({
        'id': 'y',
        'name': '기기',
        'aliases': ['별명1', 2, null, '별명2'], // 이물질 섞인 리스트
      });
      expect(withAliases.aliases, ['별명1', '별명2']);
    });
  });

  const microwave = RegisteredVoiceDevice(
    id: 'microwave-1',
    name: '전자레인지',
    bleId: 'esp32-1',
  );
  const washer = RegisteredVoiceDevice(id: 'washer-1', name: '세탁기');

  group('VoiceDeviceResolver.resolve', () {
    test('발화에 포함된 기기명을 우선 선택하고 명령 텍스트만 남긴다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '전자레인지 30초 시작',
        devices: const [microwave, washer],
      );

      expect(result.device?.id, 'microwave-1');
      expect(result.commandText, '30초 시작');
      expect(result.needsClarification, isFalse);
      expect(result.needsAction, isFalse);
    });

    test('기기명만 말하면 동작을 다시 묻는다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '전자레인지',
        devices: const [microwave, washer],
      );

      expect(result.device?.id, 'microwave-1');
      expect(result.needsAction, isTrue);
      expect(result.message, contains('어떤 동작'));
    });

    test('기기명이 없으면 선택된 기기를 사용한다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '1분 시작',
        devices: const [microwave, washer],
        preferredDeviceId: 'washer-1',
      );

      expect(result.device?.id, 'washer-1');
      expect(result.commandText, '1분 시작');
    });

    test('선택 기기 없이 여러 기기가 있으면 어떤 기기인지 되묻는다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '30초 시작',
        devices: const [microwave, washer],
      );

      expect(result.device, isNull);
      expect(result.needsClarification, isTrue);
      expect(result.message, contains('어떤 기기'));
    });

    test('등록된 기기가 없으면 보호자에게 기기 추가를 요청한다', () {
      final result = VoiceDeviceResolver.resolve(
        text: '30초 시작',
        devices: const [],
      );

      expect(result.needsClarification, isTrue);
      expect(result.message, contains('등록된 기기'));
    });
  });
}
