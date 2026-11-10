import 'dart:async';

import 'package:flutter/material.dart';
import '../../../models/voice_example_commands.dart';
import '../../../services/accessibility_settings.dart';
import '../../../theme/app_colors.dart';

export '../../../models/voice_example_commands.dart' show kVoiceExampleCommands;

/// 대기 상태에서 보여주는 예시 명령어 칩 목록.
///
/// 칩은 가전 버튼을 누르는 물리 동작이므로 첫 탭은 [onArmed]로 확인만 하고,
/// [kDoubleTapArmTimeout] 안에 같은 칩을 다시 탭해야 [onConfirmed]로 실행한다.
/// 낭독기로 칩을 훑어보다 실행되지 않게 하기 위함이다.
class VoiceExampleCommands extends StatefulWidget {
  const VoiceExampleCommands({
    super.key,
    required this.scale,
    required this.onArmed,
    required this.onConfirmed,
  });

  final double scale;

  /// 첫 탭. 화면은 "한 번 더 누르면 실행합니다"를 안내한다.
  final ValueChanged<String> onArmed;

  /// 같은 칩의 두 번째 탭. 이때만 명령을 보낸다.
  final ValueChanged<String> onConfirmed;

  @override
  State<VoiceExampleCommands> createState() => _VoiceExampleCommandsState();
}

class _VoiceExampleCommandsState extends State<VoiceExampleCommands> {
  String? _armed;
  Timer? _armTimer;

  @override
  void dispose() {
    _armTimer?.cancel();
    super.dispose();
  }

  void _onTap(String cmd) {
    if (_armed != cmd) {
      _armTimer?.cancel();
      setState(() => _armed = cmd);
      _armTimer = Timer(kDoubleTapArmTimeout, () {
        if (mounted) setState(() => _armed = null);
      });
      widget.onArmed(cmd);
      return;
    }
    _armTimer?.cancel();
    setState(() => _armed = null);
    widget.onConfirmed(cmd);
  }

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
                  value: cmd == _armed ? '한 번 더 누르면 실행' : null,
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
