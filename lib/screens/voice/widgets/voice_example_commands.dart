import 'package:flutter/material.dart';
import '../../../models/voice_example_commands.dart';
import '../../../theme/app_colors.dart';

export '../../../models/voice_example_commands.dart' show kVoiceExampleCommands;

/// 대기 상태에서 보여주는 예시 명령어 칩 목록.
///
/// 칩을 누르면 그 문장을 명령으로 보낸다. 가전을 누르기 전에는 음성 화면이
/// '실행'·'취소'로 한 번 확인하므로, 칩 자체에는 두 번 누르기를 두지 않는다.
class VoiceExampleCommands extends StatefulWidget {
  const VoiceExampleCommands({
    super.key,
    required this.scale,
    required this.onSelected,
  });

  final double scale;

  /// 칩을 눌렀을 때. 화면은 이 문장을 해석한 뒤 실행할지 묻는다.
  final ValueChanged<String> onSelected;

  @override
  State<VoiceExampleCommands> createState() => _VoiceExampleCommandsState();
}

class _VoiceExampleCommandsState extends State<VoiceExampleCommands> {
  void _onTap(String cmd) => widget.onSelected(cmd);

  @override
  Widget build(BuildContext context) {
    final scale = widget.scale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '예시 명령어',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 13 * scale,
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        Wrap(
          spacing: 8 * scale,
          runSpacing: 8 * scale,
          children: kVoiceExampleCommands
              .map(
                (cmd) => Semantics(
                  button: true,
                  label: '예시 명령, $cmd',
                  excludeSemantics: true,
                  onTap: () => _onTap(cmd),
                  child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTap(cmd),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: EdgeInsets.symmetric(
                      horizontal: 14 * scale,
                      vertical: 8 * scale,
                    ),
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
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
