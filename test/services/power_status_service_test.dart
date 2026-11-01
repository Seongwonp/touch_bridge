import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/ble_service.dart';
import 'package:touch_bridge/services/esp32_motion_protocol.dart';
import 'package:touch_bridge/services/power_status_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PowerStatusService', () {
    late StreamController<String> lines;
    late PowerStatusService service;

    Future<void> send(String line) async {
      lines.add(line);
      await Future<void>.delayed(Duration.zero);
    }

    setUp(() {
      lines = StreamController<String>();
      service = PowerStatusService(
        lines: lines.stream,
        staleAfter: const Duration(milliseconds: 60),
      );
    });

    tearDown(() async {
      await service.dispose();
      await lines.close();
    });

    test('처음에는 unknown이다', () {
      expect(service.state, PowerState.unknown);
      expect(service.status.value.watts, isNull);
    });

    test('on/off 줄을 읽는다', () async {
      await send('{"event":"power","w":812.5,"state":"on"}');
      expect(service.state, PowerState.on);
      expect(service.status.value.watts, 812.5);
      await send('{"event":"power","w":0.0,"state":"off"}');
      expect(service.state, PowerState.off);
      expect(service.status.value.watts, 0);
    });

    test('기기가 unknown을 보내면 전력값을 0으로 만들지 않는다', () async {
      await send('{"event":"power","w":812.5,"state":"on"}');
      await send('{"event":"power","w":null,"state":"unknown"}');
      expect(service.state, PowerState.unknown);
      expect(service.status.value.watts, isNull);
    });

    test('잘못된 줄과 다른 줄은 무시한다', () async {
      await send('{"event":"power","w":10.0,"state":"on"}');
      for (final bad in [
        'ok',
        'STATE IDLE homed=1 bot=0 q=0 auth=ok',
        '{"event":"power","w":10',
        '{"event":"power","w":"많음","state":"off"}',
        '{"event":"power","w":null,"state":"off"}',
        '{"event":"power","w":-1,"state":"off"}',
        '{"event":"power","w":1,"state":"maybe"}',
        '{"event":"other","w":1,"state":"off"}',
        '{"version":2,"commandId":"a","state":"COMPLETED"}',
      ]) {
        await send(bad);
        expect(service.state, PowerState.on, reason: bad);
      }
    });

    test('5초 규칙: 유효한 줄이 끊기면 unknown으로 돌아간다', () async {
      await send('{"event":"power","w":10.0,"state":"on"}');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      await send('{"event":"power","w":11.0,"state":"on"}');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(service.state, PowerState.on, reason: '새 줄이 타이머를 다시 시작한다');
      await send('{"event":"power","w":1');
      await Future<void>.delayed(const Duration(milliseconds: 90));
      expect(service.state, PowerState.unknown, reason: '잘못된 줄은 신선도를 올리지 않는다');
      expect(service.status.value.watts, isNull);
    });
  });

  group('BleService 전력 줄 격리', () {
    final ble = BleService.instance;

    test('전력 줄은 응답 대기자를 완료시키지 않고 스트림에는 나간다', () async {
      final seen = <String>[];
      final sub = ble.responseStream.listen(seen.add);
      addTearDown(sub.cancel);

      final next = ble.nextResponseForTest();
      ble.injectNotifyForTest('{"event":"power","w":1.0,"state":"on"}\n');
      ble.injectNotifyForTest('AUTH_OK\n');

      expect(await next, 'AUTH_OK');
      await Future<void>.delayed(Duration.zero);
      expect(seen.first, '{"event":"power","w":1.0,"state":"on"}');
    });

    test('MTU로 쪼개진 전력 줄을 이어 붙이고 대기자는 건드리지 않는다', () async {
      final seen = <String>[];
      final sub = ble.responseStream.listen(seen.add);
      addTearDown(sub.cancel);

      final next = ble.nextResponseForTest();
      ble.injectNotifyForTest('{"event":"power","w"');
      ble.injectNotifyForTest(':812.5,"state":"on"}');
      ble.injectNotifyForTest('\n');
      ble.injectNotifyForTest('ok\n');

      expect(await next, 'ok');
      await Future<void>.delayed(Duration.zero);
      expect(seen, ['{"event":"power","w":812.5,"state":"on"}', 'ok']);
      expect(PowerStatusService.parseLine(seen.first)?.state, PowerState.on);
    });

    test('MTU로 쪼개진 STATE 줄은 한 줄로 대기자에게 간다', () async {
      final next = ble.nextResponseForTest();
      ble.injectNotifyForTest('STATE MOVING homed=1 ');
      ble.injectNotifyForTest('pos=(1.00, 2.00) bot=');
      ble.injectNotifyForTest('1 q=2 auth=ok\n');
      expect(
        await next,
        'STATE MOVING homed=1 pos=(1.00, 2.00) bot=1 q=2 auth=ok',
      );
    });

    test('재조립 뒤의 FAULT는 그대로 오류로 센다', () {
      final before = ble.deviceFaultCount;
      ble.injectNotifyForTest('{"event":"power","w":1.0,"state":"on"}\n');
      ble.injectNotifyForTest('FAULT BOT_TIMEOUT\n');
      expect(ble.deviceFaultCount, before + 1);
    });

    test('전력 줄은 모션 상태로 해석되지 않는다', () {
      expect(
        Esp32MotionStatus.tryParse('{"event":"power","w":1.0,"state":"on"}'),
        isNull,
      );
    });
  });
}
