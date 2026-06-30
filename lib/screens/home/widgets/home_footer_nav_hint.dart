import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/responsive_scale.dart';

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
    return Padding(
      padding: EdgeInsets.only(
        top: ResponsiveScale.v(context, 12),
        bottom: ResponsiveScale.v(context, 8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: Icon(Icons.chevron_left_rounded, color: AppColors.textTertiary, size: 28 * rs),
          ),
          Text(
            '좌우로 밀어서 기기 전환',
            style: TextStyle(
              fontSize: 12 * rs,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: AppColors.textTertiary,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary, size: 28 * rs),
          ),
        ],
      ),
    );
  }
}
