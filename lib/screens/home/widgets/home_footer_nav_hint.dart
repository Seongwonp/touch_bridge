import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/responsive_scale.dart';
import '../../../services/accessibility_settings.dart';

/// "좌우로 밀어서 기기 전환" 안내 + 이전/다음 화살표.
class HomeFooterNavHint extends StatelessWidget {
  const HomeFooterNavHint({
    super.key,
    required this.scale,
    required this.onPrevious,
    required this.onNext,
  });

  final double scale;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    final screenReaderActive = AccessibilitySettings.isScreenReaderActive;
    return Padding(
      padding: EdgeInsets.only(
        top: ResponsiveScale.v(context, 12),
        bottom: ResponsiveScale.v(context, 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Semantics(
            label: '이전 기기',
            button: true,
            excludeSemantics: true,
            onTap: onPrevious,
            child: IconButton(
              tooltip: '이전 기기',
              onPressed: onPrevious,
              icon: Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary, size: 28 * rs),
            ),
          ),
          // 화면용 안내다. 낭독기는 양옆 버튼 이름으로 충분해 읽지 않는다.
          ExcludeSemantics(
            child: Text(
            screenReaderActive ? '버튼으로 기기 전환' : '좌우로 밀어서 기기 전환',
            style: TextStyle(
              fontSize: 12 * rs,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppColors.textTertiary,
            ),
          ),
          ),
          Semantics(
            label: '다음 기기',
            button: true,
            excludeSemantics: true,
            onTap: onNext,
            child: IconButton(
              tooltip: '다음 기기',
              onPressed: onNext,
              icon: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 28 * rs),
            ),
          ),
        ],
      ),
    );
  }
}
