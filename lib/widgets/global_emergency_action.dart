import 'package:flutter/material.dart';

import '../screens/safety/stop_done_screen.dart';
import '../services/emergency_stop_service.dart';
import '../services/feedback_service.dart';
import '../services/tts_service.dart';
import '../theme/app_colors.dart';

/// 모든 화면의 상단 앱바에 상주하는 전역 비상 정지 버튼.
///
/// 한 번 누르면 확인 없이 바로 정지를 요청한다(정지는 추가 확인을 두지 않는다는
/// 결정, `docs/USER_FLOW_REDESIGN_PROPOSAL.md` 9절). 잘못 눌러도 멈출 뿐이므로
/// 확인 단계가 주는 이득보다, 급할 때 두 번 눌러야 하는 비용이 크다.
/// 오른쪽 위 모서리는 화면을 더듬어 찾기 쉬운 자리이고, 낭독 순서에서는 화면
/// 제목 바로 다음이다. 모든 발화는 emergency 우선순위로 낭독기 사용 중에도 들린다.
class GlobalEmergencyAction extends StatefulWidget {
  const GlobalEmergencyAction({super.key});

  @override
  State<GlobalEmergencyAction> createState() => _GlobalEmergencyActionState();
}

class _GlobalEmergencyActionState extends State<GlobalEmergencyAction> {
  final TtsService _tts = TtsService();
  bool _stopping = false;

  @override
  void dispose() {
    _tts.cancelSource('GlobalEmergencyAction');
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    FeedbackService.instance.vibrateError();
    await _tts.speak(
      '즉시 중단합니다.',
      source: 'GlobalEmergencyAction',
      priority: TtsPriority.emergency,
      interrupt: true,
    );

    final outcome = await EmergencyStopService.instance.stopActiveDevice();
    if (outcome.acknowledged) {
      FeedbackService.instance.playSuccess();
    } else {
      FeedbackService.instance.playFailure();
    }
    await _tts.speak(
      outcome.message,
      source: 'GlobalEmergencyAction',
      priority: TtsPriority.emergency,
      interrupt: true,
    );

    if (!mounted) return;
    setState(() => _stopping = false);
    if (outcome.acknowledged) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '비상 정지',
      hint: _stopping ? '정지 명령을 보내는 중입니다' : '누르면 확인 없이 바로 멈춥니다',
      excludeSemantics: true,
      onTap: _handleTap,
      child: InkWell(
        onTap: _handleTap,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          // 앱바 안에서 가능한 크게. 최소 터치 영역 48dp보다 넉넉히 둔다.
          constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.emergency,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: _stopping
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                )
              : const Icon(Icons.back_hand, size: 28, color: Colors.white),
        ),
      ),
    );
  }
}
