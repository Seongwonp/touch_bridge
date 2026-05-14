import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/tts_service.dart';

// QR 코드 예상 형식:
// {"deviceId": "esp32_001", "name": "전자레인지", "type": "microwave"}
// name만 있어도 허용 (deviceId, type은 선택)

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final TtsService _tts = TtsService();
  final MobileScannerController _scanController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _detected = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _tts.speak('QR 코드 스캔 화면입니다. 프레임 안에 QR 코드를 맞춰주세요.');
  }

  @override
  void dispose() {
    _scanController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final raw = barcode.rawValue!;
    _detected = true;
    HapticFeedback.heavyImpact();

    Map<String, dynamic>? data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // JSON 아니면 raw 값을 기기명으로 사용
    }

    final name = data?['name'] as String? ?? raw;
    final deviceId = data?['deviceId'] as String? ?? name;

    _tts.speak('$name 기기를 인식했습니다. 추가하려면 확인을 누르세요.');
    _scanController.stop();

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('기기 인식됨', style: TextStyle(color: Color(0xFFFFEB00), fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF88), size: 48),
            const SizedBox(height: 12),
            Text('기기 이름: $name', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            if (deviceId != name) ...[
              const SizedBox(height: 4),
              Text('ID: $deviceId', style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
              setState(() => _detected = false);
              _scanController.start();
              _tts.speak('취소했습니다. 다시 스캔하세요.');
            },
            child: const Text('다시 스캔', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFEB00),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('추가', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.of(context).pop({'name': name, 'deviceId': deviceId});
        _tts.speak('$name 기기가 추가되었습니다.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFDE047);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 카메라 뷰
          MobileScanner(
            controller: _scanController,
            onDetect: _onDetect,
          ),
          // 어두운 오버레이 + 스캔 프레임
          _ScanOverlay(),
          SafeArea(
            child: Column(
              children: [
                // 상단 바
                SizedBox(
                  height: 64,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Semantics(
                          label: '닫기 버튼',
                          button: true,
                          child: IconButton(
                            onPressed: () {
                              _tts.speak('이전 화면으로 돌아갑니다.');
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.close, color: yellow),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'QR 코드 스캔',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: yellow, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Semantics(
                          label: _torchOn ? '플래시 끄기' : '플래시 켜기',
                          button: true,
                          child: IconButton(
                            onPressed: () {
                              _scanController.toggleTorch();
                              setState(() => _torchOn = !_torchOn);
                            },
                            icon: Icon(
                              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: _torchOn ? yellow : const Color(0xFF7A8497),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                // 안내 텍스트
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '허브의 QR 코드를 프레임 안에 맞춰주세요\n자동으로 인식됩니다',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const yellow = Color(0xFFFDE047);
    final size = MediaQuery.of(context).size;
    const frameSize = 260.0;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2 - 40;

    return Stack(
      children: [
        // 상하좌우 어두운 영역
        Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.5))),
        // 스캔 프레임 구멍
        Positioned(
          left: left, top: top, width: frameSize, height: frameSize,
          child: const ColoredBox(color: Colors.transparent),
        ),
        // 프레임 코너
        Positioned(
          left: left, top: top,
          child: _Corner(alignment: Alignment.topLeft,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)),
            border: const Border(top: BorderSide(color: yellow, width: 5), left: BorderSide(color: yellow, width: 5))),
        ),
        Positioned(
          right: left, top: top,
          child: _Corner(alignment: Alignment.topRight,
            borderRadius: const BorderRadius.only(topRight: Radius.circular(20)),
            border: const Border(top: BorderSide(color: yellow, width: 5), right: BorderSide(color: yellow, width: 5))),
        ),
        Positioned(
          left: left, bottom: size.height - top - frameSize,
          child: _Corner(alignment: Alignment.bottomLeft,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)),
            border: const Border(bottom: BorderSide(color: yellow, width: 5), left: BorderSide(color: yellow, width: 5))),
        ),
        Positioned(
          right: left, bottom: size.height - top - frameSize,
          child: _Corner(alignment: Alignment.bottomRight,
            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)),
            border: const Border(bottom: BorderSide(color: yellow, width: 5), right: BorderSide(color: yellow, width: 5))),
        ),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.alignment, required this.borderRadius, required this.border});
  final Alignment alignment;
  final BorderRadius borderRadius;
  final Border border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(borderRadius: borderRadius, border: border),
    );
  }
}
