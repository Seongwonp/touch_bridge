import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class ButtonMarker extends StatelessWidget {
  final int index;
  final String label;
  final double rs;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ButtonMarker({
    super.key,
    required this.index,
    required this.label,
    required this.rs,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // 시각 크기(40*rs)가 48dp 미만이더라도 터치 영역은 최소 48dp 보장.
    final visualSize = 40.0 * rs;
    final hitSize = visualSize.clamp(48.0, double.infinity);
    final buttonNumber = index + 1;

    return Semantics(
      button: true,
      label: '버튼 $buttonNumber: $label',
      hint: '탭하면 테스트 터치, 길게 누르면 이름 변경',
      customSemanticsActions: {
        const CustomSemanticsAction(label: '이름 변경'): onLongPress,
        const CustomSemanticsAction(label: '테스트 터치'): onTap,
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        // 터치 영역을 hitSize로 확장하되 시각적 크기는 유지한다.
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: hitSize,
          height: hitSize,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: visualSize,
                  height: visualSize,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEB00).withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2 * rs),
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8 * rs)],
                  ),
                  child: Center(
                    child: Text(
                      '$buttonNumber',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18 * rs),
                    ),
                  ),
                ),
                SizedBox(height: 4 * rs),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6 * rs, vertical: 2 * rs),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(4 * rs),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(color: Colors.white, fontSize: 10 * rs),
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
