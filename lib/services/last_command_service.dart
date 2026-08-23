import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 마지막으로 전송에 성공한 음성 명령 한 건.
class LastVoiceCommand {
  const LastVoiceCommand({
    required this.data,
    required this.deviceId,
    required this.deviceName,
    required this.description,
    required this.recordedAt,
  });

  /// 원본 파싱 결과(action/commands/message 등) — 재실행 시 그대로
  /// `_handleCommand(data, forceExecution: true)`에 넣는다.
  final Map<String, dynamic> data;
  final String deviceId;
  final String deviceName;

  /// 확인 질문에 읽어줄 사람 말 설명 (예: "전자레인지, 30초 조리를 시작합니다").
  final String description;
  final DateTime recordedAt;

  Map<String, dynamic> toJson() => {
        'data': data,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'description': description,
        'recordedAt': recordedAt.toIso8601String(),
      };

  static LastVoiceCommand? fromJson(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! Map) return null;
    return LastVoiceCommand(
      data: Map<String, dynamic>.from(data),
      deviceId: json['deviceId'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? '기기',
      description: json['description'] as String? ?? '',
      recordedAt:
          DateTime.tryParse(json['recordedAt'] as String? ?? '') ??
              DateTime.now(),
    );
  }
}

/// "아까 그거 다시"를 위해 마지막 전송 성공 명령을 저장/복원한다.
///
/// 앱 재시작 후에도 쓸 수 있도록 SharedPreferences에 영속화한다 —
/// 반복 사용이 많은 가전 조작 특성상 "어제 그 명령"도 유효한 요청이다.
/// 저장 대상은 물리 동작 명령(전송 성공)만이며, 재실행은 반드시 확인 질문을
/// 거친다(RepeatIntent 호출부 책임).
class LastCommandService {
  LastCommandService._();
  static final LastCommandService instance = LastCommandService._();

  static const _prefsKey = 'last_voice_command_v1';

  LastVoiceCommand? _cache;
  bool _loaded = false;

  Future<void> record({
    required Map<String, dynamic> data,
    required String deviceId,
    required String deviceName,
    required String description,
  }) async {
    final cmd = LastVoiceCommand(
      data: Map<String, dynamic>.from(data),
      deviceId: deviceId,
      deviceName: deviceName,
      description: description,
      recordedAt: DateTime.now(),
    );
    _cache = cmd;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(cmd.toJson()));
    } catch (e) {
      // 저장 실패해도 세션 내 캐시로는 동작한다.
      debugPrint('LastCommandService save error: $e');
    }
  }

  Future<LastVoiceCommand?> load() async {
    if (_loaded) return _cache;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return null;
      _cache = LastVoiceCommand.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (e) {
      // 손상된 저장값은 조용히 무시한다 — "없음"으로 동작.
      debugPrint('LastCommandService load error: $e');
      _cache = null;
    }
    return _cache;
  }

  @visibleForTesting
  void resetForTest() {
    _cache = null;
    _loaded = false;
  }
}
