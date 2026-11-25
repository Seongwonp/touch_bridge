import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/app_lifecycle_service.dart';

/// 부스 무인 운영용 수명 주기 서비스 — 재연결·화면 켜짐·백엔드 깨우기.
///
/// 실제 BLE·wakelock·네트워크 대신 주입한 가짜로 "언제 무엇을 부르는지"만 검증한다.
class _Fakes {
  String? bleId = 'AA:BB:CC:DD:EE:01';
  bool connected = false;
  bool busy = false;
  String backendUrl = 'https://tb-backend.onrender.com';
  final connectCalls = <String>[];
  final wakelockCalls = <bool>[];
  final pinged = <Uri>[];
  Completer<bool>? connectGate;
  bool connectThrows = false;
  bool httpThrows = false;

  AppLifecycleService build() => AppLifecycleService(
    activeBleId: () => bleId,
    isConnected: () => connected,
    isBusy: () => busy,
    connect: (id) async {
      connectCalls.add(id);
      if (connectThrows) throw StateError('BLE off');
      if (connectGate != null) return connectGate!.future;
      return false;
    },
    setWakelock: (enable) async => wakelockCalls.add(enable),
    backendUrl: () => backendUrl,
    httpGet: (uri) async {
      pinged.add(uri);
      if (httpThrows) throw Exception('offline');
      return 200;
    },
  );
}

