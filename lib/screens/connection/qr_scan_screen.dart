import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/primary_button.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
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
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close, color: yellow),
                          tooltip: '닫기',
                        ),
                        const Expanded(
                          child: Text(
                            'Scan QR Code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: yellow,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
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
                        const Text(
                          '프레임 안에 QR 코드를 맞춰주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 31,
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          '노란 가이드 프레임 안에 코드를 맞추면 자동으로 인식해요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFCEC6AD),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: 280,
                          height: 280,
                          child: Stack(
                            children: [
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
                            for (final item in const [
                              (Icons.flash_on_rounded, 'FLASH'),
                              (Icons.image_rounded, 'GALLERY'),
                            ])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                child: InkWell(
                                  onTap: () => _showPlaceholder(item.$2),
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
                                        child: Icon(item.$1, color: yellow),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item.$2,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFCEC6AD),
                                        ),
                                      ),
                                    ],
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
                            onPressed: () => Navigator.of(context).pop(),
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
                  IconButton(
                    onPressed: () => _showPlaceholder('FLASH'),
                    icon: const Icon(
                      Icons.flash_on_rounded,
                      color: Color(0xFF7A8497),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: yellow.withValues(alpha: 0.22),
                      boxShadow: const [
                        BoxShadow(color: Color(0x66FDE047), blurRadius: 16),
                      ],
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: yellow,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showPlaceholder('HISTORY'),
                    icon: const Icon(
                      Icons.history_rounded,
                      color: Color(0xFF7A8497),
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
