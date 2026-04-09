import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

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
  final FlutterTts _tts = FlutterTts();
  Timer? _confirmResetTimer;
  bool _armed = false;

  Future<void> _handleTap() async {
    if (!_armed) {
      setState(() {
        _armed = true;
      });
      HapticFeedback.heavyImpact();

      _confirmResetTimer?.cancel();
      _confirmResetTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _armed = false;
        });
      });

      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.stop();
      await _tts.speak(
        widget.firstTapGuide ?? '${widget.label}. 안전 확인을 위해 다시 한 번 누르면 실행됩니다.',
      );
      return;
    }

    _confirmResetTimer?.cancel();
    setState(() {
      _armed = false;
    });
    await _tts.stop();
    widget.onPressed();
  }

  @override
  void dispose() {
    _confirmResetTimer?.cancel();
    _tts.stop();
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
