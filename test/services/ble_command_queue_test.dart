import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/ble_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BLE 명령 직렬화 큐 (_withCommandLock)', () {
    // 배경: 단일 GATT characteristic에 여러 경로가 동시에 쓰면 응답이 엉뚱한
    // 호출로 배달되거나 유실됐다(공유 completer 경쟁). 모든 write/응답 대기는
    // 큐로 직렬화되며, 이 계약이 깨지면 그 경쟁이 재발한다.

    test('명령은 요청 순서대로 하나씩 실행된다', () async {
      final order = <String>[];
      final ble = BleService.instance;

      final first = ble.runInCommandQueueForTest(() async {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        order.add('first');
        return 1;
      });
      final second = ble.runInCommandQueueForTest(() async {
        order.add('second');
        return 2;
      });

      await Future.wait([first, second]);
      expect(order, ['first', 'second'],
          reason: '늦게 들어온 짧은 작업이 먼저 실행되면 직렬화가 깨진 것');
    });

    test('앞선 명령이 예외로 끝나도 다음 명령은 실행된다', () async {
      final ble = BleService.instance;

      final failing = ble.runInCommandQueueForTest<void>(() async {
        throw StateError('전송 실패 시뮬레이션');
      });
      final next = ble.runInCommandQueueForTest(() async => 'ran');

      await expectLater(failing, throwsStateError);
      expect(await next, 'ran', reason: '실패한 명령이 큐를 영구히 막으면 안 된다');
    });

    test('중첩 실행 결과가 호출자에게 올바르게 반환된다', () async {
      final ble = BleService.instance;
      final results = await Future.wait([
        ble.runInCommandQueueForTest(() async => 'a'),
        ble.runInCommandQueueForTest(() async => 'b'),
        ble.runInCommandQueueForTest(() async => 'c'),
      ]);
      expect(results, ['a', 'b', 'c']);
    });
  });

  group('sendRawWithResponse 오버라이드 경로', () {
    tearDown(() => BleService.instance.setSendRawOverride(null));

    test('오버라이드 성공 시 OK, 실패 시 null을 반환한다', () async {
      BleService.instance.setSendRawOverride((_) async => true);
      expect(await BleService.instance.sendRawWithResponse('\$\$'), 'OK');

      BleService.instance.setSendRawOverride((_) async => false);
      expect(await BleService.instance.sendRawWithResponse('\$\$'), isNull);
    });
  });
}
