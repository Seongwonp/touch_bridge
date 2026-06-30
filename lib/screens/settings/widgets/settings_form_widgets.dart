import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/responsive_scale.dart';

/// 설정 화면 섹션 제목 (아이콘 + 라벨).
class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18 * rs),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 13 * rs,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// 설정 행들을 감싸는 카드 컨테이너.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16 * rs),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(children: children),
    );
  }
}

/// SettingsCard 안의 행 구분선.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppColors.borderDefault);
}

/// 라벨 + 슬라이더 + 현재값 표시 행 (TTS 속도/음량 등).
class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;
  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16 * rs, 14 * rs, 16 * rs, 6 * rs),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17 * rs,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                display,
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14 * rs,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.borderDefault,
          ),
        ],
      ),
    );
  }
}

/// 제목 + 부제목 + 토글 스위치 행 (음성 안내, 보호자 모드 등).
class SwitchRow extends StatelessWidget {
  const SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 4 * rs),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17 * rs,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 13 * rs),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

/// 다른 화면으로 이동하는 설정 행 (화살표 trailing 포함).
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16 * rs,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppColors.textTertiary, fontSize: 12 * rs),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textTertiary,
      ),
      onTap: onTap,
    );
  }
}

/// 비상 연락처 편집 다이얼로그의 입력 필드 (이름/전화번호).
class ContactField extends StatelessWidget {
  const ContactField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textTertiary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            filled: true,
            fillColor: AppColors.surfaceElevated,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}

/// 비상 연락처가 비어있을 때 보여주는 "연락처 추가" 행.
class EmptyContactRow extends StatelessWidget {
  const EmptyContactRow({super.key, required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(Icons.add_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '연락처 추가',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '보호자를 등록하세요',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 등록된 비상 연락처 정보를 보여주는 행 (전화/편집 액션 포함).
class ContactRow extends StatelessWidget {
  const ContactRow({
    super.key,
    required this.name,
    required this.phone,
    required this.onCall,
    required this.onEdit,
  });
  final String name;
  final String phone;
  final VoidCallback onCall;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0] : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                phone,
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_rounded, color: AppColors.textTertiary),
        ),
        IconButton(
          onPressed: onCall,
          icon: const Icon(Icons.call_rounded, color: AppColors.emergency),
        ),
      ],
    );
  }
}
