import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../widgets/responsive_scale.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scanController;
  final MobileScannerController _cameraController = MobileScannerController();
  bool _isScanCompleted = false;

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
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanCompleted) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      _isScanCompleted = true;
      final String? code = barcodes.first.rawValue;
      HapticFeedback.heavyImpact();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('기기 확인', style: TextStyle(color: Color(0xFFFFEB00), fontWeight: FontWeight.bold)),
          content: Text('인식된 기기 코드:\n$code', style: const TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('연결하기', style: TextStyle(color: Color(0xFFFFEB00))),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color yellow = Color(0xFFFFEB00);
    final rs = ResponsiveScale.factor(context);
    final screenHeight = MediaQuery.of(context).size.height;
    
    // 프레임 사이즈 계산
    final double frameSize = (240 * rs).clamp(180.0, screenHeight * 0.35);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 카메라 배경
          Positioned.fill(
            child: MobileScanner(
              controller: _cameraController,
              onDetect: _onDetect,
            ),
          ),
          
          // 2. 마스크와 노란색 프레임 (동일한 Center에 배치하여 완벽 일치)
          Positioned.fill(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 어두운 오버레이 마스크
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.7),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Center(
                        child: Container(
                          width: frameSize,
                          height: frameSize,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // 노란색 가이드 테두리 (마스크 구멍과 위치 일치)
                _buildScanFrame(frameSize, yellow, rs),
              ],
            ),
          ),

          // 3. 상/하단 UI 레이어
          SafeArea(
            child: Column(
              children: [
                _buildCustomAppBar(context, yellow),
                const SizedBox(height: 24),
                _buildTopText(rs),
                const Spacer(),
                _buildBottomActions(context, rs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopText(double rs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(
            '프레임 안에 QR 코드를\n맞춰주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24 * rs,
              fontWeight: FontWeight.w900,
              height: 1.2,
              shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '허브의 뒷면이나 상단에 있는\nQR 코드를 자동으로 인식합니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFCCCCCC),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context, double rs) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _scanAction(
                icon: Icons.flash_on_rounded,
                label: '플래시',
                onTap: () => _cameraController.toggleTorch(),
              ),
              const SizedBox(width: 40),
              _scanAction(
                icon: Icons.image_rounded,
                label: '갤러리',
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFF2A2A2A)),
                ),
              ),
              icon: const Icon(Icons.close_rounded),
              label: Text('스캔 취소', style: TextStyle(fontSize: 18 * rs, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context, Color yellow) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.close_rounded, color: yellow, size: 28),
          ),
          Expanded(
            child: Text(
              'QR 코드 스캔',
              textAlign: TextAlign.center,
              style: TextStyle(color: yellow, fontSize: 18, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildScanFrame(double size, Color yellow, double rs) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          _corner(Alignment.topLeft, const BorderRadius.only(topLeft: Radius.circular(24)), Border(top: BorderSide(color: yellow, width: 6), left: BorderSide(color: yellow, width: 6))),
          _corner(Alignment.topRight, const BorderRadius.only(topRight: Radius.circular(24)), Border(top: BorderSide(color: yellow, width: 6), right: BorderSide(color: yellow, width: 6))),
          _corner(Alignment.bottomLeft, const BorderRadius.only(bottomLeft: Radius.circular(24)), Border(bottom: BorderSide(color: yellow, width: 6), left: BorderSide(color: yellow, width: 6))),
          _corner(Alignment.bottomRight, const BorderRadius.only(bottomRight: Radius.circular(24)), Border(bottom: BorderSide(color: yellow, width: 6), right: BorderSide(color: yellow, width: 6))),
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, _) {
              return Positioned(
                top: 15 + (_scanController.value * (size - 30)),
                left: 15,
                right: 15,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: yellow,
                    boxShadow: [BoxShadow(color: yellow.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _corner(Alignment alignment, BorderRadius borderRadius, Border border) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(borderRadius: borderRadius, border: border),
      ),
    );
  }

  Widget _scanAction({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: const Color(0xFF111111).withOpacity(0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: Icon(icon, color: const Color(0xFFFFEB00), size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
