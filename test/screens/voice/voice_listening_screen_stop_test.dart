import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/safety/emergency_stop_screen.dart';
import 'package:touch_bridge/screens/safety/stop_done_screen.dart';
import 'package:touch_bridge/screens/voice/voice_listening_screen.dart';
import 'package:touch_bridge/screens/voice/widgets/press_progress_view.dart';
import 'package:touch_bridge/services/active_device_service.dart';
import 'package:touch_bridge/services/ble_service.dart';
import 'package:touch_bridge/services/run_status_service.dart';
import 'package:touch_bridge/services/speech_session_service.dart';
import 'package:touch_bridge/services/tts_service.dart';

/// 음성 화면에 단일 탭 정지 위젯을 **연결한 상태**의 검증 (리뷰 #3).
///
/// 위젯 단독 테스트(press_progress_view_test)와 달리, 여기서는 실제 화면이
/// 명령을 받아 실행 화면으로 들어간 뒤 버튼 한 번으로 우선 정지 경로
/// (BleService.sendEmergencyStop)가 호출되는지, 그리고 정지 뒤 늦게 돌아온 실행
/// 결과가 정지 안내를 덮거나 타이머 화면으로 이동시키지 않는지를 본다.
///
/// AI_BACKEND_URL이 없어 STT 초기화는 건너뛰지만(화면은 "미설정" 안내만 하고 뜬다),
/// 명령 처리 경로는 handleCommandForTest로 직접 넣는다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> stopCalls;
  late List<String> rawSent;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    TtsService().disableEngineForTest = true;
    TtsService().resetForTest();
    RunStatusService.instance.resetForTest();
    SpeechSessionService.instance.resetForTest();
    stopCalls = <String>[];
    rawSent = <String>[];
    await ActiveDeviceService.instance.init();
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
      bleId: 'TEST-BLE-0001',
      bleName: '테스트 브리지',
    );
    BleService.instance.setTestOverrides(connect: (_) async => true);
    // 목데이터 경로(pressPhysical)의 G-code. 각 줄 사이에 실제 대기가 있어
    // 실행 화면이 충분히 오래 떠 있다.
    BleService.instance.setSendRawOverride((cmd) async {
      rawSent.add(cmd);
      return true;
    });
  });

  tearDown(() {
    TtsService().disableEngineForTest = false;
    BleService.instance.clearTestOverrides();
    BleService.instance.setSendRawOverride(null);
    BleService.instance.setPriorityStopOverride(null);
    RunStatusService.instance.resetForTest();
    SpeechSessionService.instance.resetForTest();
  });

  void stubStopAck(String ack) {
    BleService.instance.setPriorityStopOverride((deviceId) async {
      stopCalls.add(deviceId);
      return ack;
    });
  }

  Future<VoiceListeningScreenState> pumpScreen(WidgetTester tester) async {
    final key = GlobalKey<VoiceListeningScreenState>();
    await tester.pumpWidget(MaterialApp(
      home: VoiceListeningScreen(
        key: key,
        deviceId: 'test-microwave',
        deviceName: '전자레인지',
      ),
    ));
    await tester.pump();
    return key.currentState!;
  }

  /// 전자레인지 조리 명령(전송 성공 시 타이머 화면으로 넘어가는 경로)을 넣고
  /// 실행 화면이 뜰 때까지 진행한다.
  Future<void> startExecution(WidgetTester tester, VoiceListeningScreenState state) async {
    // ignore: unawaited_futures
    state.handleCommandForTest({
      'action': 'MICROWAVE_CONTROL',
      'commands': ['BT-02', 'BT-05'],
      'inferred_seconds': 30,
      'confidence': 0.99,
      'needs_confirmation': false,
      'message': '30초 조리를 시작합니다.',
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.isExecutingForTest, isTrue);
    expect(find.byKey(PressProgressView.stopButtonKey), findsOneWidget,
        reason: '실행 중 화면에 단일 탭 정지 버튼이 있어야 한다');
  }

  testWidgets('실행 중 정지 버튼 한 번 탭으로 우선 정지 경로가 호출되고 잔여 명령이 끊긴다', (tester) async {
    stubStopAck('STOPPED');
    final state = await pumpScreen(tester);
    await startExecution(tester, state);
    final sentBeforeStop = rawSent.length;

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();
    // 정지 요청은 탭 직후 마이크로태스크 안에서 epoch를 올린다(전송 대기는 타이머라
    // 그 사이에 끼어들 수 없다). 이 시점 이후 전송은 0줄이어야 한다.
    final sentAtStop = rawSent.length;
    expect(sentAtStop, sentBeforeStop);

    expect(stopCalls, ['TEST-BLE-0001'], reason: '확인창·두 번째 탭 없이 즉시 1회 호출');
    expect(find.byType(AlertDialog), findsNothing);

    // 실행 시퀀스가 정지를 인지하고 끝날 때까지 충분히 진행 (내부 대기 최대 1.5초).
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));

    expect(state.lastSequenceStoppedForTest, isTrue);
    expect(rawSent.length, sentAtStop, reason: '정지 뒤 추가 전송은 정확히 0줄');
    // ACK 확인 → 완료 화면. 전송 성공 시 갔을 타이머(EmergencyStopScreen)로는 가지 않는다.
    expect(find.byType(StopDoneScreen), findsOneWidget);
    expect(find.byType(EmergencyStopScreen), findsNothing);
    expect(state.isExecutingForTest, isFalse);
    // 정지 안내가 남아 있고, 늦게 돌아온 실행 결과 문구로 덮이지 않았다.
    expect(state.statusMessageForTest, '기기를 멈췄습니다. 안전합니다.');
    expect(TtsService().getRecentLog().join('\n'), isNot(contains('취소했습니다')));
  });

  testWidgets('정지 요청 대기 중 연속 탭은 정지 명령을 1회만 보낸다', (tester) async {
    // ACK를 늦게 돌려줘 "정지 요청 중" 상태를 만든다.
    BleService.instance.setPriorityStopOverride((deviceId) async {
      stopCalls.add(deviceId);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return 'STOPPED';
    });
    final state = await pumpScreen(tester);
    await startExecution(tester, state);

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();
    expect(find.text('정지 요청 중'), findsOneWidget);
    await tester.tap(find.byKey(PressProgressView.stopButtonKey), warnIfMissed: false);
    await tester.tap(find.byKey(PressProgressView.stopButtonKey), warnIfMissed: false);
    await tester.pump();

    expect(stopCalls.length, 1);

    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(StopDoneScreen), findsOneWidget);
  });

  testWidgets('타임아웃(미확인) 뒤에는 완료 화면으로 가지 않고 다시 탭해 재시도할 수 있다', (tester) async {
    final acks = ['ERROR:TIMEOUT', 'STOPPED'];
    BleService.instance.setPriorityStopOverride((deviceId) async {
      stopCalls.add(deviceId);
      return acks[stopCalls.length - 1];
    });
    final state = await pumpScreen(tester);
    await startExecution(tester, state);

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(stopCalls.length, 1);
    expect(find.byType(StopDoneScreen), findsNothing, reason: 'ACK 없이 완료 화면 금지');
    expect(state.statusMessageForTest, contains('응답을 확인하지 못했습니다'));
    expect(find.text('다시 정지'), findsOneWidget);

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    expect(stopCalls.length, 2, reason: '실패·미확인 뒤 재시도는 새 요청');
    expect(find.byType(StopDoneScreen), findsOneWidget);
  });

  testWidgets('시퀀스가 끝난 뒤에도 정지 미확인이면 재시도 UI가 남고, 한참 뒤 재시도할 수 있다', (tester) async {
    final acks = ['ERROR:TIMEOUT', 'STOPPED'];
    BleService.instance.setPriorityStopOverride((deviceId) async {
      stopCalls.add(deviceId);
      return acks[stopCalls.length - 1];
    });
    final state = await pumpScreen(tester);
    await startExecution(tester, state);

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();
    final sentAtStop = rawSent.length;

    // 시퀀스가 끝나고도 한참 지난 뒤(내부 대기·완료 타이머를 모두 넘긴다).
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 5));
    }

    expect(state.lastSequenceStoppedForTest, isTrue);
    expect(rawSent.length, sentAtStop, reason: '시퀀스 종료 뒤에도 추가 전송 없음');
    expect(find.byType(StopDoneScreen), findsNothing, reason: '미확인 상태에서 완료 화면 금지');
    expect(find.byType(EmergencyStopScreen), findsNothing);
    expect(find.byKey(PressProgressView.stopButtonKey), findsOneWidget,
        reason: '시퀀스가 끝나도 정지가 미확인이면 재시도 버튼을 유지한다');
    expect(find.text('다시 정지'), findsOneWidget);
    expect(find.text('정지 확인이 필요합니다'), findsOneWidget);
    expect(find.textContaining('확인되지 않았습니다'), findsOneWidget);
    expect(state.statusMessageForTest, contains('응답을 확인하지 못했습니다'),
        reason: '늦게 끝난 시퀀스가 정지 안내를 덮지 않는다');

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(stopCalls.length, 2);
    expect(find.byType(StopDoneScreen), findsOneWidget);
    expect(state.isExecutingForTest, isFalse);
  });

  testWidgets('정지 응답을 기다리는 중 화면이 dispose돼도 알림·예외가 나지 않는다', (tester) async {
    final gate = Completer<String>();
    BleService.instance.setPriorityStopOverride((deviceId) {
      stopCalls.add(deviceId);
      return gate.future;
    });
    final state = await pumpScreen(tester);
    await startExecution(tester, state);

    await tester.tap(find.byKey(PressProgressView.stopButtonKey));
    await tester.pump();
    expect(stopCalls.length, 1);
    expect(find.text('정지 요청 중'), findsOneWidget);

    // 응답이 오기 전에 화면을 내린다 (뒤로 가기 등).
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump();

    // 그 뒤에 늦은 응답이 도착한다.
    gate.complete('STOPPED');
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));

    expect(tester.takeException(), isNull,
        reason: 'dispose된 ChangeNotifier에 notifyListeners·setState가 가면 안 된다');
    expect(find.byType(StopDoneScreen), findsNothing, reason: '내려간 화면이 화면 전환을 하면 안 된다');
  });
}
