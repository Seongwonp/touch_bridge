import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/speech_session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = SpeechSessionService.instance;

  setUp(service.resetForTest);
  tearDown(service.resetForTest);

  group('SpeechSessionService 이벤트 위임 (스택 최상단 화면만 수신)', () {
    // 배경: SpeechToText는 패키지 싱글톤이라 콜백이 최초 1회만 등록된다.
    // 화면별 개별 초기화 시 (a) 나중 화면의 콜백 미등록, (b) 스택 아래 화면이
    // 위 화면의 listen 이벤트를 받아 상태가 오염되는 문제가 있었다.
    test('이벤트는 가장 나중에 attach한 화면에만 전달된다', () {
      final received = <String>[];
      service.attach(
        SpeechClient(name: 'voice', onStatus: (s) => received.add('voice:$s')),
      );
      service.attach(
        SpeechClient(
          name: 'emergency',
          onStatus: (s) => received.add('emergency:$s'),
        ),
      );

      service.dispatchStatusForTest('listening');

      expect(received, ['emergency:listening'],
          reason: '스택 아래(voice) 화면이 이벤트를 받으면 상태 오염 재발');
    });

    test('최상단 화면 detach 후에는 이전 화면이 이벤트를 이어받는다', () {
      final received = <String>[];
      service.attach(
        SpeechClient(name: 'voice', onStatus: (s) => received.add('voice:$s')),
      );
      service.attach(
        SpeechClient(
          name: 'emergency',
          onStatus: (s) => received.add('emergency:$s'),
        ),
      );

      service.detach('emergency'); // 비상 화면 pop 시나리오
      service.dispatchStatusForTest('done');

      expect(received, ['voice:done']);
    });

    test('같은 이름으로 다시 attach하면 최상단으로 올라온다 (중복 없이)', () {
      service.attach(SpeechClient(name: 'voice'));
      service.attach(SpeechClient(name: 'emergency'));
      service.attach(SpeechClient(name: 'voice')); // 재진입

      expect(service.clientNamesForTest, ['emergency', 'voice']);
    });

    test('스택 중간 화면을 detach해도 최상단 수신자는 유지된다', () {
      final received = <String>[];
      service.attach(SpeechClient(name: 'a', onStatus: (s) => received.add('a')));
      service.attach(SpeechClient(name: 'b', onStatus: (s) => received.add('b')));
      service.attach(SpeechClient(name: 'c', onStatus: (s) => received.add('c')));

      service.detach('b');
      service.dispatchStatusForTest('x');

      expect(received, ['c']);
      expect(service.clientNamesForTest, ['a', 'c']);
    });

    test('아무도 attach하지 않았으면 이벤트는 조용히 버려진다 (예외 금지)', () {
      expect(() => service.dispatchStatusForTest('done'), returnsNormally);
      expect(() => service.dispatchErrorForTest('err'), returnsNormally);
    });

    test('에러 이벤트도 최상단 화면에만 전달된다', () {
      final received = <String>[];
      service.attach(
        SpeechClient(name: 'voice', onError: (e) => received.add('voice')),
      );
      service.attach(
        SpeechClient(name: 'emergency', onError: (e) => received.add('emergency')),
      );

      service.dispatchErrorForTest(StateError('stt error'));

      expect(received, ['emergency']);
    });
  });
}
