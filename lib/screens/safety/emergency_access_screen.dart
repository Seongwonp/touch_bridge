import 'package:flutter/material.dart';

import '../../services/emergency_stop_service.dart';
import '../../services/feedback_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/emergency_button.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import 'stop_done_screen.dart';

class EmergencyAccessScreen extends StatefulWidget {
  const EmergencyAccessScreen({super.key});

  @override
  State<EmergencyAccessScreen> createState() => _EmergencyAccessScreenState();
}

class _EmergencyAccessScreenState extends State<EmergencyAccessScreen> {
  final TtsService _tts = TtsService();
  bool _isStopping = false;

  // 진입 안내는 하지 않는다. 하단 탭이 IndexedStack이라 이 화면은 앱 시작 때 함께
  // 만들어지므로, 여기서 말하면 홈에 있는데도 비상 정지 안내가 들린다.
  // 탭으로 들어올 때의 안내는 MainNavigationScreen이 맡는다.

  @override
  void dispose() {
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다.
    super.dispose();
  }

  Future<void> _stopNow() async {
    if (_isStopping) return;
    setState(() => _isStopping = true);
    FeedbackService.instance.vibrateError();

    await _tts.speak(
      '즉시 중단합니다.',
      priority: TtsPriority.emergency,
      interrupt: true,
    );

    // 대상 결정 → 재연결 → STOP 전송 → ACK 해석은 EmergencyStopService가 담당한다.
    // 전송 성공만으로 "완료"라고 말하지 않는다 — outcome이 문구를 분기한다.
    final outcome = await EmergencyStopService.instance.stopActiveDevice();
    if (outcome.acknowledged) {
      FeedbackService.instance.playSuccess();
    } else {
      FeedbackService.instance.playFailure();
    }
    await _tts.speak(
      outcome.message,
      priority: TtsPriority.emergency,
      interrupt: true,
    );

    if (!mounted) return;
    setState(() => _isStopping = false);
    if (outcome.acknowledged) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: '비상 정지', showEmergency: false),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24 * rs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 24 * rs),
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.emergency,
                size: 72 * rs,
              ),
              SizedBox(height: 24 * rs),
              Text(
                '긴급 상황이면\n즉시 중단하세요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30 * rs,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
              SizedBox(height: 12 * rs),
              Text(
                '버튼을 한 번 누르면 바로 멈춥니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFFD1D5DB),
                  fontSize: 16 * rs,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              EmergencyButton(
                label: _isStopping ? '중단 중' : '즉시 중단',
                onPressed: _stopNow,
              ),
              SizedBox(height: 28 * rs),
            ],
          ),
        ),
      ),
    );
  }
}
