import 'package:flutter/material.dart';

import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tts.speak(
      '비상 정지 화면입니다. 큰 빨간 버튼을 한 번 누르면 안내하고, 한 번 더 누르면 현재 기기를 즉시 중단합니다.',
      source: 'EmergencyAccessScreen',
      interrupt: true,
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _stopNow() async {
    if (_isStopping) return;
    setState(() => _isStopping = true);
    FeedbackService.instance.vibrateError();

    final connectedBleId = BleService.instance.connectedDeviceId;
    final activeBleId = ActiveDeviceService.instance.getActiveBleId();
    final targetId = connectedBleId.isNotEmpty ? connectedBleId : activeBleId;

    if (targetId == null || targetId.isEmpty) {
      await _tts.speak('연결된 기기가 없습니다. 기기 전원을 확인해 주세요.');
      if (mounted) setState(() => _isStopping = false);
      return;
    }

    await _tts.speak('즉시 중단합니다.', interrupt: true);
    if (!BleService.instance.isConnected) {
      await BleService.instance.ensureConnected(targetId);
    }
    await BleService.instance.sendEmergencyStop(targetId);

    if (!mounted) return;
    setState(() => _isStopping = false);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const StopDoneScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: '비상 정지'),
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
                '버튼을 두 번 눌러 실행합니다.',
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
                firstTapGuide: '즉시 중단 버튼입니다. 한 번 더 누르면 현재 연결된 기기를 멈춥니다.',
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
