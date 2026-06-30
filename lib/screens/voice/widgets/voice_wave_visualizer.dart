import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 음성 녹음 중 표시되는 음파 막대 시각화.
class VoiceWaveVisualizer extends StatelessWidget {
  const VoiceWaveVisualizer({
    super.key,
    required this.waveHeights,
    required this.waveHeight,
    required this.isRecording,
    required this.scale,
  });

  final List<double> waveHeights;
  final double waveHeight;
  final bool isRecording;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: waveHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: waveHeights
            .map(
              (h) => AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 7 * scale,
                height: waveHeight * h,
                margin: EdgeInsets.symmetric(horizontal: 3 * scale),
                decoration: BoxDecoration(
                  color: isRecording ? AppColors.primary : AppColors.disabled,
                  borderRadius: BorderRadius.circular(4 * scale),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
