import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.firstTapGuide,
    this.requireDoubleTap = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? firstTapGuide;
  final bool requireDoubleTap;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  final TtsService _ttsService = TtsService();
  Timer? _confirmResetTimer;
  bool _armed = false;

  Future<void> _handleTap() async {
    if (widget.onPressed == null) {
      return;
    }

    if (!widget.requireDoubleTap) {
      widget.onPressed!.call();
      return;
    }

    if (!_armed) {
      setState(() {
        _armed = true;
      });
      HapticFeedback.mediumImpact();

      _confirmResetTimer?.cancel();
      _confirmResetTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _armed = false;
        });
      });

      await _ttsService.speak(
        widget.firstTapGuide ?? '${widget.label}. 다시 한 번 누르면 실행됩니다.',
      );
      return;
    }

    _confirmResetTimer?.cancel();
    setState(() {
      _armed = false;
    });
    await _ttsService.stop();
    widget.onPressed!.call();
  }

  @override
  void dispose() {
    _confirmResetTimer?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.requireDoubleTap ? '한 번 누르면 음성 안내, 두 번 누르면 실행' : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _armed ? Colors.white : Colors.transparent,
            width: _armed ? 3 : 0,
          ),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton.icon(
            onPressed: _handleTap,
            icon: Icon(widget.icon ?? Icons.arrow_forward),
            label: Text(_armed ? '${widget.label} (다시 누르기)' : widget.label),
          ),
        ),
      ),
    );
  }
}
