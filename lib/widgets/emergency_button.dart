import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 비상 정지 버튼. 한 번 누르면 확인 없이 바로 [onPressed]를 부른다.
///
/// 정지는 추가 확인을 두지 않는다(`docs/USER_FLOW_REDESIGN_PROPOSAL.md` 9절).
/// 잘못 눌러도 멈출 뿐이고, 급할 때 두 번 눌러야 하는 비용이 더 크다.
class EmergencyButton extends StatelessWidget {
  const EmergencyButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      hint: '누르면 확인 없이 바로 멈춥니다',
      excludeSemantics: true,
      onTap: () {
        HapticFeedback.heavyImpact();
        onPressed();
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 84),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              HapticFeedback.heavyImpact();
              onPressed();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              textStyle: Theme.of(context).textTheme.titleLarge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.warning_amber_rounded, size: 28),
            label: Text(label),
          ),
        ),
      ),
    );
  }
}
