import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 기기 카드 PageView의 현재 위치를 보여주는 점 인디케이터.
class DevicePageIndicator extends StatelessWidget {
  const DevicePageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.scale,
  });

  final int count;
  final int currentIndex;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final bool active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(horizontal: 4 * rs),
          width: active ? 32 * rs : 8 * rs,
          height: 4 * rs,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(2 * rs),
          ),
        );
      }),
    );
  }
}
