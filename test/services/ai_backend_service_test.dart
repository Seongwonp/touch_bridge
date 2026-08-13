import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/ai_backend_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    dotenv.testLoad(fileInput: 'AI_BACKEND_URL=http://127.0.0.1:8000');
  });

  group('AiBackendService.fetchDeviceProfile — deviceId 검증', () {
    const invalidIds = [
      '../etc/passwd', // path traversal
      'device/slash', // 슬래시
      'device with space', // 공백
      'device@name', // @ 특수문자
      'device#hash', // # 특수문자
      '', // 빈 문자열
    ];

    for (final id in invalidIds) {
      test('"$id" 은 ArgumentError를 던진다', () async {
        await expectLater(
          AiBackendService.instance.fetchDeviceProfile(id),
          throwsA(isA<ArgumentError>()),
        );
      });
    }

    test('65자 ID는 ArgumentError를 던진다', () async {
      final longId = 'a' * 65;
      await expectLater(
        AiBackendService.instance.fetchDeviceProfile(longId),
        throwsA(isA<ArgumentError>()),
      );
    });

    final validIds = [
      'esp32_001',
      'micro-wave-01',
      'DEVICE123',
      'a',
      'A-B_C',
      'a' * 64, // 정확히 64자 — 허용
    ];

    for (final id in validIds) {
      test(
        '"${id.length > 20 ? '${id.substring(0, 20)}…(${id.length}자)' : id}"'
        ' 은 ArgumentError를 던지지 않는다',
        () async {
          // 로컬 서버가 없으므로 네트워크 예외는 발생하지만,
          // ArgumentError(deviceId 검증 실패)는 발생하지 않아야 한다.
          await expectLater(
            AiBackendService.instance.fetchDeviceProfile(id),
            throwsA(isNot(isA<ArgumentError>())),
          );
        },
      );
    }
  });

  group('AiBackendService._validatedBaseUrl — scheme 검증', () {
    test('ftp:// scheme은 StateError를 던진다', () async {
      dotenv.testLoad(fileInput: 'AI_BACKEND_URL=ftp://example.com');
      await expectLater(
        AiBackendService.instance.parseVoiceCommand('테스트'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('scheme'),
          ),
        ),
      );
    });

    test('빈 URL은 StateError를 던진다', () async {
      dotenv.testLoad(fileInput: 'AI_BACKEND_URL=');
      await expectLater(
        AiBackendService.instance.parseVoiceCommand('테스트'),
        throwsA(isA<StateError>()),
      );
    });

    test('host가 없는 URL은 StateError를 던진다', () async {
      dotenv.testLoad(fileInput: 'AI_BACKEND_URL=https://');
      await expectLater(
        AiBackendService.instance.parseVoiceCommand('테스트'),
        throwsA(isA<StateError>()),
      );
    });

    test('유효한 http URL(디버그 모드)은 scheme 검증 StateError를 던지지 않는다', () async {
      // TestWidgetsFlutterBinding이 HTTP를 가로채 400을 반환하므로
      // "명령 파싱 API 오류: 400" StateError는 발생하지만,
      // scheme 관련 StateError('scheme' 또는 'HTTPS' 포함)는 발생하지 않아야 한다.
      dotenv.testLoad(fileInput: 'AI_BACKEND_URL=http://backend.invalid:8000');
      await expectLater(
        AiBackendService.instance.parseVoiceCommand('테스트'),
        throwsA(
          isNot(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              anyOf(contains('scheme'), contains('HTTPS')),
            ),
          ),
        ),
      );
    });
  });
}
