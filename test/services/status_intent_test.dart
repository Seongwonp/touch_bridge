import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/run_status_service.dart';
import 'package:touch_bridge/services/status_intent.dart';

void main() {
  tearDown(RunStatusService.instance.resetForTest);

  group('StatusIntent.matches (상태 질의 판별)', () {
    test('상태 질의 표현을 인식한다', () {
      for (final t in [
        '얼마나 남았어',
        '얼마나남았지',
        '남은 시간 알려줘',
        '몇 분 남았어',
        '지금 뭐 해',
        '지금 뭐하고 있어',
        '진행 상황 어때',
        '상태 알려줘',
        '지금 작동 중이야?',
        '돌아가고 있어?',
      ]) {
        expect(StatusIntent.matches(t), isTrue, reason: t);
      }
    });

    test('일반 명령은 상태 질의로 오인하지 않는다', () {
      for (final t in [
        '30초 시작',
        '전자레인지 돌려줘',
        '일시정지 상태로 해줘', // '상태'가 들어가도 질문형이 아니면 매칭 금지
        '취소해줘',
      ]) {
        expect(StatusIntent.matches(t), isFalse, reason: t);
      }
    });
  });

  group('StatusIntent.buildResponseFrom (응답 생성)', () {
    test('작동 중이면 기기명과 남은 시간을 답한다', () {
      final r = StatusIntent.buildResponseFrom(
        running: true,
        secondsLeft: 150,
        runningDeviceName: '전자레인지',
        bleConnected: true,
        activeDeviceName: '전자레인지',
      );
      expect(r, contains('전자레인지'));
      expect(r, contains('2분 30초'));
      expect(r, contains('남았습니다'));
    });

    test('분/초 단수 표현: 60초 배수는 분만, 60초 미만은 초만 말한다', () {
      expect(
        StatusIntent.buildResponseFrom(
          running: true,
          secondsLeft: 120,
          runningDeviceName: '기기',
          bleConnected: true,
        ),
        contains('2분 남았습니다'),
      );
      expect(
        StatusIntent.buildResponseFrom(
          running: true,
          secondsLeft: 45,
          runningDeviceName: '기기',
          bleConnected: true,
        ),
        contains('45초 남았습니다'),
      );
    });

    test('작동 중이 아니면 선택 기기와 연결 상태를 답한다', () {
      final r = StatusIntent.buildResponseFrom(
        running: false,
        secondsLeft: 0,
        bleConnected: false,
        activeDeviceName: '세탁기',
      );
      expect(r, contains('작동 중인 기기는 없어요'));
      expect(r, contains('세탁기'));
      expect(r, contains('연결되어 있지 않아요'));
    });

    test('선택 기기가 없으면 그 사실도 답한다', () {
      final r = StatusIntent.buildResponseFrom(
        running: false,
        secondsLeft: 0,
        bleConnected: true,
        activeDeviceName: null,
      );
      expect(r, contains('선택된 기기가 없고'));
      expect(r, contains('연결되어 있어요'));
    });
  });

  group('RunStatusService (실행 상태 전역 추적)', () {
    test('start/tick/stop 라이프사이클을 추적한다', () {
      final svc = RunStatusService.instance;
      expect(svc.isRunning, isFalse);

      svc.start(deviceName: '전자레인지', seconds: 90);
      expect(svc.isRunning, isTrue);
      expect(svc.secondsLeft, 90);
      expect(svc.deviceName, '전자레인지');

      svc.tick(60);
      expect(svc.secondsLeft, 60);

      svc.stop();
      expect(svc.isRunning, isFalse);
      expect(svc.secondsLeft, 0);
    });

    test('stop 후 상태 질의는 "작동 중"이라 답하지 않는다 (정직성)', () {
      RunStatusService.instance.start(deviceName: '전자레인지', seconds: 90);
      RunStatusService.instance.stop();

      final r = StatusIntent.buildResponseFrom(
        running: RunStatusService.instance.isRunning,
        secondsLeft: RunStatusService.instance.secondsLeft,
        runningDeviceName: RunStatusService.instance.deviceName,
        bleConnected: false,
        activeDeviceName: null,
      );
      expect(r, contains('작동 중인 기기는 없어요'));
    });
  });
}
