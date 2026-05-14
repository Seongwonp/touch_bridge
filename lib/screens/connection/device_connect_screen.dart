// TODO(hardware): BleService.scan() 결과로 _statusCard() 상태 동적 업데이트
// TODO(hardware): 블루투스 연결 버튼 → BleService.connect() 호출
// TODO(hardware): NFC 태그 → NFC 패키지로 ESP32 디바이스 ID 읽기
// TODO(hardware): 수동 입력 → IP/MAC 주소 입력 다이얼로그 → BleService.connect()

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart'; // TODO(hardware): BLE 연동 시 활성화
import 'qr_scan_screen.dart';

class DeviceConnectScreen extends StatelessWidget {
  const DeviceConnectScreen({super.key});

  void _showPlaceholder(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 기능은 다음 단계에서 연결됩니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
    TtsService().speak('$label 기능은 다음 단계에서 연결됩니다.'); // TTS 안내 추가
  }

  Widget _statusCard() {
    return Semantics( // 상태 카드 Semantics 추가
      label: 'ESP32 Smart Hub, 연결 가능한 기기 감지됨',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF00FF88),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESP32 Smart Hub',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '연결 가능한 기기 감지됨',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool highlighted,
  }) {
    return Semantics( // 옵션 카드 Semantics 추가
      label: '$title. $subtitle. 버튼',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: highlighted ? const Color(0xFFFFEB00) : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? Colors.transparent : const Color(0xFF2A2A2A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? Colors.black.withValues(alpha: 0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: highlighted
                        ? null
                        : Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Icon(
                    icon,
                    color: highlighted ? Colors.black : const Color(0xFFFFEB00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: highlighted ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: highlighted
                              ? Colors.black.withValues(alpha: 0.6)
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: highlighted
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFF555555),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallAction({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics( // 작은 액션 Semantics 추가
        label: '$title 버튼',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF888888), size: 22),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Semantics( // 앱 타이틀 Semantics 추가
                label: 'Touch Bridge 앱',
                child: const Row(
                  children: [
                    Text(
                      'Touch Bridge',
                      style: TextStyle(
                        color: Color(0xFFFFEB00),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '기기 연결',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '기기를 연결하여 제어를 시작하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _statusCard(),
                    const SizedBox(height: 12),
                    _optionCard(
                      context: context,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'QR 코드 스캔',
                      subtitle: '허브의 QR을 촬영하여 즉시 연결',
                      highlighted: true,
                      onTap: () async {
                        TtsService().speak('QR 코드 스캔 화면으로 이동합니다.');
                        final result = await Navigator.of(context).push<Map<String, String>>(
                          MaterialPageRoute(builder: (_) => const QrScanScreen()),
                        );
                        if (result != null && context.mounted) {
                          final name = result['name'] ?? '알 수 없는 기기';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$name 기기가 인식되었습니다. 홈에서 기기를 추가하세요.'),
                              backgroundColor: const Color(0xFF00FF88),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _optionCard(
                      context: context,
                      icon: Icons.bluetooth_rounded,
                      title: '블루투스 연결',
                      subtitle: '주변 기기 자동 검색 및 페어링',
                      highlighted: false,
                      onTap: () {
        // TODO(hardware): BleService.instance.scan() 호출 → 결과 목록 BottomSheet 표시
        // TODO(hardware): 선택 시 BleService.instance.connect(deviceId)
        _showPlaceholder(context, '블루투스 연결');
      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _smallAction(
                          context: context,
                          title: 'NFC 태그',
                          icon: Icons.nfc_rounded,
                          onTap: () => _showPlaceholder(context, 'NFC 태그'),
                        ),
                        const SizedBox(width: 10),
                        _smallAction(
                          context: context,
                          title: '수동 입력',
                          icon: Icons.keyboard_rounded,
                          onTap: () => _showPlaceholder(context, '수동 입력'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Semantics( // 도움말 텍스트 Semantics 추가
                      label: '연결에 문제가 있나요? 도움말 보기 버튼',
                      button: true,
                      child: Center(
                        child: Text(
                          '연결에 문제가 있나요? 도움말 보기',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
