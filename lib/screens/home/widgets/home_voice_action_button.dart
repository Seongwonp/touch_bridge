import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 홈 화면의 "말하기" 음성 제어 시작 버튼.
class HomeVoiceActionButton extends StatelessWidget {
  const HomeVoiceActionButton({
    super.key,
    required this.deviceName,
    required this.enabled,
    required this.scale,
    required this.onTap,
  });

  final String deviceName;
  final bool enabled;
  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return Semantics(
      label: '$deviceName 음성 제어 시작',
      button: true,
      child: Container(
        height: 80 * rs,
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: AppColors.primaryGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.disabled,
          borderRadius: BorderRadius.circular(14 * rs),
          boxShadow: enabled
              ? const [BoxShadow(color: AppColors.shadowPrimary, blurRadius: 14)]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(14 * rs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_rounded, size: 28 * rs, color: Colors.black),
                SizedBox(width: 10 * rs),
                Text(
                  '말하기',
                  style: TextStyle(
                    fontSize: 22 * rs,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
