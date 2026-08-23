import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/last_command_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LastCommandService.instance.resetForTest();
  });

  group('LastCommandService (아까 그거 다시)', () {
    test('기록한 명령을 그대로 복원한다', () async {
      await LastCommandService.instance.record(
        data: {
          'action': 'MICROWAVE_CONTROL',
          'commands': ['BT-02', 'BT-05'],
          'message': '30초 조리를 시작합니다.',
        },
        deviceId: 'microwave-1',
        deviceName: '전자레인지',
        description: '30초 조리를 시작합니다.',
      );

      final loaded = await LastCommandService.instance.load();

      expect(loaded, isNotNull);
      expect(loaded!.deviceId, 'microwave-1');
      expect(loaded.deviceName, '전자레인지');
      expect(loaded.data['action'], 'MICROWAVE_CONTROL');
      expect(loaded.data['commands'], ['BT-02', 'BT-05']);
      expect(loaded.description, contains('30초'));
    });

    test('앱 재시작(캐시 초기화) 후에도 prefs에서 복원한다', () async {
      await LastCommandService.instance.record(
        data: {'action': 'WASHER_CONTROL', 'commands': ['BT-W01']},
        deviceId: 'washer-1',
        deviceName: '세탁기',
        description: '표준 코스',
      );

      // 앱 재시작 시뮬레이션: 메모리 캐시만 비운다 (prefs는 유지).
      LastCommandService.instance.resetForTest();

      final loaded = await LastCommandService.instance.load();
      expect(loaded?.deviceName, '세탁기');
    });

    test('기록이 없으면 null (재실행 요청에 정직하게 "없음" 응답 가능)', () async {
      expect(await LastCommandService.instance.load(), isNull);
    });

    test('손상된 저장값은 조용히 무시하고 null을 반환한다', () async {
      SharedPreferences.setMockInitialValues({
        'last_voice_command_v1': '{{{broken json',
      });
      LastCommandService.instance.resetForTest();

      expect(await LastCommandService.instance.load(), isNull);
    });
  });
}
