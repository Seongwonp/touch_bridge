import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';

const List<String> kVoiceExampleCommands = [
  '1번 눌러줘',
  '2번 눌러줘',
  '8번 눌러줘',
  '만두 데워줘',
  '우유 따뜻하게',
  '30초 돌려줘',
  '해동해줘',
];

/// 대기 상태에서 보여주는 예시 명령어 칩 목록. 탭하면 해당 명령을 바로 실행한다.
class VoiceExampleCommands extends StatelessWidget {
  const VoiceExampleCommands({
    super.key,
    required this.scale,
    required this.onCommandTap,
  });

  final double scale;
  final ValueChanged<String> onCommandTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '예시 명령어',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 13 * scale),
          ),
        ),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: kVoiceExampleCommands
              .map(
                (cmd) => GestureDetector(
                  onTap: () => onCommandTap(cmd),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14 * scale, vertical: 8 * scale),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(20 * scale),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Text(
                      cmd,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14 * scale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
