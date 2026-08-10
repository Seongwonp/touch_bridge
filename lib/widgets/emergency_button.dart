import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/tts_service.dart';

class EmergencyButton extends StatefulWidget {
  const EmergencyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.firstTapGuide,
  });

  final String label;
  final VoidCallback onPressed;
  final String? firstTapGuide;

  @override
  State<EmergencyButton> createState() => _EmergencyButtonState();
}

class _EmergencyButtonState extends State<EmergencyButton> {
  // 비상 버튼은 사용자 속도/음량 설정, 스크린리더 억제 정책, 안내 큐를
  // 공유해야 하므로 별도 FlutterTts가 아니라 공용 TtsService를 사용한다.
  // (이전에는 자체 FlutterTts 인스턴스를 써서 중재자를 우회했다.)
  final TtsService _tts = TtsService();
  Timer? _confirmResetTimer;
  bool _armed = false;

  Future<void> _handleTap() async {
    if (!_armed) {
      setState(() {
        _armed = true;
      });
      HapticFeedback.heavyImpact();

      _confirmResetTimer?.cancel();
      _confirmResetTimer = Timer(const Duration(seconds: 15), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _armed = false;
        });
      });

      await _tts.speak(
        widget.firstTapGuide ?? '${widget.label}. 안전 확인을 위해 다시 한 번 누르면 실행됩니다.',
        source: 'EmergencyButton',
        priority: TtsPriority.emergency,
        interrupt: true,
      );
      return;
    }

    _confirmResetTimer?.cancel();
    setState(() {
      _armed = false;
    });
    widget.onPressed();
  }

  @override
  void dispose() {
    _confirmResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      hint: '한 번 누르면 음성 안내, 두 번 누르면 실행',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _armed ? Colors.white : Colors.transparent,
            width: _armed ? 3 : 0,
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 84,
          child: FilledButton.icon(
            onPressed: _handleTap,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
              textStyle: Theme.of(context).textTheme.titleLarge,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.warning_amber_rounded, size: 28),
            label: Text(_armed ? '${widget.label} (다시 누르기)' : widget.label),
          ),
        ),
      ),
    );
  }
}
