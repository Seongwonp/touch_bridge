import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';
import '../../services/accessibility_experiment_service.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../safety/emergency_stop_screen.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key, this.deviceName = '스마트 기기'});

  final String deviceName;

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  final TtsService _tts = TtsService();

  Timer? _actionResetTimer;
  String? _armedActionId;

  int _secondsLeft = 150;
  bool _running = false;
  String _draft = '0230';

  @override
  void initState() {
    super.initState();
    _speak('${widget.deviceName} 제어 화면입니다. 숫자 버튼을 입력하여 시간을 설정하세요.');
  }

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  Future<void> _armAndRun({
    required String id,
    required String guide,
    required VoidCallback onConfirmed,
  }) async {
    if (_armedActionId != id) {
      setState(() {
        _armedActionId = id;
      });
      HapticFeedback.mediumImpact();

      _actionResetTimer?.cancel();
      _actionResetTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) return;
        setState(() {
          _armedActionId = null;
        });
      });

      await _speak(guide);
      return;
    }

    _actionResetTimer?.cancel();
    await _tts.stop();
    setState(() {
      _armedActionId = null;
    });
    HapticFeedback.selectionClick();
    onConfirmed();
  }

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _updateFromDraft() {
    final min = int.parse(_draft.substring(0, 2));
    final sec = int.parse(_draft.substring(2, 4)).clamp(0, 59);
    setState(() {
      _secondsLeft = min * 60 + sec;
    });
  }

  void _appendDigit(int value) {
    if (_running) return;
    setState(() {
      _draft = (_draft.substring(1) + value.toString());
    });
    _updateFromDraft();
    _speak('$value 입력됨');
  }

  void _backspaceDigit() {
    if (_running) return;
    setState(() {
      _draft = '0${_draft.substring(0, 3)}';
    });
    _updateFromDraft();
    _speak('마지막 숫자 지움');
  }

  void _cancelTimer() {
    setState(() {
      _running = false;
      _draft = '0000';
      _secondsLeft = 0;
    });
    _speak('초기화되었습니다.');
  }

  void _toggleStart() {
    if (_secondsLeft <= 0) {
      setState(() {
        _draft = '0030';
        _secondsLeft = 30;
      });
      _speak('30초로 시작합니다.');
    } else {
      _speak('${_formatMMSS(_secondsLeft)} 시작합니다.');
    }
    
    AccessibilityExperimentService.instance.recordTaskStarted(TaskMode.manual);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyStopScreen(initialSeconds: _secondsLeft),
      ),
    );
  }

  Widget _numberKey(int number, double rs) {
    final id = 'num_$number';
    final isArmed = _armedActionId == id;

    return Semantics(
      label: '$number 숫자 버튼',
      button: true,
      child: _ActionKey(
        borderColor: const Color(0xFF2A2A2A),
        armed: isArmed,
        onTap: () {
          _armAndRun(
            id: id,
            guide: '$number 버튼',
            onConfirmed: () => _appendDigit(number),
          );
        },
        child: Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28 * rs,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _cancelKey(double rs) {
    final isArmed = _armedActionId == 'cancel';
    return Semantics(
      label: '취소 버튼',
      button: true,
      child: _ActionKey(
        color: const Color(0xFF1A0A0A),
        borderColor: const Color(0xFF3A1A1A),
        armed: isArmed,
        onTap: () {
          _armAndRun(
            id: 'cancel',
            guide: '취소',
            onConfirmed: _cancelTimer,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cancel_rounded, color: const Color(0xFFFF4444), size: 24 * rs),
            SizedBox(height: 4 * rs),
            Text(
              '취소',
              style: TextStyle(
                color: const Color(0xFFFF4444),
                fontSize: 12 * rs,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backspaceKey(double rs) {
    final isArmed = _armedActionId == 'backspace';
    return Semantics(
      label: '지우기 버튼',
      button: true,
      child: _ActionKey(
        color: const Color(0xFF1A1A1A),
        borderColor: const Color(0xFF2A2A2A),
        armed: isArmed,
        onTap: () {
          _armAndRun(
            id: 'backspace',
            guide: '지우기',
            onConfirmed: _backspaceDigit,
          );
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backspace_rounded, color: const Color(0xFF888888), size: 22 * rs),
            SizedBox(height: 4 * rs),
            Text(
              '지우기',
              style: TextStyle(
                color: const Color(0xFF888888),
                fontSize: 12 * rs,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _actionResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: TopAppBar(title: widget.deviceName, showBack: true),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20 * rs, vertical: 12 * rs),
          child: Column(
            children: [
              Text(
                '남은 시간',
                style: TextStyle(
                  color: const Color(0xFF888888),
                  fontSize: 13 * rs,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: ResponsiveScale.v(context, 8)),
              Semantics(
                label: '현재 시간 ${_formatMMSS(_secondsLeft)}',
                child: Text(
                  _formatMMSS(_secondsLeft),
                  style: TextStyle(
                    color: const Color(0xFFFFEB00),
                    fontSize: 72 * rs,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),
              SizedBox(height: ResponsiveScale.v(context, 16)),
              Expanded(
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 12 * rs,
                  mainAxisSpacing: 12 * rs,
                  childAspectRatio: 1.1,
                  children: [
                    _numberKey(1, rs), _numberKey(2, rs), _numberKey(3, rs),
                    _numberKey(4, rs), _numberKey(5, rs), _numberKey(6, rs),
                    _numberKey(7, rs), _numberKey(8, rs), _numberKey(9, rs),
                    _cancelKey(rs), _numberKey(0, rs), _backspaceKey(rs),
                  ],
                ),
              ),
              SizedBox(height: ResponsiveScale.v(context, 16)),
              SizedBox(
                width: double.infinity,
                height: 64 * rs,
                child: Semantics(
                  label: '시작 버튼',
                  button: true,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _armAndRun(
                        id: 'start',
                        guide: '시작',
                        onConfirmed: _toggleStart,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEB00),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16 * rs),
                        side: _armedActionId == 'start' ? const BorderSide(color: Colors.white, width: 3) : BorderSide.none,
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.play_arrow_rounded, size: 28 * rs),
                    label: Text(
                      '조리 시작',
                      style: TextStyle(fontSize: 20 * rs, fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.child,
    required this.onTap,
    this.color = const Color(0xFF111111),
    this.borderColor = const Color(0xFF2A2A2A),
    this.armed = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final Color borderColor;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16 * rs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16 * rs),
          border: Border.all(
            color: armed ? Colors.white : borderColor,
            width: armed ? 3 : 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}
