import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/safety/emergency_stop_screen.dart';
import 'package:touch_bridge/screens/safety/stop_done_screen.dart';
import 'package:touch_bridge/services/active_device_service.dart';
import 'package:touch_bridge/services/ble_service.dart';
import 'package:touch_bridge/services/run_status_service.dart';
import 'package:touch_bridge/services/tts_service.dart';

/// 비상 정지 화면의 안전 계약 검증.
///
/// 이 화면은 "3초 홀드 → 하드웨어 정지 명령 → ACK 해석 → 안내" 경로 전체를
/// 조립하는 곳인데 커버리지가 0/187줄이었다. 정지 로직 자체(EmergencyStopService,
/// EmergencyStopOutcome)는 단위 테스트가 있지만, 그것을 **화면이 올바르게
/// 사용하는지**는 아무도 검증하지 않고 있었다.
///
/// 특히 지키려는 계약은 하나다 — **거짓 완료 금지**.
/// ACK로 정지가 확인된 경우에만 "안전하게 중단" 완료 화면으로 넘어가야 하고,
/// 전송만 됐거나 실패한 경우에는 사용자가 재시도할 수 있어야 한다.
/// 화면을 볼 수 없는 사용자에게 "멈췄습니다"는 되돌릴 수 없는 신뢰의 문제다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> stopCalls;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // FakeAsync(testWidgets) 환경에서는 TTS 플랫폼 채널이 완료되지 않아
    // speak()를 await하는 화면 로직이 멈춘다 — 엔진 호출만 생략한다.
    TtsService().disableEngineForTest = true;
    // 싱글톤 상태(발화 로그·8초 중복 억제)를 테스트 사이에 남기지 않는다.
    TtsService().resetForTest();
    RunStatusService.instance.resetForTest();
    stopCalls = <String>[];
    // 활성 기기 인메모리 상태를 비운다(빈 SharedPreferences를 다시 읽음).
    await ActiveDeviceService.instance.init();
    // 실제 BLE 스택을 건드리지 않도록 연결을 항상 성공으로 대체한다.
    BleService.instance.setTestOverrides(connect: (_) async => true);
  });

  tearDown(() {
    TtsService().disableEngineForTest = false;
    BleService.instance.clearTestOverrides();
    BleService.instance.setPriorityStopOverride(null);
    RunStatusService.instance.resetForTest();
  });

  /// 정지 명령이 실제로 나갈 수 있도록 활성 기기를 등록한다.
  Future<void> registerActiveDevice() async {
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
      bleId: 'TEST-BLE-0001',
      bleName: '테스트 브리지',
    );
  }

  /// ESP32가 돌려줄 ACK 문자열을 지정한다(호출 이력도 기록).
  void stubStopAck(String ack) {
    BleService.instance.setPriorityStopOverride((deviceId) async {
      stopCalls.add(deviceId);
      return ack;
    });
  }

  Widget wrap(Widget child) => MaterialApp(home: child);

  /// 비상 정지 버튼을 [hold] 동안 길게 누른다.
  ///
  /// 롱프레스 인식 임계(500ms)를 먼저 넘겨 `onLongPressStart`를 일으킨 뒤,
  /// 홀드 시간만큼 진행한다. 화면의 AnimationController 지속시간은 3초이므로
  /// hold가 3초 이상이면 정지가 실행된다.
  Future<void> holdStopButton(
    WidgetTester tester, {
    required Duration hold,
  }) async {
    final gesture = await tester.startGesture(
      tester.getCenter(find.bySemanticsLabel('비상 정지')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // AnimationController는 첫 tick에서 기준 시각만 잡고 elapsed=0이다.
    // 이 프레임 없이 곧바로 홀드 시간을 점프하면 경과가 0으로 계산돼
    // 진행바가 움직이지 않는다.
    await tester.pump();
    await tester.pump(hold);
    // 완주 판정은 "경과 > duration"이라 정확히 3.000초에서는 completed가 되지
    // 않는다(경계 배타). 실제 손가락도 정확히 3.000초일 수 없으므로 한 프레임
    // 더 진행해 경계를 넘긴다.
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump();
  }

  /// 정지 처리의 비동기 흐름(지표 기록 → BLE 전송 → TTS → 화면 전환)을 흘려보낸다.
  /// 진행 애니메이션 때문에 pumpAndSettle을 쓸 수 없어 유한 pump로 진행한다.
  Future<void> settleStopFlow(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// 화면을 정리해 카운트다운·햅틱 주기 타이머가 테스트에 남지 않게 한다.
  Future<void> disposeScreen(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  }

  bool spoke(String fragment) =>
      TtsService().getRecentLog().any((line) => line.contains(fragment));

  group('비상 정지 화면 — 남은 시간 안내', () {
    testWidgets('남은 시간을 MM:SS Semantics value로 노출한다 (스크린리더 포커스 시 낭독)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const EmergencyStopScreen(initialSeconds: 150, deviceName: '전자레인지')),
      );
      await tester.pump();

      // 화면에는 시각용 헤딩 Text('남은 시간')와 값을 담은
      // Semantics(label:'남은 시간', value:'02:30')가 함께 있어 라벨만으로는
      // 노드가 둘 매칭된다. value를 가진 쪽을 정확히 지목한다.
      final semantics = tester.getSemantics(
        find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.label == '남은 시간' &&
              w.properties.value != null,
        ),
      );
      expect(
        semantics.value,
        '02:30',
        reason: '숫자 텍스트는 ExcludeSemantics로 가려져 있어, value가 유일한 낭독 경로다',
      );

      await disposeScreen(tester);
    });

    testWidgets('진입 시 기기명과 조작 방법을 안내한다', (tester) async {
      await tester.pumpWidget(
        wrap(const EmergencyStopScreen(initialSeconds: 60, deviceName: '세탁기')),
      );
      await tester.pump();

      expect(spoke('세탁기 작동 중입니다'), isTrue);
      expect(spoke('3초간 누르세요'), isTrue);

      await disposeScreen(tester);
    });

    testWidgets('카운트다운 구간(10·5·3초)에서 각각 한 번씩만 안내한다', (tester) async {
      await tester.pumpWidget(
        wrap(const EmergencyStopScreen(initialSeconds: 12, deviceName: '전자레인지')),
      );
      await tester.pump();

      // 12초에서 9초 진행 → 남은 시간 3초. 구간 10·5·3을 모두 지난다.
      for (var i = 0; i < 9; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      final log = TtsService().getRecentLog();
      for (final expected in ['10초 남았습니다.', '5초 남았습니다.', '3초 남았습니다.']) {
        expect(
          log.where((line) => line.contains(expected)).length,
          1,
          reason: '$expected 구간 안내는 정확히 한 번이어야 한다 (_announcedMilestones)',
        );
      }

      await disposeScreen(tester);
    });
  });

  group('비상 정지 화면 — 3초 홀드', () {
    testWidgets('3초를 채우기 전에 떼면 정지 명령이 나가지 않는다', (tester) async {
      await registerActiveDevice();
      stubStopAck('STOPPED');

      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();

      await holdStopButton(tester, hold: const Duration(seconds: 1));
      await settleStopFlow(tester);

      expect(stopCalls, isEmpty, reason: '홀드 미완주는 물리 동작을 일으키면 안 된다');
      expect(find.byType(StopDoneScreen), findsNothing);

      await disposeScreen(tester);
    });

    testWidgets('3초 홀드를 완주하면 정지 명령을 활성 기기로 보낸다', (tester) async {
      await registerActiveDevice();
      stubStopAck('STOPPED');

      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();

      await holdStopButton(tester, hold: const Duration(seconds: 3));
      await settleStopFlow(tester);

      expect(stopCalls, ['TEST-BLE-0001']);

      await disposeScreen(tester);
    });

    testWidgets('홀드 시작 시 진행 중임을 음성으로 알린다', (tester) async {
      await registerActiveDevice();
      stubStopAck('STOPPED');

      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();

      await holdStopButton(tester, hold: const Duration(seconds: 1));

      expect(
        spoke('멈추는 중입니다'),
        isTrue,
        reason: '화면을 못 보는 사용자는 홀드가 인식됐는지 음성으로만 알 수 있다',
      );

      await disposeScreen(tester);
    });
  });

  group('비상 정지 화면 — 거짓 완료 금지', () {
    testWidgets('기기가 정지를 확인하면(STOPPED) 완료 화면으로 이동한다', (tester) async {
      await registerActiveDevice();
      stubStopAck('STOPPED');

      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();

      await holdStopButton(tester, hold: const Duration(seconds: 3));
      await settleStopFlow(tester);

      expect(find.byType(StopDoneScreen), findsOneWidget);
      expect(spoke('기기를 멈췄습니다'), isTrue);

      await disposeScreen(tester);
    });

    testWidgets('응답을 확인하지 못하면(TIMEOUT) 완료 화면으로 가지 않고 재시도할 수 있다', (
      tester,
    ) async {
      await registerActiveDevice();
      stubStopAck('ERROR:TIMEOUT');

      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();

      await holdStopButton(tester, hold: const Duration(seconds: 3));
      await settleStopFlow(tester);

      expect(
        find.byType(StopDoneScreen),
        findsNothing,
        reason: '타임아웃은 정지 확인이 아니다 — "안전하게 중단" 화면으로 넘기면 거짓 완료다',
      );
      expect(spoke('응답을 확인하지 못했습니다'), isTrue);

      // _stopInProgress가 풀려 재시도가 가능해야 한다.
      //
      // 이 두 번째 홀드는 홀드 진행 햅틱 타이머(1초 주기)의 누수도 함께
      // 지킨다. _onHoldCompleted가 타이머를 취소하지 않으면 완주할 때마다
      // 주기 타이머가 남아, 테스트는 "Pending timers"로 실패한다.
      await holdStopButton(tester, hold: const Duration(seconds: 3));
      await settleStopFlow(tester);
      expect(
        stopCalls.length,
        2,
        reason: '미확인 후에는 다시 홀드해서 재시도할 수 있어야 한다',
      );

      await disposeScreen(tester);
    });

    testWidgets('정지와 무관한 알림(TEMP_OK)을 정지 확인으로 오판하지 않는다', (tester) async {
      await registerActiveDevice();
      // 센서 알림이 같은 응답 스트림으로 흘러드는 상황.
      stubStopAck('TEMP_OK');

      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();

      await holdStopButton(tester, hold: const Duration(seconds: 3));
      await settleStopFlow(tester);

      expect(find.byType(StopDoneScreen), findsNothing);
      expect(spoke('응답을 확인하지 못했습니다'), isTrue);

      await disposeScreen(tester);
    });

    testWidgets('연결된 기기가 없으면 완료 화면으로 가지 않고 전원 확인을 안내한다', (tester) async {
      // 활성 기기를 등록하지 않는다 → EmergencyStopService가 조기 반환.
      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();

      await holdStopButton(tester, hold: const Duration(seconds: 3));
      await settleStopFlow(tester);

      expect(find.byType(StopDoneScreen), findsNothing);
      expect(spoke('연결된 기기가 없습니다'), isTrue);

      await disposeScreen(tester);
    });
  });

  group('비상 정지 화면 — 상태 추적 정리', () {
    testWidgets('진입하면 실행 상태를 전역에 보고한다 ("얼마나 남았어?" 응답용)', (tester) async {
      await tester.pumpWidget(
        wrap(const EmergencyStopScreen(initialSeconds: 90, deviceName: '전자레인지')),
      );
      await tester.pump();

      expect(RunStatusService.instance.isRunning, isTrue);
      expect(RunStatusService.instance.deviceName, '전자레인지');
      expect(RunStatusService.instance.secondsLeft, 90);

      await disposeScreen(tester);
    });

    testWidgets('화면을 떠나면 추적을 멈춘다 (옛 값으로 "작동 중"이라 답하지 않도록)', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const EmergencyStopScreen(initialSeconds: 90, deviceName: '전자레인지')),
      );
      await tester.pump();
      expect(RunStatusService.instance.isRunning, isTrue);

      await disposeScreen(tester);

      expect(
        RunStatusService.instance.isRunning,
        isFalse,
        reason: '화면 이탈 후에는 남은 시간을 추적할 수 없으므로 "작동 중"이라 답하면 안 된다',
      );
    });

    testWidgets('정지가 확인되면 카운트다운 추적도 멈춘다', (tester) async {
      await registerActiveDevice();
      stubStopAck('STOPPED');

      await tester.pumpWidget(wrap(const EmergencyStopScreen(initialSeconds: 150)));
      await tester.pump();
      expect(RunStatusService.instance.isRunning, isTrue);

      await holdStopButton(tester, hold: const Duration(seconds: 3));
      await settleStopFlow(tester);

      expect(RunStatusService.instance.isRunning, isFalse);

      await disposeScreen(tester);
    });
  });
}
