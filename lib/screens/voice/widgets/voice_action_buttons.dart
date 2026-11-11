import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 음성 화면의 상태별(녹음 중/대기/분석 중) 메인 액션 버튼 영역.
class VoiceActionButtons extends StatelessWidget {
  const VoiceActionButtons({
    super.key,
    required this.isRecording,
    required this.isIdle,
    required this.micArmed,
    required this.scale,
    required this.onMicTap,
    required this.onCancelRecording,
    required this.onCancelAnalysis,
  });

  final bool isRecording;
  final bool isIdle;
  final bool micArmed;
  final double scale;
  final VoidCallback onMicTap;
  final VoidCallback onCancelRecording;
  final VoidCallback onCancelAnalysis;

  /// 대기·듣기 상태에서 같은 자리에 있는 하나의 큰 버튼. 낭독기가 읽는 이름을 '말하기'로
  /// 고정한다. 예전에는 듣기가 시작되면 버튼이 '듣기 멈추기'·'취소' 두 개로 바뀌어 낭독기
  /// 포커스가 '취소'로 옮겨 가며 그 이름을 읽었고, 막 열린 마이크가 그 소리를 '취소' 명령으로
  /// 받아 처리했다(실기). 이름이 그대로면 낭독기는 다시 읽지 않는다. 상태는 띵 소리와 상태
  /// 문구로 알리고, 같은 버튼을 다시 누르면 듣기를 멈춘다.
  Widget _mainButton() {
    return Semantics(
      key: const ValueKey('voice_main_action'),
      label: '말하기',
      button: true,
      excludeSemantics: true,
      onTap: onMicTap,
      child: GestureDetector(
        onTap: onMicTap,
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: 80 * scale),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16 * scale),
            border: micArmed
                ? Border.all(color: Colors.white, width: 3 * scale)
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10 * scale),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRecording ? Icons.stop_circle_outlined : Icons.mic,
                  color: Colors.black,
                  size: 30 * scale,
                ),
                SizedBox(width: 10 * scale),
                Flexible(
                  child: Text(
                    isRecording ? '듣는 중 · 누르면 멈춤' : '말하기 시작',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 19 * scale,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isRecording || isIdle) {
      // 대기와 듣기에서 같은 트리 모양을 유지해 큰 버튼이 같은 낭독 항목으로 남게 한다.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _mainButton(),
          if (isRecording) ...[
            SizedBox(height: 12 * scale),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: 64 * scale),
              child: OutlinedButton(
                // '취소'는 실제 가전 명령이기도 해서, 듣는 중에 읽혀도 명령으로 오인되지
                // 않는 이름을 쓴다.
                onPressed: onCancelRecording,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.borderDefault),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16 * scale),
                  ),
                ),
                child: Text(
                  '녹음 취소',
                  style: TextStyle(fontSize: 18 * scale, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 80 * scale, minWidth: double.infinity),
      child: OutlinedButton.icon(
        onPressed: onCancelAnalysis,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.textTertiary),
          foregroundColor: AppColors.textSecondary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * scale)),
        ),
        icon: const Icon(Icons.close_rounded, size: 28),
        label: Text(
          '분석 취소',
          style: TextStyle(fontSize: 19 * scale, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
