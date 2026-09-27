import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/emergency_intent.dart';
import 'package:touch_bridge/services/single_tap_stop_controller.dart';

void main() {
  group('SingleTapStopController (실행 중 단일 탭 정지 — 리뷰 #3)', () {
    test('한 번 탭으로 확인 없이 정지 경로를 부르고 결과를 돌려준다', () async {
      var calls = 0;
      final c = SingleTapStopController(stop: () async {
        calls++;
        return EmergencyStopOutcome.fromAck('STOPPED');
      });

      final outcome = await c.requestStop();

      expect(calls, 1);
      expect(outcome, isNotNull);
      expect(outcome!.acknowledged, isTrue);
      expect(c.lastOutcome, same(outcome));
      expect(c.inFlight, isFalse);
      expect(c.canRetry, isFalse, reason: '확인된 정지는 재시도 대상이 아니다');
    });

    test('요청이 진행 중일 때의 중복 탭은 새 정지 명령을 만들지 않는다', () async {
      var calls = 0;
      final gate = Completer<EmergencyStopOutcome>();
      final c = SingleTapStopController(stop: () {
        calls++;
        return gate.future;
      });

      final first = c.requestStop();
      expect(c.inFlight, isTrue);
      final second = await c.requestStop(); // 진행 중 중복 탭
      final third = await c.requestStop();

      expect(second, isNull);
      expect(third, isNull);
      expect(calls, 1, reason: '정지 명령이 중복 전송되면 안 된다');

      gate.complete(EmergencyStopOutcome.fromAck('ERROR:TIMEOUT'));
      final outcome = await first;
      expect(outcome!.sent, isTrue);
      expect(outcome.acknowledged, isFalse);
      expect(c.inFlight, isFalse);
    });

    test('실패·미확인 뒤에는 다시 탭해 재시도할 수 있다', () async {
      final acks = ['ERROR:WRITE_FAILED', 'ERROR:TIMEOUT', 'STOPPED'];
      var i = 0;
      final c = SingleTapStopController(
        stop: () async => EmergencyStopOutcome.fromAck(acks[i++]),
      );

      final failed = await c.requestStop();
      expect(failed!.sent, isFalse);
      expect(c.canRetry, isTrue);

      final unconfirmed = await c.requestStop();
      expect(unconfirmed!.sent, isTrue);
      expect(unconfirmed.acknowledged, isFalse);
      expect(c.canRetry, isTrue);

      final ok = await c.requestStop();
      expect(ok!.acknowledged, isTrue);
      expect(c.canRetry, isFalse);
      expect(c.requestCount, 3);
    });

    test('결과는 ACK 확인 / 미확인 / 전송 실패 세 가지로 구분되고 문구가 서로 다르다', () async {
      Future<EmergencyStopOutcome> run(String ack) async {
        final c = SingleTapStopController(
          stop: () async => EmergencyStopOutcome.fromAck(ack),
        );
        return (await c.requestStop())!;
      }

      final confirmed = await run('STOPPED');
      final unconfirmed = await run('ERROR:TIMEOUT');
      final failed = await run('ERROR:NOT_CONNECTED');
      // 무관한 센서 알림은 확인으로 치지 않는다.
      final unrelated = await run('TEMP_OK');

      expect(confirmed.acknowledged, isTrue);
      expect(unconfirmed.sent && !unconfirmed.acknowledged, isTrue);
      expect(failed.sent, isFalse);
      expect(unrelated.acknowledged, isFalse);
      expect({confirmed.message, unconfirmed.message, failed.message}.length, 3);
      expect(unconfirmed.message, isNot(contains('멈췄습니다')),
          reason: 'ACK 없이 정지 완료라고 말하면 안 된다');
      expect(failed.message, isNot(contains('멈췄습니다')));
    });

    test('정지 경로가 예외를 던지면 전송 실패로 보고하고 재시도 가능하다', () async {
      var first = true;
      final c = SingleTapStopController(stop: () async {
        if (first) {
          first = false;
          throw StateError('boom');
        }
        return EmergencyStopOutcome.fromAck('STOPPED');
      });

      final outcome = await c.requestStop();
      expect(outcome!.sent, isFalse);
      expect(outcome.acknowledged, isFalse);
      expect(c.inFlight, isFalse);
      expect(c.canRetry, isTrue);

      final retry = await c.requestStop();
      expect(retry!.acknowledged, isTrue);
    });

    test('요청 대기 중 dispose돼도 늦은 응답이 리스너를 깨우거나 예외를 내지 않는다', () async {
      final gate = Completer<EmergencyStopOutcome>();
      final c = SingleTapStopController(stop: () => gate.future);
      var notified = 0;
      c.addListener(() => notified++);

      final pending = c.requestStop();
      expect(notified, 1);
      c.dispose();

      gate.complete(EmergencyStopOutcome.fromAck('STOPPED'));
      final outcome = await pending;

      expect(outcome!.acknowledged, isTrue, reason: '결과 자체는 호출자에게 돌려준다');
      expect(notified, 1, reason: 'dispose 뒤에는 notifyListeners를 부르지 않는다');
    });

    test('reset은 진행 중이 아닐 때만 이전 결과를 지운다', () async {
      final c = SingleTapStopController(
        stop: () async => EmergencyStopOutcome.fromAck('ERROR:TIMEOUT'),
      );
      await c.requestStop();
      expect(c.lastOutcome, isNotNull);
      c.reset();
      expect(c.lastOutcome, isNull);
    });
  });
}