Future<void> _goBackground(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

Future<void> _goForeground(WidgetTester tester) async {
  for (final s in [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(s);
  }
  await tester.pump();
}

void main() {
  group('AppLifecycleService.healthUri', () {
    test('백엔드 주소 뒤에 /healthz를 붙인다', () {
      expect(
        AppLifecycleService.healthUri('https://tb.onrender.com').toString(),
        'https://tb.onrender.com/healthz',
      );
      expect(
        AppLifecycleService.healthUri('https://tb.onrender.com/').toString(),
        'https://tb.onrender.com/healthz',
      );
      expect(
        AppLifecycleService.healthUri('http://192.168.0.5:8000').toString(),
        'http://192.168.0.5:8000/healthz',
      );
    });

    test('설정이 없거나 로컬·형식 오류면 깨우지 않는다', () {
      expect(AppLifecycleService.healthUri(''), isNull);
      expect(AppLifecycleService.healthUri('   '), isNull);
      expect(AppLifecycleService.healthUri('http://localhost:8000'), isNull);
      expect(AppLifecycleService.healthUri('http://127.0.0.1:8000'), isNull);
      expect(AppLifecycleService.healthUri('ftp://example.com'), isNull);
      expect(AppLifecycleService.healthUri('not a url'), isNull);
    });
  });

  group('AppLifecycleService 재연결', () {
    testWidgets('실행 시 활성 기기가 끊겨 있으면 저장된 bleId로 한 번 연결한다', (tester) async {
      final f = _Fakes();
      final service = f.build()..start();
      await tester.pump();

      expect(f.connectCalls, ['AA:BB:CC:DD:EE:01']);
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });

    testWidgets('이미 연결됐거나 bleId가 없으면 연결하지 않는다', (tester) async {
      final f = _Fakes()..connected = true;
      await f.build().reconnectIfNeeded();
      f
        ..connected = false
        ..bleId = null;
      await f.build().reconnectIfNeeded();
      f.bleId = '';
      await f.build().reconnectIfNeeded();

      expect(f.connectCalls, isEmpty);
    });

    testWidgets('백오프 재연결·비상 정지 중(busy)이면 끼어들지 않는다', (tester) async {
      final f = _Fakes()..busy = true;
      await f.build().reconnectIfNeeded();
      expect(f.connectCalls, isEmpty);
    });

    testWidgets('연결 시도가 끝나기 전에는 겹쳐 시도하지 않는다', (tester) async {
      final f = _Fakes()..connectGate = Completer<bool>();
      final service = f.build();
      final first = service.reconnectIfNeeded();
      await service.reconnectIfNeeded();
      expect(f.connectCalls, hasLength(1));
      f.connectGate!.complete(true);
      await first;
    });

    testWidgets('연결 예외는 삼키고 다음 복귀 때 다시 시도한다', (tester) async {
      final f = _Fakes()..connectThrows = true;
      final service = f.build()..start();
      await tester.pump();
      expect(f.connectCalls, hasLength(1));

      await _goBackground(tester);
      await _goForeground(tester);
      expect(f.connectCalls, hasLength(2));
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });

    testWidgets('알림창 정도의 inactive→resumed에서는 다시 시도하지 않는다', (tester) async {
      final f = _Fakes();
      final service = f.build()..start();
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(f.connectCalls, hasLength(1));
      expect(f.pinged, hasLength(1));
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });
  });

  group('AppLifecycleService 화면 켜짐', () {
    testWidgets('앞에 있으면 켜고, 백그라운드로 가면 풀고, 돌아오면 다시 켠다', (tester) async {
      final f = _Fakes();
      final service = f.build()..start();
      await tester.pump();
      expect(f.wakelockCalls, [true]);

      await _goBackground(tester);
      expect(f.wakelockCalls, [true, false]);

      await _goForeground(tester);
      expect(f.wakelockCalls, [true, false, true]);
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });

    testWidgets('wakelock 실패는 앱을 멈추지 않는다', (tester) async {
      final service = AppLifecycleService(
        activeBleId: () => null,
        isConnected: () => false,
        isBusy: () => false,
        connect: (_) async => false,
        setWakelock: (_) async => throw Exception('no plugin'),
        backendUrl: () => '',
        httpGet: (_) async => 200,
      )..start();
      await tester.pump();
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });
  });

  group('AppLifecycleService 백엔드 깨우기', () {
    testWidgets('시작 때 한 번, 앞에 있는 동안 10분마다 /healthz를 부른다', (tester) async {
      final f = _Fakes();
      final service = f.build()..start();
      await tester.pump();
      expect(f.pinged.map((u) => u.toString()), [
        'https://tb-backend.onrender.com/healthz',
      ]);

      await tester.pump(const Duration(minutes: 9));
      expect(f.pinged, hasLength(1));
      await tester.pump(const Duration(minutes: 1));
      expect(f.pinged, hasLength(2));
      await tester.pump(const Duration(minutes: 10));
      expect(f.pinged, hasLength(3));
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });

    testWidgets('백그라운드에서는 멈추고, 돌아오면 바로 한 번 부른 뒤 다시 센다', (tester) async {
      final f = _Fakes();
      final service = f.build()..start();
      await tester.pump();
      expect(f.pinged, hasLength(1));

      await _goBackground(tester);
      await tester.pump(const Duration(minutes: 30));
      expect(f.pinged, hasLength(1));

      await _goForeground(tester);
      expect(f.pinged, hasLength(2));
      await tester.pump(const Duration(minutes: 10));
      expect(f.pinged, hasLength(3));
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });

    testWidgets('설정이 없거나 로컬 주소면 요청하지 않는다', (tester) async {
      final f = _Fakes()..backendUrl = '';
      final service = f.build()..start();
      await tester.pump(const Duration(minutes: 10));
      f.backendUrl = 'http://localhost:8000';
      await tester.pump(const Duration(minutes: 10));
      expect(f.pinged, isEmpty);
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });

    testWidgets('요청 실패는 삼키고 다음 주기에 다시 부른다', (tester) async {
      final f = _Fakes()..httpThrows = true;
      final service = f.build()..start();
      await tester.pump();
      await tester.pump(const Duration(minutes: 10));
      expect(f.pinged, hasLength(2));
      // 주기 타이머가 남으면 테스트 바인딩이 실패시키므로 직접 멈춘다.
      service.stop();
    });
  });
}
