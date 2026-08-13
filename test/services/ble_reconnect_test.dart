import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/ble_service.dart';

/// BLE 자동 재연결 상태 머신 단위 테스트.
///
/// 타이머 기반 백오프(2초→4초→8초) 흐름은 실기기 통합 테스트에서 검증한다.
/// 여기서는 순수 상태 머신 계약(스트림 이벤트·플래그·초기화)만 검증한다.
void main() {
  final ble = BleService.instance;

  setUp(() {
    ble.resetReconnectStateForTest();
    ble.clearTestOverrides();
  });

  tearDown(() {
    ble.resetReconnectStateForTest();
    ble.clearTestOverrides();
  });

  group('BleReconnectState enum', () {
    test('세 가지 값(reconnecting / reconnected / failed)을 가진다', () {
      expect(BleReconnectState.values.length, 3);
      expect(
        BleReconnectState.values,
        containsAll([
          BleReconnectState.reconnecting,
          BleReconnectState.reconnected,
          BleReconnectState.failed,
        ]),
      );
    });
  });

  group('초기 상태', () {
    test('isReconnecting 는 false 다', () {
      expect(ble.isReconnectingForTest, isFalse);
    });

    test('autoReconnectTargetId 는 null 이다', () {
      expect(ble.autoReconnectTargetIdForTest, isNull);
    });

    test('reconnectAttempt 는 0 이다', () {
      expect(ble.reconnectAttemptForTest, 0);
    });
  });

  group('reconnectStateStream', () {
    test('broadcast stream — 복수 리스너 동시 구독 가능', () {
      final sub1 = ble.reconnectStateStream.listen((_) {});
      final sub2 = ble.reconnectStateStream.listen((_) {});
      // 예외 없이 구독됐으면 성공
      expect(sub1, isNotNull);
      expect(sub2, isNotNull);
      sub1.cancel();
      sub2.cancel();
    });

    test('emitReconnectStateForTest — reconnecting 이벤트 수신', () async {
      final events = <BleReconnectState>[];
      final sub = ble.reconnectStateStream.listen(events.add);

      ble.emitReconnectStateForTest(BleReconnectState.reconnecting);
      await Future<void>.delayed(Duration.zero);

      expect(events, [BleReconnectState.reconnecting]);
      await sub.cancel();
    });

    test('emitReconnectStateForTest — reconnected 이벤트 수신', () async {
      final events = <BleReconnectState>[];
      final sub = ble.reconnectStateStream.listen(events.add);

      ble.emitReconnectStateForTest(BleReconnectState.reconnected);
      await Future<void>.delayed(Duration.zero);

      expect(events, [BleReconnectState.reconnected]);
      await sub.cancel();
    });

    test('emitReconnectStateForTest — failed 이벤트 수신', () async {
      final events = <BleReconnectState>[];
      final sub = ble.reconnectStateStream.listen(events.add);

      ble.emitReconnectStateForTest(BleReconnectState.failed);
      await Future<void>.delayed(Duration.zero);

      expect(events, [BleReconnectState.failed]);
      await sub.cancel();
    });

    test('여러 이벤트를 순서대로 수신한다', () async {
      final events = <BleReconnectState>[];
      final sub = ble.reconnectStateStream.listen(events.add);

      ble.emitReconnectStateForTest(BleReconnectState.reconnecting);
      ble.emitReconnectStateForTest(BleReconnectState.failed);
      await Future<void>.delayed(Duration.zero);

      expect(events, [
        BleReconnectState.reconnecting,
        BleReconnectState.failed,
      ]);
      await sub.cancel();
    });
  });

  group('isConnectedStream', () {
    test('connectionStateStream 와 독립적으로 구독 가능', () {
      final sub = ble.isConnectedStream.listen((_) {});
      expect(sub, isNotNull);
      sub.cancel();
    });

    test('초기 연결이 없으면 스트림에서 이벤트 없음 (미연결 상태)', () async {
      final received = <bool>[];
      final sub = ble.isConnectedStream.listen(received.add);
      await Future<void>.delayed(Duration.zero);
      // connectionStateStream 이 emit 하지 않으면 isConnectedStream 도 없음
      expect(received, isEmpty);
      await sub.cancel();
    });
  });

  group('resetReconnectStateForTest', () {
    test('상태 초기화 후 플래그가 모두 기본값으로 돌아온다', () {
      // 상태를 임의로 변경
      ble.emitReconnectStateForTest(BleReconnectState.reconnecting);

      ble.resetReconnectStateForTest();

      expect(ble.isReconnectingForTest, isFalse);
      expect(ble.autoReconnectTargetIdForTest, isNull);
      expect(ble.reconnectAttemptForTest, 0);
    });
  });

  group('connect override — 실패 시나리오', () {
    test('connect override 가 false 를 반환하면 connect() 도 false 를 반환한다', () async {
      ble.setTestOverrides(connect: (_) async => false);
      final result = await ble.connect('test-device-id');
      expect(result, isFalse);
    });

    test('connect override 가 true 를 반환하면 connect() 도 true 를 반환한다', () async {
      ble.setTestOverrides(connect: (_) async => true);
      final result = await ble.connect('test-device-id');
      expect(result, isTrue);
    });
  });

  group('isConnected', () {
    test('비연결 상태에서 isConnected 는 false 다', () {
      expect(ble.isConnected, isFalse);
    });

    test('demo mode 활성화 시 isConnected 는 true 다', () {
      ble.enableDemoMode('demo-device');
      expect(ble.isConnected, isTrue);
      // teardown 에서 clearTestOverrides 만 호출하므로 demoMode 는 수동 reset
      // 다음 테스트는 setUp 에서 resetReconnectStateForTest 가 호출된다
    });
  });
}
