import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/accessibility_experiment_service.dart';

void main() {
  final exp = AccessibilityExperimentService.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await exp.reset();
  });

  group('AccessibilityExperimentService (실험 지표)', () {
    test('음성/수동 완료 시간을 분리 집계한다 (당사자 검증 핵심 비교 지표)', () async {
      await exp.recordTaskStarted(TaskMode.voice);
      await exp.recordTaskCompleted();
      await exp.recordTaskStarted(TaskMode.manual);
      await exp.recordTaskCompleted();

      expect(exp.voiceTasks, 1);
      expect(exp.manualTasks, 1);
      expect(exp.voiceCompleted, 1);
      expect(exp.manualCompleted, 1);
      expect(exp.completedTasks, 2);
    });

    test('중단된 작업도 집계·저장된다 (완료율 해석 모호성 해소)', () async {
      await exp.recordTaskStarted(TaskMode.voice);
      await exp.recordTaskAborted();

      expect(exp.abortedTasks, 1);
      expect(exp.completedTasks, 0);

      // 저장까지 됐는지: 새로 로드해도 유지.
      await exp.load();
      expect(exp.abortedTasks, 1);
    });

    test('중단 후 완료 기록은 모드 없이 집계돼 분리 지표를 오염시키지 않는다', () async {
      await exp.recordTaskStarted(TaskMode.voice);
      await exp.recordTaskAborted();
      // 시작 없이 완료가 오는 비정상 순서 — 전체 완료 수만 오르고
      // 음성/수동 분리 카운트는 오르지 않아야 한다.
      await exp.recordTaskCompleted();

      expect(exp.completedTasks, 1);
      expect(exp.voiceCompleted, 0);
      expect(exp.manualCompleted, 0);
    });

    test('buildExportCsv는 모든 핵심 지표를 CSV로 담는다', () async {
      await exp.recordTaskStarted(TaskMode.voice);
      await exp.recordTaskCompleted();
      await exp.recordEmergencyStop();
      await exp.recordDoubleTapTimeout();

      final csv = exp.buildExportCsv(now: DateTime(2026, 8, 23, 12, 0));

      expect(csv, contains('지표,값'));
      expect(csv, contains('내보낸 시각,2026-08-23T12:00:00.000'));
      expect(csv, contains('총 작업 수,1'));
      expect(csv, contains('완료 작업 수,1'));
      expect(csv, contains('완료율(%),100.0'));
      expect(csv, contains('음성 완료 수,1'));
      expect(csv, contains('비상 정지 횟수,1'));
      expect(csv, contains('이중 탭 타임아웃 횟수,1'));
      // 시트 호환: 모든 줄이 "이름,값" 2열 형식.
      for (final line in csv.split('\n')) {
        expect(line.split(',').length, 2, reason: line);
      }
    });

    test('reset은 분리 지표까지 모두 초기화한다', () async {
      await exp.recordTaskStarted(TaskMode.manual);
      await exp.recordTaskCompleted();
      await exp.recordTaskAborted();

      await exp.reset();

      expect(exp.totalTasks, 0);
      expect(exp.abortedTasks, 0);
      expect(exp.manualCompleted, 0);
      expect(exp.buildExportCsv(), contains('총 작업 수,0'));
    });
  });
}
