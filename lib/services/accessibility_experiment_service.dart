import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskMode { manual, voice }

class AccessibilityExperimentService extends ChangeNotifier {
  AccessibilityExperimentService._();
  static final AccessibilityExperimentService instance = AccessibilityExperimentService._();

  static const _kTotalTasks = 'exp_total_tasks';
  static const _kCompletedTasks = 'exp_completed_tasks';
  static const _kAbortedTasks = 'exp_aborted_tasks';
  static const _kEmergencyStops = 'exp_emergency_stops';
  static const _kDoubleTapTimeouts = 'exp_double_tap_timeouts';
  static const _kVoiceTasks = 'exp_voice_tasks';
  static const _kManualTasks = 'exp_manual_tasks';
  static const _kTotalCompletionSeconds = 'exp_total_completion_seconds';
  static const _kVoiceCompleted = 'exp_voice_completed';
  static const _kManualCompleted = 'exp_manual_completed';
  static const _kVoiceCompletionSeconds = 'exp_voice_completion_seconds';
  static const _kManualCompletionSeconds = 'exp_manual_completion_seconds';

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _abortedTasks = 0;
  int _emergencyStops = 0;
  int _doubleTapTimeouts = 0;
  int _voiceTasks = 0;
  int _manualTasks = 0;
  int _totalCompletionSeconds = 0;
  int _voiceCompleted = 0;
  int _manualCompleted = 0;
  int _voiceCompletionSeconds = 0;
  int _manualCompletionSeconds = 0;

  DateTime? _activeTaskStartedAt;
  // 완료 시간을 음성/수동으로 분리 집계하기 위해 시작 모드를 기억한다
  // (당사자 검증에서 "음성 vs 수동" 비교가 핵심 지표다 — USER_VALIDATION_PLAN).
  TaskMode? _activeTaskMode;

