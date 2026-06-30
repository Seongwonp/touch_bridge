import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/voice_device_resolver.dart';

void main() {
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
