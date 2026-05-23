import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../widgets/responsive_scale.dart';
import '../safety/emergency_stop_screen.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  final FlutterTts _tts = FlutterTts();

  Timer? _actionResetTimer;
  String? _armedActionId;

  Timer? _countdownTimer;
  int _secondsLeft = 150;
  bool _running = false;
  String _draft = '0230';

  @override
  void initState() {
    super.initState();
    _speak('기기 제어 화면입니다. 타이머를 설정하고 시작하세요.');
  }

  Future<void> _speak(String message) async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.stop();
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
  }

  void _backspaceDigit() {
    if (_running) return;
    setState(() {
      _draft = '0${_draft.substring(0, 3)}';
    });
    _updateFromDraft();
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _running = false;
      _draft = '0230';
      _secondsLeft = 150;
    });
  }

  void _toggleStart() {
    if (_secondsLeft <= 0) {
      setState(() {
        _draft = '0030';
        _secondsLeft = 30;
      });
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyStopScreen(initialSeconds: _secondsLeft),
      ),
    );
  }

  void _stopTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _running = false;
      _draft = _formatMMSS(_secondsLeft).replaceAll(':', '');
    });
  }

  Widget _numberKey(int number) {
    final id = 'num_$number';
    final isArmed = _armedActionId == id;

    return _ActionKey(
      borderColor: const Color(0xFF2A2A2A),
      armed: isArmed,
      child: Text(
        '$number',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontWeight: FontWeight.w800,
        ),
      ),
      onTap: () {
        _armAndRun(
          id: id,
          guide: '$number 버튼입니다. 다시 누르면 입력됩니다.',
          onConfirmed: () => _appendDigit(number),
        );
      },
    );
  }

  Widget _cancelKey() {
    final isArmed = _armedActionId == 'cancel';
    return _ActionKey(
      color: const Color(0xFF1A0A0A),
      borderColor: const Color(0xFF3A1A1A),
      armed: isArmed,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel_rounded, color: Color(0xFFFF4444), size: 28),
          SizedBox(height: 4),
          Text(
            '취소',
            style: TextStyle(
              color: Color(0xFFFF4444),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      onTap: () {
        _armAndRun(
          id: 'cancel',
          guide: '취소 버튼입니다. 다시 누르면 타이머가 초기화됩니다.',
          onConfirmed: _cancelTimer,
        );
      },
    );
  }

  Widget _backspaceKey() {
    final isArmed = _armedActionId == 'backspace';
    return _ActionKey(
      color: const Color(0xFF1A1A1A),
      borderColor: const Color(0xFF2A2A2A),
      armed: isArmed,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.backspace_rounded, color: Color(0xFF888888), size: 26),
          SizedBox(height: 4),
          Text(
            '지우기',
            style: TextStyle(
              color: Color(0xFF888888),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      onTap: () {
        _armAndRun(
          id: 'backspace',
          guide: '지우기 버튼입니다. 다시 누르면 마지막 숫자를 지웁니다.',
          onConfirmed: _backspaceDigit,
        );
      },
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _actionResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  double _sensitivity = 70;
  double _speed = 50;

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('기기 정밀 설정', style: TextStyle(color: Color(0xFFFFEB00), fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('모터 감도', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('${_sensitivity.toInt()}%', style: const TextStyle(color: Color(0xFFFFEB00))),
                ],
              ),
              Slider(
                value: _sensitivity,
                min: 0,
                max: 100,
                activeColor: const Color(0xFFFFEB00),
                inactiveColor: const Color(0xFF2A2A2A),
                onChanged: (val) {
                  setModalState(() => _sensitivity = val);
                  setState(() => _sensitivity = val);
                },
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('동작 속도', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Text('${_speed.toInt()}%', style: const TextStyle(color: Color(0xFFFFEB00))),
                ],
              ),
              Slider(
                value: _speed,
                min: 10,
                max: 100,
                activeColor: const Color(0xFFFFEB00),
                inactiveColor: const Color(0xFF2A2A2A),
                onChanged: (val) {
                  setModalState(() => _speed = val);
                  setState(() => _speed = val);
                },
              ),
              
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEB00),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('설정 저장 및 닫기', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Container(
              height: ResponsiveScale.v(context, 64),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveScale.v(context, 8),
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFFEB00)),
                    tooltip: '뒤로 가기',
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Touch Bridge',
                    style: TextStyle(
                      color: Color(0xFFFFEB00),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _showSettings,
                    icon: const Icon(Icons.tune_rounded, color: Color(0xFFFFEB00)),
                    tooltip: '설정',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveScale.v(context, 16),
                  ResponsiveScale.v(context, 12),
                  ResponsiveScale.v(context, 16),
                  ResponsiveScale.v(context, 4),
                ),
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
                    SizedBox(height: ResponsiveScale.v(context, 6)),
                    Text(
                      _formatMMSS(_secondsLeft),
                      style: TextStyle(
                        color: const Color(0xFFFFEB00),
                        fontSize: 72 * rs,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 8)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00FF88),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            '스마트 전자레인지 연결됨',
                            style: TextStyle(
                              color: Color(0xFF00FF88),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 14)),
                    Expanded(
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1,
                        children: [
                          _numberKey(1),
                          _numberKey(2),
                          _numberKey(3),
                          _numberKey(4),
                          _numberKey(5),
                          _numberKey(6),
                          _numberKey(7),
                          _numberKey(8),
                          _numberKey(9),
                          _cancelKey(),
                          _numberKey(0),
                          _backspaceKey(),
                        ],
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 8)),
                    SizedBox(
                      width: double.infinity,
                      height: ResponsiveScale.v(context, 70),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _armAndRun(
                            id: 'start_voice',
                            guide: '시작 버튼입니다. 다시 누르면 타이머가 시작됩니다.',
                            onConfirmed: _toggleStart,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEB00),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: _armedActionId == 'start_voice'
                                  ? Colors.white
                                  : Colors.transparent,
                              width: _armedActionId == 'start_voice' ? 2.5 : 0,
                            ),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text(
                          _running ? '실행 중...' : '시작',
                          style: TextStyle(
                            fontSize: 22 * rs,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 8)),
                    TextButton.icon(
                      onPressed: () {
                        _armAndRun(
                          id: 'stop_timer',
                          guide: '타이머 정지 버튼입니다. 다시 누르면 정지합니다.',
                          onConfirmed: _stopTimer,
                        );
                      },
                      icon: const Icon(Icons.stop_circle, size: 22),
                      label: const Text(
                        '타이머 정지',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF888888),
                        side: BorderSide(
                          color: _armedActionId == 'stop_timer'
                              ? Colors.white
                              : Colors.transparent,
                          width: _armedActionId == 'stop_timer' ? 2 : 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: armed ? Colors.white : borderColor,
            width: armed ? 2.5 : 1,
          ),
        ),
        child: child,
      ),
    );
  }
}
