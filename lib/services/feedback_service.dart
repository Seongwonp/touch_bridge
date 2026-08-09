import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

/// 소리(earcon)와 진동을 결과별로 구분해 전달한다.
/// 전맹 사용자가 화면 없이도 "수신 / 성공 / 실패"를 귀와 손으로 구분할 수 있게 한다.
/// - 성공: 상승 2음 + 짧은 진동
/// - 실패: 하강 저음 2음 + 긴 진동
/// - 수신: 짧은 단음
class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  // 오디오 재생기는 첫 사용 시점에 생성한다(앱 시작/테스트 환경 부담 최소화).
  AudioPlayer? _playerInstance;
  AudioPlayer get _player => _playerInstance ??= AudioPlayer();

  // earcon이 TTS 오디오 세션을 독점하지 않도록 다른 오디오와 섞는다.
  // play()의 ctx 인자로 넘기면 audioplayers가 컨텍스트 적용을 기다린 뒤 재생한다.
  AudioContext get _earconAudioContext =>
      AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();

  Future<void> _playEarcon(String file) async {
    try {
      await _player.stop();
      await _player.play(
        AssetSource('sounds/$file'),
        volume: 0.7,
        ctx: _earconAudioContext,
      );
    } catch (_) {
      // 오디오 미지원 환경(테스트/일부 데스크톱)에서는 시스템 사운드로 폴백한다.
      try {
        await SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// 명령 수신 earcon (짧은 단음)
  Future<void> playReceived() => _playEarcon('received.wav');

  /// 성공 earcon (상승 2음) — 실패음과 귀로 확실히 구분된다.
  Future<void> playSuccess() => _playEarcon('success.wav');

  /// 실패 earcon (하강 저음 2음)
  Future<void> playFailure() => _playEarcon('failure.wav');

  /// (구버전 호환) 인식 시작/완료 알림 — 수신음으로 매핑한다.
  Future<void> playDing() => playReceived();

  /// 짧고 강한 진동 (성공/확인)
  Future<void> vibrateSuccess() async {
    final hasVib = await Vibration.hasVibrator();
    if (hasVib == true) {
      Vibration.vibrate(duration: 100, amplitude: 255);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// 긴 진동 (경고/오류)
  Future<void> vibrateError() async {
    final hasVib = await Vibration.hasVibrator();
    if (hasVib == true) {
      Vibration.vibrate(duration: 400, amplitude: 255);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// 성공을 소리+진동으로 함께 전달한다.
  Future<void> signalSuccess() async {
    await playSuccess();
    await vibrateSuccess();
  }

  /// 실패를 소리+진동으로 함께 전달한다.
  Future<void> signalFailure() async {
    await playFailure();
    await vibrateError();
  }
}
