import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/primary_button.dart';
import '../../services/tts_service.dart'; // TtsService 임포트

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  final TtsService _tts = TtsService(); // TtsService 인스턴스 생성

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _tts.speak('QR 코드 스캔 화면입니다. 프레임 안에 QR 코드를 맞춰주세요.'); // 화면 진입 시 TTS 안내
  }

  @override
  void dispose() {
    _scanController.dispose();
    _tts.stop(); // TtsService 리소스 해제
    super.dispose();
  }

  void _showPlaceholder(String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 기능은 다음 단계에서 연결됩니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
    _tts.speak('$label 기능은 다음 단계에서 연결됩니다.'); // TTS 안내 추가
  }

  Widget _corner({
    required Alignment alignment,
    required BorderRadius borderRadius,
    required Border border,
  }) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(borderRadius: borderRadius, border: border),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color deepNavy = Color(0xFF041329);
    const Color yellow = Color(0xFFFDE047);

    return Scaffold(
      backgroundColor: deepNavy,
      body: Stack(
        children: [
          // Background Decoration (Semantics는 필요 없음)
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.2),
                radius: 1.1,
                colors: [Color(0xFF233148), Color(0xFF041329)],
              ),
            ),
          ),
          Container(color: const Color(0x99041329)),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Semantics( // 닫기 버튼 Semantics 추가
                          label: '닫기 버튼',
                          button: true,
                          child: IconButton(
                            onPressed: () {
                              _tts.speak('이전 화면으로 돌아갑니다.'); // TTS 안내 추가
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close, color: yellow),
                            tooltip: '닫기',
                          ),
                        ),
                        Expanded(
                          child: Semantics( // 화면 타이틀 Semantics 추가
                            label: 'QR 코드 스캔 화면',
                            child: const Text(
                              'Scan QR Code',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: yellow,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        Semantics( // 지시 텍스트 Semantics 추가
                          label: '프레임 안에 QR 코드를 맞춰주세요',
                          child: const Text(
                            '프레임 안에 QR 코드를 맞춰주세요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 31,
                              fontWeight: FontWeight.w900,
                              height: 1.12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Semantics( // 보조 지시 텍스트 Semantics 추가
                          label: '노란 가이드 프레임 안에 코드를 맞추면 자동으로 인식해요',
                          child: const Text(
                            '노란 가이드 프레임 안에 코드를 맞추면 자동으로 인식해요',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFFCEC6AD),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            children: [
                              // QR 스캔 프레임 코너 (Semantics는 필요 없음)
                              _corner(
                                alignment: Alignment.topLeft,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(20),
                                ),
                                border: const Border(
                                  top: BorderSide(color: yellow, width: 5),
                                  left: BorderSide(color: yellow, width: 5),
                                ),
                              ),
                              _corner(
                                alignment: Alignment.topRight,
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(20),
                                ),
                                border: const Border(
                                  top: BorderSide(color: yellow, width: 5),
                                  right: BorderSide(color: yellow, width: 5),
                                ),
                              ),
                              _corner(
                                alignment: Alignment.bottomLeft,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                ),
                                border: const Border(
                                  bottom: BorderSide(color: yellow, width: 5),
                                  left: BorderSide(color: yellow, width: 5),
                                ),
                              ),
                              _corner(
                                alignment: Alignment.bottomRight,
                                borderRadius: const BorderRadius.only(
                                  bottomRight: Radius.circular(20),
                                ),
                                border: const Border(
                                  bottom: BorderSide(color: yellow, width: 5),
                                  right: BorderSide(color: yellow, width: 5),
                                ),
                              ),
                              // 스캔 애니메이션 라인 (Semantics는 필요 없음)
                              AnimatedBuilder(
                                animation: _scanController,
                                builder: (context, _) {
                                  return Positioned(
                                    top: 12 + (_scanController.value * 256),
                                    left: 10,
                                    right: 10,
                                    child: Container(
                                      height: 2.2,
                                      decoration: const BoxDecoration(
                                        color: yellow,
                                        boxShadow: [
                                          BoxShadow(
                                            color: yellow,
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Semantics( // 플래시 버튼 Semantics 추가
                              label: '플래시 켜기/끄기 버튼',
                              button: true,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: InkWell(
                                  onTap: () => _showPlaceholder('FLASH'),
                                  borderRadius: BorderRadius.circular(32),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1C2A41),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.flash_on_rounded, color: yellow),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'FLASH',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFCEC6AD),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Semantics( // 갤러리 버튼 Semantics 추가
                              label: '갤러리에서 QR 코드 이미지 선택 버튼',
                              button: true,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: InkWell(
                                  onTap: () => _showPlaceholder('GALLERY'),
                                  borderRadius: BorderRadius.circular(32),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF1C2A41),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.image_rounded, color: yellow),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'GALLERY',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFCEC6AD),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Theme(
                          data: Theme.of(context).copyWith(
                            elevatedButtonTheme: ElevatedButtonThemeData(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 78),
                                backgroundColor: yellow,
                                foregroundColor: const Color(0xFF726300),
                                textStyle: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                            ),
                          ),
                          child: PrimaryButton(
                            label: '취소',
                            icon: Icons.close_rounded,
                            firstTapGuide:
                                '취소 버튼입니다. 다시 한 번 누르면 이전 화면으로 이동합니다.',
                            onPressed: () {
                              _tts.speak('취소 버튼입니다. 다시 한 번 누르면 이전 화면으로 이동합니다.'); // TTS 안내 추가
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 88,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              decoration: const BoxDecoration(
                color: Color(0xCC041329),
                border: Border(top: BorderSide(color: Color(0x22FFFFFF))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Semantics( // 하단 플래시 버튼 Semantics 추가
                    label: '플래시 켜기/끄기 버튼',
                    button: true,
                    child: IconButton(
                      onPressed: () => _showPlaceholder('FLASH'),
                      icon: const Icon(
                        Icons.flash_on_rounded,
                        color: Color(0xFF7A8497),
                      ),
                    ),
                  ),
                  Semantics( // 하단 QR 스캐너 아이콘 (현재 활성화된 기능) Semantics 추가
                    label: 'QR 코드 스캐너 활성화됨',
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: yellow.withOpacity(0.22), // withValues 대신 withOpacity 사용
                        boxShadow: const [
                          BoxShadow(color: Color(0x66FDE047), blurRadius: 16),
                        ],
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: yellow,
                      ),
                    ),
                  ),
                  Semantics( // 하단 히스토리 버튼 Semantics 추가
                    label: '스캔 기록 보기 버튼',
                    button: true,
                    child: IconButton(
                      onPressed: () => _showPlaceholder('HISTORY'),
                      icon: const Icon(
                        Icons.history_rounded,
                        color: Color(0xFF7A8497),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
