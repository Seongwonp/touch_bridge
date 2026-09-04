import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/mapping_verification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  MappingVerificationRecord record({
    String id = 'record-1',
    bool executionOk = true,
    bool userPassed = true,
    double? controllerErrorMm = 0.2,
    double? errorX = 0.3,
    double? errorY = 0.4,
  }) => MappingVerificationRecord(
    id: id,
    buttonId: 'BT-05',
    label: '시작',
    mode: MappingVerificationMode.moveOnly,
    targetXmm: 42.5,
    targetYmm: 18.25,
    executionOk: executionOk,
    userPassed: userPassed,
    controllerErrorMm: controllerErrorMm,
    measuredErrorXmm: errorX,
    measuredErrorYmm: errorY,
    createdAt: DateTime.utc(2026, 9, 4),
  );

  test('엔코더 오차와 실측 X/Y 오차를 기기별로 저장하고 복원한다', () async {
    final service = MappingVerificationService.instance;
    await service.add('device-1', record());

    final loaded = await service.load('device-1');

    expect(loaded, hasLength(1));
    expect(loaded.single.buttonId, 'BT-05');
    expect(loaded.single.controllerErrorMm, 0.2);
    expect(loaded.single.measuredRadialErrorMm, closeTo(0.5, 0.0001));
    expect(loaded.single.passesTolerance(0.7), isTrue);
    expect(await service.load('another-device'), isEmpty);
  });

  test('실행 실패, 사용자 실패, 허용값 초과는 모두 통과로 계산하지 않는다', () {
    expect(record(executionOk: false).passesTolerance(0.7), isFalse);
    expect(record(userPassed: false).passesTolerance(0.7), isFalse);
    expect(record(controllerErrorMm: 0.8).passesTolerance(0.7), isFalse);
    expect(record(errorX: 0.6, errorY: 0.6).passesTolerance(0.7), isFalse);
  });

  test('기기별 최근 기록 100개만 유지한다', () async {
    final service = MappingVerificationService.instance;
    for (var i = 0; i < 105; i++) {
      await service.add('device-1', record(id: 'record-$i'));
    }

    final loaded = await service.load('device-1');

    expect(loaded, hasLength(MappingVerificationService.maxRecordsPerDevice));
    expect(loaded.first.id, 'record-5');
    expect(loaded.last.id, 'record-104');
  });

  test('손상된 저장값은 예외 없이 빈 기록으로 복구한다', () async {
    SharedPreferences.setMockInitialValues({
      'mapping_verification_device-1': '{broken',
    });

    expect(await MappingVerificationService.instance.load('device-1'), isEmpty);
  });
}
