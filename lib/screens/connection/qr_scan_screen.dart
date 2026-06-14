import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';

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
    _tts.speak('프레임 안에 QR 코드를 맞춰주세요.');
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
    } catch (_) {}

    final name = data?['name'] as String? ?? raw;
    final deviceId = data?['deviceId'] as String? ?? name;
    final type = data?['type'] as String? ?? '';

    _tts.speak('$name 인식됨.');
    _scanController.stop();

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final rs = ResponsiveScale.factor(context);
        return AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * rs)),
          title: Text('기기 인식됨', style: TextStyle(color: const Color(0xFFFFEB00), fontWeight: FontWeight.w800, fontSize: 18 * rs)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_rounded, color: const Color(0xFF00FF88), size: 48 * rs),
              SizedBox(height: ResponsiveScale.v(context, 12)),
              Text('이름: $name', style: TextStyle(color: Colors.white, fontSize: 16 * rs, fontWeight: FontWeight.w700)),
            ],
          ),
          actions: [
            TextButton(onPressed: () { Navigator.pop(ctx, false); setState(() => _detected = false); _scanController.start(); }, child: Text('다시 스캔', style: TextStyle(color: Colors.white54, fontSize: 14 * rs))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFEB00), foregroundColor: Colors.black), child: Text('추가', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14 * rs))),
          ],
        );
      },
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        Navigator.of(context).pop({'name': name, 'deviceId': deviceId, 'type': type});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    const yellow = Color(0xFFFDE047);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(controller: _scanController, onDetect: _onDetect),
          _ScanOverlay(rs: rs),
          SafeArea(
            child: Column(
              children: [
                SizedBox(
                  height: 64 * rs,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16 * rs),
                    child: Row(
                      children: [
                        IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: yellow, size: 24 * rs)),
                        Expanded(child: Text('QR 코드 스캔', textAlign: TextAlign.center, style: TextStyle(color: yellow, fontSize: 18 * rs, fontWeight: FontWeight.w800))),
                        IconButton(onPressed: () { _scanController.toggleTorch(); setState(() => _torchOn = !_torchOn); }, icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: _torchOn ? yellow : Colors.white38, size: 24 * rs)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  margin: EdgeInsets.all(24 * rs), padding: EdgeInsets.all(16 * rs),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12 * rs)),
                  child: Text('허브의 QR 코드를 프레임 안에 맞춰주세요', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 14 * rs, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.rs});
  final double rs;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final frameSize = 260.0 * rs;
    final left = (size.width - frameSize) / 2;
    final top = (size.height - frameSize) / 2 - (40 * rs);
    const yellow = Color(0xFFFDE047);

    return Stack(
      children: [
        Positioned.fill(child: ColoredBox(color: Colors.black.withValues(alpha: 0.5))),
        Positioned(left: left, top: top, width: frameSize, height: frameSize, child: const ColoredBox(color: Colors.transparent)),
        Positioned(left: left, top: top, child: _Corner(borderRadius: const BorderRadius.only(topLeft: Radius.circular(20)), border: const Border(top: BorderSide(color: yellow, width: 5), left: BorderSide(color: yellow, width: 5)))),
        Positioned(right: left, top: top, child: _Corner(borderRadius: const BorderRadius.only(topRight: Radius.circular(20)), border: const Border(top: BorderSide(color: yellow, width: 5), right: BorderSide(color: yellow, width: 5)))),
        Positioned(left: left, bottom: size.height - top - frameSize, child: _Corner(borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20)), border: const Border(bottom: BorderSide(color: yellow, width: 5), left: BorderSide(color: yellow, width: 5)))),
        Positioned(right: left, bottom: size.height - top - frameSize, child: _Corner(borderRadius: const BorderRadius.only(bottomRight: Radius.circular(20)), border: const Border(bottom: BorderSide(color: yellow, width: 5), right: BorderSide(color: yellow, width: 5)))),
      ],
    );
  }
}

class _Corner extends StatelessWidget {
  const _Corner({required this.borderRadius, required this.border});
  final BorderRadius borderRadius; final Border border;
  @override
  Widget build(BuildContext context) => Container(width: 40, height: 40, decoration: BoxDecoration(borderRadius: borderRadius, border: border));
}