  int get totalTasks => _totalTasks;
  int get completedTasks => _completedTasks;
  int get abortedTasks => _abortedTasks;
  int get emergencyStops => _emergencyStops;
  int get doubleTapTimeouts => _doubleTapTimeouts;
  int get voiceTasks => _voiceTasks;
  int get manualTasks => _manualTasks;
  int get totalCompletionSeconds => _totalCompletionSeconds;
  int get voiceCompleted => _voiceCompleted;
  int get manualCompleted => _manualCompleted;
  double get completionRate => _totalTasks == 0 ? 0 : (_completedTasks / _totalTasks) * 100;
  double get averageCompletionSeconds => _completedTasks == 0 ? 0 : _totalCompletionSeconds / _completedTasks;
  double get voiceAverageCompletionSeconds =>
      _voiceCompleted == 0 ? 0 : _voiceCompletionSeconds / _voiceCompleted;
  double get manualAverageCompletionSeconds =>
      _manualCompleted == 0 ? 0 : _manualCompletionSeconds / _manualCompleted;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _totalTasks = prefs.getInt(_kTotalTasks) ?? 0;
    _completedTasks = prefs.getInt(_kCompletedTasks) ?? 0;
    _abortedTasks = prefs.getInt(_kAbortedTasks) ?? 0;
    _emergencyStops = prefs.getInt(_kEmergencyStops) ?? 0;
    _doubleTapTimeouts = prefs.getInt(_kDoubleTapTimeouts) ?? 0;
    _voiceTasks = prefs.getInt(_kVoiceTasks) ?? 0;
    _manualTasks = prefs.getInt(_kManualTasks) ?? 0;
    _totalCompletionSeconds = prefs.getInt(_kTotalCompletionSeconds) ?? 0;
    _voiceCompleted = prefs.getInt(_kVoiceCompleted) ?? 0;
    _manualCompleted = prefs.getInt(_kManualCompleted) ?? 0;
    _voiceCompletionSeconds = prefs.getInt(_kVoiceCompletionSeconds) ?? 0;
    _manualCompletionSeconds = prefs.getInt(_kManualCompletionSeconds) ?? 0;
    notifyListeners();
  }

  Future<void> recordTaskStarted(TaskMode mode) async {
    _totalTasks += 1;
    if (mode == TaskMode.voice) {
      _voiceTasks += 1;
    } else {
      _manualTasks += 1;
    }
    _activeTaskStartedAt = DateTime.now();
    _activeTaskMode = mode;
    await _save();
  }

  Future<void> recordTaskCompleted() async {
    _completedTasks += 1;
    if (_activeTaskStartedAt != null) {
      final elapsed = DateTime.now().difference(_activeTaskStartedAt!).inSeconds;
      final safeElapsed = elapsed < 0 ? 0 : elapsed;
      _totalCompletionSeconds += safeElapsed;
      if (_activeTaskMode == TaskMode.voice) {
        _voiceCompleted += 1;
        _voiceCompletionSeconds += safeElapsed;
      } else if (_activeTaskMode == TaskMode.manual) {
        _manualCompleted += 1;
        _manualCompletionSeconds += safeElapsed;
      }
    }
    _activeTaskStartedAt = null;
    _activeTaskMode = null;
    await _save();
  }

  Future<void> recordTaskAborted() async {
    // 이전 구현은 저장하지 않고 시작 시각만 지워서, 중단된 작업이 영구
    // "미완료"로 남고 완료율 해석이 모호했다 — 중단도 셈해서 저장한다.
    _abortedTasks += 1;
    _activeTaskStartedAt = null;
    _activeTaskMode = null;
    await _save();
  }

  Future<void> recordEmergencyStop() async {
    _emergencyStops += 1;
    await _save();
  }

  Future<void> recordDoubleTapTimeout() async {
    _doubleTapTimeouts += 1;
    await _save();
  }

  /// 지표를 CSV 텍스트로 만든다 — 클립보드로 내보내 시트에 붙여 넣는 용도.
  /// 당사자 검증(USER_VALIDATION_PLAN)의 실측 데이터 수집 창구.
  String buildExportCsv({DateTime? now}) {
    final ts = (now ?? DateTime.now()).toIso8601String();
    String f(double v) => v.toStringAsFixed(1);
    final rows = <List<String>>[
      ['지표', '값'],
      ['내보낸 시각', ts],
      ['총 작업 수', '$_totalTasks'],
      ['완료 작업 수', '$_completedTasks'],
      ['중단 작업 수', '$_abortedTasks'],
      ['완료율(%)', f(completionRate)],
      ['평균 완료 시간(초)', f(averageCompletionSeconds)],
      ['음성 작업 수', '$_voiceTasks'],
      ['음성 완료 수', '$_voiceCompleted'],
      ['음성 평균 완료 시간(초)', f(voiceAverageCompletionSeconds)],
      ['수동 작업 수', '$_manualTasks'],
      ['수동 완료 수', '$_manualCompleted'],
      ['수동 평균 완료 시간(초)', f(manualAverageCompletionSeconds)],
      ['비상 정지 횟수', '$_emergencyStops'],
      ['이중 탭 타임아웃 횟수', '$_doubleTapTimeouts'],
    ];
    return rows.map((r) => r.join(',')).join('\n');
  }

  Future<void> reset() async {
    _totalTasks = 0;
    _completedTasks = 0;
    _abortedTasks = 0;
    _emergencyStops = 0;
    _doubleTapTimeouts = 0;
    _voiceTasks = 0;
    _manualTasks = 0;
    _totalCompletionSeconds = 0;
    _voiceCompleted = 0;
    _manualCompleted = 0;
    _voiceCompletionSeconds = 0;
    _manualCompletionSeconds = 0;
    _activeTaskStartedAt = null;
    _activeTaskMode = null;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTotalTasks, _totalTasks);
    await prefs.setInt(_kCompletedTasks, _completedTasks);
    await prefs.setInt(_kAbortedTasks, _abortedTasks);
    await prefs.setInt(_kEmergencyStops, _emergencyStops);
    await prefs.setInt(_kDoubleTapTimeouts, _doubleTapTimeouts);
    await prefs.setInt(_kVoiceTasks, _voiceTasks);
    await prefs.setInt(_kManualTasks, _manualTasks);
    await prefs.setInt(_kTotalCompletionSeconds, _totalCompletionSeconds);
    await prefs.setInt(_kVoiceCompleted, _voiceCompleted);
    await prefs.setInt(_kManualCompleted, _manualCompleted);
    await prefs.setInt(_kVoiceCompletionSeconds, _voiceCompletionSeconds);
    await prefs.setInt(_kManualCompletionSeconds, _manualCompletionSeconds);
    notifyListeners();
  }
}
