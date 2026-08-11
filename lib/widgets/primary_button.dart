import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/tts_service.dart';
import '../theme/app_colors.dart';

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

class _PrimaryButtonState extends State<PrimaryButton>
    with SingleTickerProviderStateMixin {
  final TtsService _tts = TtsService();
  Timer? _confirmResetTimer;
  bool _armed = false;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _scaleController, curve: Curves.easeOut));
  }

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
      _confirmResetTimer = Timer(const Duration(seconds: 15), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _armed = false;
        });
      });

      await _tts.speak(
        widget.firstTapGuide ?? '${widget.label}. 다시 한 번 누르면 실행됩니다.',
        source: 'PrimaryButton',
      );
      return;
    }

    _confirmResetTimer?.cancel();
    setState(() {
      _armed = false;
    });
    widget.onPressed!.call();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  void dispose() {
    _confirmResetTimer?.cancel();
    // stop()은 전역 큐를 지워 다음 화면 안내까지 날린다.
    // 이 버튼 자신의 대기 항목만 취소한다.
    _tts.cancelSource('PrimaryButton');
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      hint: widget.requireDoubleTap ? '한 번 누르면 음성 안내, 두 번 누르면 실행' : null,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: AppColors.primaryGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: _armed ? Colors.white : Colors.transparent,
                width: _armed ? 3 : 0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowPrimary.withValues(
                    alpha: _armed ? 0.15 : 0.6,
                  ),
                  blurRadius: _armed ? 4 : 14,
                  spreadRadius: _armed ? 0 : 1,
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.icon ?? Icons.arrow_forward,
                        size: 28,
                        color: Colors.black,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _armed ? '${widget.label} (다시 누르기)' : widget.label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
