import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/accessibility_settings.dart';
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
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final TtsService _tts = TtsService();
  Timer? _confirmResetTimer;
  bool _armed = false;

  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      _confirmResetTimer = Timer(kDoubleTapArmTimeout, () {
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _confirmResetTimer?.cancel();
      if (mounted && _armed) {
        setState(() {
          _armed = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      // armed 상태를 value/hint로 동적 노출 — TalkBack/VoiceOver가 포커스를
      // 재낭독할 때 "실행 대기 중" 상태를 명확히 전달한다.
      value: _armed ? '실행 대기 중' : null,
      hint: _armed
          ? '한 번 더 활성화하면 실행됩니다'
          : (widget.requireDoubleTap ? '한 번 누르면 음성 안내, 두 번 누르면 실행' : null),
      liveRegion: _armed,
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
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleTap,
                  borderRadius: BorderRadius.circular(16),
                  // 200% 텍스트 확대 시에도 레이아웃이 깨지지 않도록:
                  // - ConstrainedBox로 최소 64px 보장, 텍스트가 크면 확장 허용
                  // - Flexible로 긴 라벨이 Row를 넘치지 않고 줄바꿈하도록
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 80),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.icon ?? Icons.arrow_forward,
                            size: 32,
                            color: Colors.black,
                          ),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              _armed
                                  ? '${widget.label} (다시 누르기)'
                                  : widget.label,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
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
        ),
      ),
    );
  }
}
