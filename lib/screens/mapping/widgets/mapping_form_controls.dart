import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 라벨 + 숫자 입력 필드 (그리드/원점/간격 설정 등에서 재사용).
class LabeledNumberField extends StatelessWidget {
  const LabeledNumberField({
    super.key,
    required this.label,
    required this.controller,
    required this.scale,
  });

  final String label;
  final TextEditingController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.textTertiary, fontSize: 12 * rs)),
        SizedBox(height: 6 * rs),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8 * rs),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12 * rs, vertical: 8 * rs),
          ),
        ),
      ],
    );
  }
}

/// 조깅용 방향 아이콘 버튼.
class JogArrowButton extends StatelessWidget {
  const JogArrowButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.scale,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double scale;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip ?? _defaultTooltip(),
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.primary, size: 32 * scale),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        padding: EdgeInsets.all(12 * scale),
      ),
    );
  }

  String _defaultTooltip() {
    if (icon == Icons.arrow_upward) return '위로 이동';
    if (icon == Icons.arrow_downward) return '아래로 이동';
    if (icon == Icons.arrow_back) return '왼쪽으로 이동';
    if (icon == Icons.arrow_forward) return '오른쪽으로 이동';
    return '이동';
  }
}

/// 매핑 화면의 텍스트 액션 버튼 (모터 테스트/원점 지정/테스트 터치 등 공용).
/// [armed]가 true면 dead-man 확인 대기 중임을 노란 테두리로 표시한다.
class MappingActionChip extends StatelessWidget {
  const MappingActionChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.scale,
    this.armed = false,
  });

  final String label;
  final VoidCallback onTap;
  final double scale;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            armed ? AppColors.primary.withValues(alpha: 0.18) : AppColors.surfaceElevated,
        foregroundColor: armed ? AppColors.primary : AppColors.textPrimary,
        side: armed
            ? const BorderSide(color: AppColors.primary, width: 2)
            : BorderSide.none,
        padding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 8 * rs),
      ),
      child: Text(
        armed ? '$label ✓' : label,
        style: TextStyle(fontSize: 14 * rs),
      ),
    );
  }
}
