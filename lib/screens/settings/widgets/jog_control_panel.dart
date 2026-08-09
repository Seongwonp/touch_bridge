import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

/// 개발자 콘솔의 XY/Z축 조깅 패널 (이동 단위/속도 설정 + 방향키).
class JogControlPanel extends StatelessWidget {
  const JogControlPanel({
    super.key,
    required this.stepSize,
    required this.feedRate,
    required this.scale,
    required this.onStepSizeChanged,
    required this.onFeedRateChanged,
    required this.onJog,
  });

  final double stepSize;
  final double feedRate;
  final double scale;
  final ValueChanged<double> onStepSizeChanged;
  final ValueChanged<double> onFeedRateChanged;
  final void Function(String axis, double value) onJog;

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return Container(
      padding: EdgeInsets.all(16 * rs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStepSizeSelector(rs),
              _buildFeedRateDisplay(rs),
            ],
          ),
          SizedBox(height: 20 * rs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  _jogButton(Icons.arrow_upward, () => onJog('Y', stepSize), rs),
                  Row(
                    children: [
                      _jogButton(Icons.arrow_back, () => onJog('X', -stepSize), rs),
                      SizedBox(width: 40 * rs),
                      _jogButton(Icons.arrow_forward, () => onJog('X', stepSize), rs),
                    ],
                  ),
                  _jogButton(Icons.arrow_downward, () => onJog('Y', -stepSize), rs),
                ],
              ),
              SizedBox(width: 60 * rs),
              Column(
                children: [
                  _jogButton(
                    Icons.keyboard_double_arrow_up,
                    () => onJog('Z', stepSize),
                    rs,
                    label: 'Z UP',
                    color: Colors.blueAccent,
                  ),
                  SizedBox(height: 20 * rs),
                  _jogButton(
                    Icons.keyboard_double_arrow_down,
                    () => onJog('Z', -stepSize),
                    rs,
                    label: 'Z DOWN',
                    color: Colors.blueAccent,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepSizeSelector(double rs) {
    return Row(
      children: [
        Text('이동 단위:', style: TextStyle(color: AppColors.textSecondary, fontSize: 13 * rs)),
        SizedBox(width: 8 * rs),
        DropdownButton<double>(
          value: stepSize,
          dropdownColor: AppColors.surfaceElevated,
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          underline: Container(),
          items: [0.1, 0.5, 1.0, 5.0, 10.0].map((val) {
            return DropdownMenuItem(value: val, child: Text('${val}mm'));
          }).toList(),
          onChanged: (v) => onStepSizeChanged(v!),
        ),
      ],
    );
  }

  Widget _buildFeedRateDisplay(double rs) {
    return SizedBox(
      width: 170 * rs,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '속도: F${feedRate.round()}',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13 * rs),
          ),
          Slider(
            value: feedRate,
            min: 100,
            max: 2000,
            divisions: 19,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.disabled,
            onChanged: onFeedRateChanged,
          ),
        ],
      ),
    );
  }

  Widget _jogButton(
    IconData icon,
    VoidCallback onTap,
    double rs, {
    String? label,
    Color color = AppColors.primary,
  }) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 36 * rs),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            padding: EdgeInsets.all(12 * rs),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * rs)),
          ),
        ),
        if (label != null) ...[
          SizedBox(height: 4 * rs),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.7),
              fontSize: 10 * rs,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ],
    );
  }
}
