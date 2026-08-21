import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/ble_security_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BleSecuritySession newSession(List<String> log) =>
      BleSecuritySession(onLog: log.add);

  group('BleSecuritySession.authorizePhysicalAction (물리 동작 게이트)', () {
    test('키가 프로비저닝되지 않았으면 경고 로그와 함께 허용한다 (fail-open)', () async {
      final log = <String>[];
      final session = newSession(log);
      session.setPairKeyForTest(null);

      final ok = await session.authorizePhysicalAction(
        sendAndWaitAck: (payload, {timeout = const Duration(seconds: 5)}) async {
          fail('키가 없으면 핸드셰이크를 시도하면 안 된다');
        },
      );

      expect(ok, isTrue);
      expect(log.any((l) => l.contains('no pair key')), isTrue);
    });

    test('키가 있으면 challenge/auth 핸드셰이크를 요구하고 성공 시 허용한다', () async {
      final log = <String>[];
      final session = newSession(log);
      session.setPairKeyForTest('secret-key');

      final actions = <String>[];
      final ok = await session.authorizePhysicalAction(
        sendAndWaitAck: (payload, {timeout = const Duration(seconds: 5)}) async {
          final action = payload['action'] as String;
          actions.add(action);
          if (action == 'challenge') return 'NONCE:abc123';
          if (action == 'auth') {
            // mac이 실제 HMAC으로 계산돼 왔는지(비어있지 않은 hex) 확인.
            final mac = payload['mac'] as String;
            expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(mac), isTrue);
            return 'AUTH_OK';
          }
          return 'ERROR:UNEXPECTED';
        },
      );

      expect(ok, isTrue);
      expect(actions, ['challenge', 'auth']);
    });

    test('키가 있는데 인증이 실패하면 차단한다 (fail-closed)', () async {
      final session = newSession(<String>[]);
      session.setPairKeyForTest('secret-key');

      final ok = await session.authorizePhysicalAction(
        sendAndWaitAck: (payload, {timeout = const Duration(seconds: 5)}) async {
          final action = payload['action'] as String;
          if (action == 'challenge') return 'NONCE:abc123';
          return 'AUTH_FAIL';
        },
      );

      expect(ok, isFalse);
    });

    test('NONCE 형식이 아닌 응답이면 차단한다', () async {
      final session = newSession(<String>[]);
      session.setPairKeyForTest('secret-key');

      final ok = await session.authorizePhysicalAction(
        sendAndWaitAck: (payload, {timeout = const Duration(seconds: 5)}) async =>
            'GRBL_STATUS:<Idle>',
      );

      expect(ok, isFalse);
    });

    test('인증 성공 후에는 세션이 유지되어 핸드셰이크를 반복하지 않는다', () async {
      final session = newSession(<String>[]);
      session.setPairKeyForTest('secret-key');

      var handshakes = 0;
      Future<String> fakeSend(
        Map<String, dynamic> payload, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
        final action = payload['action'] as String;
        if (action == 'challenge') {
          handshakes++;
          return 'NONCE:n1';
        }
        return 'AUTH_OK';
      }

      expect(
        await session.authorizePhysicalAction(sendAndWaitAck: fakeSend),
        isTrue,
      );
      expect(
        await session.authorizePhysicalAction(sendAndWaitAck: fakeSend),
        isTrue,
      );
      expect(handshakes, 1, reason: '유효한 세션이 있으면 재인증하지 않는다');
    });

    test('reset() 후에는 다시 인증을 요구한다 (연결 해제 시 세션 무효화)', () async {
      final session = newSession(<String>[]);
      session.setPairKeyForTest('secret-key');

      var handshakes = 0;
      Future<String> fakeSend(
        Map<String, dynamic> payload, {
        Duration timeout = const Duration(seconds: 5),
      }) async {
        final action = payload['action'] as String;
        if (action == 'challenge') {
          handshakes++;
          return 'NONCE:n$handshakes';
        }
        return 'AUTH_OK';
      }

      await session.authorizePhysicalAction(sendAndWaitAck: fakeSend);
      session.reset();
      await session.authorizePhysicalAction(sendAndWaitAck: fakeSend);

      expect(handshakes, 2);
    });

    test('같은 nonce에 다른 키는 다른 MAC을 만든다 (HMAC 검증)', () async {
      String? macA;
      String? macB;

      // 세션 A
      final a = newSession(<String>[]);
      a.setPairKeyForTest('key-A');
      await a.authorizePhysicalAction(
        sendAndWaitAck: (payload, {timeout = const Duration(seconds: 5)}) async {
          if (payload['action'] == 'challenge') return 'NONCE:same-nonce';
          macA = payload['mac'] as String;
          return 'AUTH_OK';
        },
      );
      // 세션 B
      final b = newSession(<String>[]);
      b.setPairKeyForTest('key-B');
      await b.authorizePhysicalAction(
        sendAndWaitAck: (payload, {timeout = const Duration(seconds: 5)}) async {
          if (payload['action'] == 'challenge') return 'NONCE:same-nonce';
          macB = payload['mac'] as String;
          return 'AUTH_OK';
        },
      );

      expect(macA, isNotNull);
      expect(macB, isNotNull);
      expect(macA, isNot(macB));
    });
  });
}
