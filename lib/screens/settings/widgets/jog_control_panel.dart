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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    // 시각 요소가 축소되더라도 실제 터치 영역은 WCAG 최소 44dp를 유지한다.
    final buttonSize = ((compact ? 44.0 : 52.0) * rs)
        .clamp(44.0, double.infinity)
        .toDouble();
    final iconSize = (compact ? 26.0 : 32.0) * rs;
    final pad = (compact ? 10.0 : 14.0) * rs;
    final xyGap = (compact ? 26.0 : 40.0) * rs;
    final axisGap = (compact ? 28.0 : 54.0) * rs;
    return Container(
      padding: EdgeInsets.all((compact ? 12 : 16) * rs),
      decoration: const BoxDecoration(
        color: AppColors.surfaceElevated,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Column(
        children: [
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStepSizeSelector(rs),
                    SizedBox(height: 8 * rs),
                    _buildFeedRateDisplay(rs, compact: true),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStepSizeSelector(rs),
                    _buildFeedRateDisplay(rs),
                  ],
                ),
          SizedBox(height: (compact ? 12 : 18) * rs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Column(
                children: [
                  _jogButton(
                    Icons.arrow_upward,
                    () => onJog('Y', stepSize),
                    rs,
                    size: buttonSize,
                    iconSize: iconSize,
                    padding: pad,
                  ),
                  Row(
                    children: [
                      _jogButton(
                        Icons.arrow_back,
                        () => onJog('X', -stepSize),
                        rs,
                        size: buttonSize,
                        iconSize: iconSize,
                        padding: pad,
                      ),
                      SizedBox(width: xyGap),
                      _jogButton(
                        Icons.arrow_forward,
                        () => onJog('X', stepSize),
                        rs,
                        size: buttonSize,
                        iconSize: iconSize,
                        padding: pad,
                      ),
                    ],
                  ),
                  _jogButton(
                    Icons.arrow_downward,
                    () => onJog('Y', -stepSize),
                    rs,
                    size: buttonSize,
                    iconSize: iconSize,
                    padding: pad,
                  ),
                ],
              ),
              SizedBox(width: axisGap),
              Column(
                children: [
                  _jogButton(
                    Icons.keyboard_double_arrow_up,
                    () => onJog('Z', stepSize),
                    rs,
                    label: 'Z UP',
                    color: Colors.blueAccent,
                    size: buttonSize,
                    iconSize: iconSize,
                    padding: pad,
                  ),
                  SizedBox(height: (compact ? 12 : 20) * rs),
                  _jogButton(
                    Icons.keyboard_double_arrow_down,
                    () => onJog('Z', -stepSize),
                    rs,
                    label: 'Z DOWN',
                    color: Colors.blueAccent,
                    size: buttonSize,
                    iconSize: iconSize,
                    padding: pad,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            '이동 단위:',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13 * rs),
          ),
        ),
        SizedBox(width: 8 * rs),
        DropdownButton<double>(
          value: stepSize,
          dropdownColor: AppColors.surfaceElevated,
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 13 * rs,
          ),
          underline: Container(),
          items: [0.1, 0.5, 1.0, 5.0, 10.0].map((val) {
            return DropdownMenuItem(value: val, child: Text('${val}mm'));
          }).toList(),
          onChanged: (v) => onStepSizeChanged(v!),
        ),
      ],
    );
  }

  String _iconTooltip(IconData icon) {
    if (icon == Icons.arrow_upward) return 'Y축 앞으로';
    if (icon == Icons.arrow_downward) return 'Y축 뒤로';
    if (icon == Icons.arrow_back) return 'X축 왼쪽';
    if (icon == Icons.arrow_forward) return 'X축 오른쪽';
    if (icon == Icons.keyboard_double_arrow_up) return 'Z축 위로';
    if (icon == Icons.keyboard_double_arrow_down) return 'Z축 아래로';
    return '이동';
  }

  Widget _buildFeedRateDisplay(double rs, {bool compact = false}) {
    return SizedBox(
      width: compact ? double.infinity : 170 * rs,
      child: Column(
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.end,
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
    required double size,
    required double iconSize,
    required double padding,
  }) {
    final String tooltipText = label ?? _iconTooltip(icon);
    return Column(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: IconButton(
            tooltip: tooltipText,
            onPressed: onTap,
            icon: Icon(icon, color: color, size: iconSize),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.surface,
              padding: EdgeInsets.all(padding),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10 * rs),
              ),
            ),
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
