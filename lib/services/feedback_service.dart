import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'dart:io';

class FeedbackService {
  FeedbackService._();
  static final FeedbackService instance = FeedbackService._();

  final AudioPlayer _audioPlayer = AudioPlayer();

  /// 짧고 강한 진동 (성공/확인)
  Future<void> vibrateSuccess() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 100, amplitude: 255);
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  /// 긴 진동 (경고/오류)
  Future<void> vibrateError() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(duration: 400, amplitude: 255);
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  /// "띠링" 소리 (인식 시작/완료)
  Future<void> playDing() async {
    try {
      // 시스템 사운드 활용 시도 (플랫폼별 다름)
      if (Platform.isIOS) {
        await SystemSound.play(SystemSoundType.click);
      } else {
        // 안드로이드는 적절한 시스템 사운드 찾기 어려우므로 추후 에셋 추가 권장
        // 임시로 클릭음 사용
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      // 무시
    }
  }

  /// 명령 인식 성공 소리
  Future<void> playSuccess() async {
    // 실제 구현 시에는 에셋 파일 필요
    // await _audioPlayer.play(AssetSource('sounds/success.mp3'));
    await SystemSound.play(SystemSoundType.click);
  }
}
