import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/models/handoff_report.dart';
import 'package:touch_bridge/services/device_mapping_service.dart';
import 'package:touch_bridge/services/guardian_handoff_service.dart';
import 'package:touch_bridge/services/home_device_store.dart';

void main() {
  group('HandoffReport', () {
    test('전부 통과하면 allPassed와 정직한 요약을 준다', () {
      const report = HandoffReport(
        items: [
          HandoffCheckItem(label: 'A', passed: true),
          HandoffCheckItem(label: 'B', passed: true),
        ],
      );
      expect(report.allPassed, isTrue);
      expect(report.passCount, 2);
      expect(report.spokenSummary, contains('모두 통과'));
    });

    test('실패 항목이 있으면 첫 실패의 원인을 우선 말한다', () {
      const report = HandoffReport(
        items: [
          HandoffCheckItem(label: 'A', passed: true),
          HandoffCheckItem(label: 'B', passed: false, detail: 'B 원인'),
          HandoffCheckItem(label: 'C', passed: false, detail: 'C 원인'),
        ],
      );
      expect(report.allPassed, isFalse);
      expect(report.passCount, 1);
      expect(report.spokenSummary, contains('B'));
      expect(report.spokenSummary, contains('B 원인'));
      expect(report.spokenSummary, contains('1건 더')); // C까지 포함해 남은 건수 안내
    });
  });

  group('GuardianHandoffService.run', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('기기 미등록·매핑 없음이면 관련 항목이 실패로 표시된다', () async {
      final report = await GuardianHandoffService.instance.run(
        deviceId: 'not-registered-device',
      );

      final byLabel = {for (final i in report.items) i.label: i};
      expect(byLabel['기기가 홈 화면 목록에 등록됨']!.passed, isFalse);
      expect(byLabel['버튼 위치가 매핑됨']!.passed, isFalse);
      // 매핑이 없으면 dry-run 명령 생성 항목 자체가 추가되지 않는다(대표 버튼이 없으므로).
      expect(byLabel.containsKey('버튼 간격 값이 정상'), isTrue);
    });

    test('기기 등록 + 매핑이 있으면 관련 항목이 통과로 표시된다', () async {
      const deviceId = 'demo-microwave';
      await HomeDeviceStore.saveDevices([
        {'id': deviceId, 'name': '데모 전자레인지'},
      ]);
      const profile = DeviceMappingProfile(
        rows: 3,
        cols: 3,
        originX: 10,
        originY: 10,
        pitchX: 20,
        pitchY: 20,
        buttonMap: {'BT-05': (row: 1, col: 1)},
      );
      await DeviceMappingService.instance.save(deviceId, profile);

      final report = await GuardianHandoffService.instance.run(
        deviceId: deviceId,
      );

      final byLabel = {for (final i in report.items) i.label: i};
      expect(byLabel['기기가 홈 화면 목록에 등록됨']!.passed, isTrue);
      expect(byLabel['버튼 위치가 매핑됨']!.passed, isTrue);
      expect(byLabel['버튼 간격 값이 정상']!.passed, isTrue);
      // dry-run이므로 BLE 연결 없이도 명령 생성 자체는 통과해야 한다.
      expect(byLabel['BT-05 버튼 명령 생성 확인']!.passed, isTrue);
    });

    test('버튼맵 없이 좌표(그리드)만 저장한 경우도 매핑 완료로 인정한다', () async {
      // "사진 없이 좌표로 설정" 경로는 buttonMap을 채우지 않고 그리드
      // fallback(MicrowaveCommandService.btnToGrid)에 의존한다. buttonMap이
      // 비어 있다는 이유로 "매핑 안 됨"이라 오판하면 안 된다.
      const deviceId = 'coordinate-only-device';
      await HomeDeviceStore.saveDevices([
        {'id': deviceId, 'name': '좌표로 설정한 기기'},
      ]);
      const profile = DeviceMappingProfile(
        rows: 3,
        cols: 3,
        originX: 0,
        originY: 0,
        pitchX: 20,
        pitchY: 20,
        buttonMap: {},
      );
      await DeviceMappingService.instance.save(deviceId, profile);

      final report = await GuardianHandoffService.instance.run(
        deviceId: deviceId,
      );

      final byLabel = {for (final i in report.items) i.label: i};
      expect(byLabel['버튼 위치가 매핑됨']!.passed, isTrue);
      expect(byLabel['버튼 간격 값이 정상']!.passed, isTrue);
      // buttonMap이 비어 있으므로 그리드 fallback 대표 버튼(BT-05)으로 검증한다.
      expect(byLabel['BT-05 버튼 명령 생성 확인']!.passed, isTrue);
    });
  });
}
