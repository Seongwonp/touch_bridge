import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TaskMode { manual, voice }

class AccessibilityExperimentService extends ChangeNotifier {
  AccessibilityExperimentService._();
  static final AccessibilityExperimentService instance =
      AccessibilityExperimentService._();

  static const _kTotalTasks = 'exp_total_tasks';
  static const _kCompletedTasks = 'exp_completed_tasks';
  static const _kEmergencyStops = 'exp_emergency_stops';
  static const _kDoubleTapTimeouts = 'exp_double_tap_timeouts';
  static const _kVoiceTasks = 'exp_voice_tasks';
  static const _kManualTasks = 'exp_manual_tasks';
  static const _kTotalCompletionSeconds = 'exp_total_completion_seconds';

  int _totalTasks = 0;
  int _completedTasks = 0;
  int _emergencyStops = 0;
  int _doubleTapTimeouts = 0;
  int _voiceTasks = 0;
  int _manualTasks = 0;
  int _totalCompletionSeconds = 0;

  DateTime? _activeTaskStartedAt;

  int get totalTasks => _totalTasks;
  int get completedTasks => _completedTasks;
  int get emergencyStops => _emergencyStops;
  int get doubleTapTimeouts => _doubleTapTimeouts;
  int get voiceTasks => _voiceTasks;
  int get manualTasks => _manualTasks;
  int get totalCompletionSeconds => _totalCompletionSeconds;
  double get completionRate =>
      _totalTasks == 0 ? 0 : (_completedTasks / _totalTasks) * 100;
  double get averageCompletionSeconds =>
      _completedTasks == 0 ? 0 : _totalCompletionSeconds / _completedTasks;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _totalTasks = prefs.getInt(_kTotalTasks) ?? 0;
    _completedTasks = prefs.getInt(_kCompletedTasks) ?? 0;
    _emergencyStops = prefs.getInt(_kEmergencyStops) ?? 0;
    _doubleTapTimeouts = prefs.getInt(_kDoubleTapTimeouts) ?? 0;
    _voiceTasks = prefs.getInt(_kVoiceTasks) ?? 0;
    _manualTasks = prefs.getInt(_kManualTasks) ?? 0;
    _totalCompletionSeconds = prefs.getInt(_kTotalCompletionSeconds) ?? 0;
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
    await _save();
  }

  Future<void> recordTaskCompleted() async {
    _completedTasks += 1;
    if (_activeTaskStartedAt != null) {
      final elapsed = DateTime.now()
          .difference(_activeTaskStartedAt!)
          .inSeconds;
      _totalCompletionSeconds += elapsed < 0 ? 0 : elapsed;
    }
    _activeTaskStartedAt = null;
    await _save();
  }

  Future<void> recordTaskAborted() async {
    _activeTaskStartedAt = null;
    notifyListeners();
  }

  Future<void> recordEmergencyStop() async {
    _emergencyStops += 1;
    await _save();
  }

  Future<void> recordDoubleTapTimeout() async {
    _doubleTapTimeouts += 1;
    await _save();
  }

  Future<void> reset() async {
    _totalTasks = 0;
    _completedTasks = 0;
    _emergencyStops = 0;
    _doubleTapTimeouts = 0;
    _voiceTasks = 0;
    _manualTasks = 0;
    _totalCompletionSeconds = 0;
    _activeTaskStartedAt = null;
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kTotalTasks, _totalTasks);
    await prefs.setInt(_kCompletedTasks, _completedTasks);
    await prefs.setInt(_kEmergencyStops, _emergencyStops);
    await prefs.setInt(_kDoubleTapTimeouts, _doubleTapTimeouts);
    await prefs.setInt(_kVoiceTasks, _voiceTasks);
    await prefs.setInt(_kManualTasks, _manualTasks);
    await prefs.setInt(_kTotalCompletionSeconds, _totalCompletionSeconds);
    notifyListeners();
  }
}
