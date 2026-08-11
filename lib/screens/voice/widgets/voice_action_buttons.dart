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

  @override
  Widget build(BuildContext context) {
    if (isRecording) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: Semantics(
              label: '듣기 멈추기',
              button: true,
              child: GestureDetector(
                onTap: onMicTap,
                child: Container(
                  height: 80 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(16 * scale),
                    border: micArmed
                        ? Border.all(color: Colors.white, width: 3 * scale)
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop_circle_outlined, color: Colors.black, size: 28 * scale),
                      SizedBox(width: 8 * scale),
                      Text(
                        '듣기 멈추기',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 19 * scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 12 * scale),
          Expanded(
            flex: 2,
            child: Semantics(
              label: '취소',
              button: true,
              child: GestureDetector(
                onTap: onCancelRecording,
                child: Container(
                  height: 80 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16 * scale),
                    border: Border.all(color: AppColors.borderDefault),
                  ),
                  child: Center(
                    child: Text(
                      '취소',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 19 * scale,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isIdle) {
      return Semantics(
        label: '음성 명령 시작',
        button: true,
        child: GestureDetector(
          onTap: onMicTap,
          child: Container(
            width: double.infinity,
            height: 80 * scale,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16 * scale),
              border: micArmed
                  ? Border.all(color: Colors.white, width: 3 * scale)
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: Colors.black, size: 30 * scale),
                SizedBox(width: 10 * scale),
                Text(
                  micArmed ? '지금 누르면 녹음 시작' : '녹음 준비',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 19 * scale,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 80 * scale,
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
