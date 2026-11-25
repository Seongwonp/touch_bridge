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
    // 버튼 글자 '말하기'와 라벨이 이어 읽혀 같은 말이 두 번 나오지 않게 하나로 합친다.
    return Semantics(
      label: '말하기',
      hint: '$deviceName에 음성으로 명령합니다',
      button: true,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: BoxConstraints(minHeight: 80 * rs),
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
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 10 * rs),
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
      ),
    );
  }
}
