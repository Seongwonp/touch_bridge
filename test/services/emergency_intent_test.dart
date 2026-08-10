import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/emergency_intent.dart';

void main() {
  group('EmergencyIntent.matches', () {
    test('중단 토큰(멈춰/정지/그만/중단/stop)을 모두 인식한다', () {
      for (final token in ['멈춰', '멈춤', '정지', '그만', '중단', 'stop']) {
        expect(EmergencyIntent.matches(token), isTrue, reason: token);
      }
    });

    test('문장 안에 포함돼도 인식하고 대소문자를 무시한다', () {
      expect(EmergencyIntent.matches('지금 당장 그만해'), isTrue);
      expect(EmergencyIntent.matches('please STOP now'), isTrue);
    });

    test('관련 없는 발화는 인식하지 않는다', () {
      expect(EmergencyIntent.matches('전자레인지 30초 시작'), isFalse);
      expect(EmergencyIntent.matches('공기청정기 켜줘'), isFalse);
    });
  });

  group('EmergencyStopOutcome.fromAck', () {
    test('명시적 성공 신호(ok/stop 포함)만 정지 확인(acknowledged=true)으로 본다', () {
      final ok = EmergencyStopOutcome.fromAck('OK');
      expect(ok.acknowledged, isTrue);
      expect(ok.sent, isTrue);

      final ack = EmergencyStopOutcome.fromAck('STOPPED');
      expect(ack.acknowledged, isTrue);
    });

    test('정지와 무관한 알림은 "확인됨"으로 오판하지 않는다 (ACK 스푸핑 방지)', () {
      // BLE notify는 정지 명령과 무관한 센서값 등도 같은 completer로 흘려보낼 수 있다.
      // "ERROR로 시작하지 않으면 성공"처럼 느슨하게 판정하면 이런 알림을
      // "안전하게 멈췄음"으로 오판하는 안전 결함이 된다.
      for (final noise in ['TEMP:40', 'ALARM:9', 'HW: idle', '']) {
        final o = EmergencyStopOutcome.fromAck(noise);
        expect(o.acknowledged, isFalse, reason: noise);
        expect(o.sent, isTrue, reason: noise);
      }
    });

    test('NOT_CONNECTED는 전송 실패(sent=false)로 본다', () {
      final o = EmergencyStopOutcome.fromAck('ERROR:NOT_CONNECTED');
      expect(o.acknowledged, isFalse);
      expect(o.sent, isFalse);
      expect(o.message, contains('연결된 기기가 없습니다'));
    });

    test('TIMEOUT은 전송됐지만 미확인(sent=true, acknowledged=false)으로 본다', () {
      final o = EmergencyStopOutcome.fromAck('ERROR:TIMEOUT');
      expect(o.sent, isTrue);
      expect(o.acknowledged, isFalse);
      expect(o.message, contains('보냈지만'));
    });

    test('그 외 오류는 전송 실패로 본다', () {
      final o = EmergencyStopOutcome.fromAck('ERROR:WRITE_FAILED');
      expect(o.acknowledged, isFalse);
      expect(o.sent, isFalse);
      expect(o.message, contains('다시 시도'));
    });
  });
}
