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
        Text(
          label,
          style: TextStyle(color: AppColors.textTertiary, fontSize: 12 * rs),
        ),
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
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12 * rs,
              vertical: 8 * rs,
            ),
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
  });

  final IconData icon;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.primary, size: 32 * scale),
      style: IconButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        padding: EdgeInsets.all(12 * scale),
      ),
    );
  }
}

/// 매핑 화면의 텍스트 액션 버튼 (모터 테스트/원점 지정/테스트 터치 등 공용).
class MappingActionChip extends StatelessWidget {
  const MappingActionChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.scale,
  });

  final String label;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.surfaceElevated,
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 8 * rs),
      ),
      child: Text(label, style: TextStyle(fontSize: 14 * rs)),
    );
  }
}
