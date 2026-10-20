import 'package:flutter/material.dart';

import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/top_app_bar.dart';

/// QR 스캔 화면 — 현재 비활성화 상태.
///
/// mobile_scanner 의존성이 없어 스캔 기능이 빠져 있다. 화면만 열고 침묵하면
/// 전맹 사용자가 카메라를 조준하며 기다리게 되므로, 재활성화 전까지는 상태를
/// 그대로 안내하고 대안 경로(블루투스 허브 / 기기 코드 입력)로 유도한다.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  @override
  void initState() {
    super.initState();
    TtsService().speak(
      'QR 스캔은 현재 사용할 수 없습니다. 뒤로 가서 블루투스 허브 연결이나 '
      '기기 코드 입력을 이용해 주세요.',
      source: 'QrScanScreen',
      interrupt: true,
      priority: TtsPriority.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'QR 스캔', showBack: true),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                color: AppColors.textTertiary,
                size: 72,
              ),
              const SizedBox(height: 20),
              const Text(
                'QR 스캔을 사용할 수 없습니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '블루투스 허브 연결 또는 기기 코드 입력으로\n기기를 등록해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
