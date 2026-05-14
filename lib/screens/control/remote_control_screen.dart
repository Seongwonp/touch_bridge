import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';

import '../../widgets/responsive_scale.dart';
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

  Timer? _countdownTimer;
  int _secondsLeft = 150;
  bool _running = false;
  String _draft = '0230';

  @override
  void initState() {
    super.initState();
    _speak('${widget.deviceName} 제어 화면입니다. 숫자 버튼은 한 번 누르면 선택되고 한 번 더 누르면 입력됩니다. 이전 화면으로 돌아가려면 화면을 왼쪽에서 오른쪽으로 쓸어주세요.');
  }

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 450 && Navigator.of(context).canPop()) {
      _tts.speak('이전 화면으로 돌아갑니다.');
      Navigator.of(context).pop();
    }
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
    _speak('$value 입력됨. 현재 시간 ${_formatMMSS(_secondsLeft)}'); // 입력 숫자 TTS 피드백
  }

  void _backspaceDigit() {
    if (_running) return;
    setState(() {
      _draft = '0${_draft.substring(0, 3)}';
    });
    _updateFromDraft();
    _speak('마지막 숫자 지움. 현재 시간 ${_formatMMSS(_secondsLeft)}'); // 지우기 TTS 피드백
  }

  void _cancelTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _running = false;
      _draft = '0230';
      _secondsLeft = 150;
    });
    _speak('타이머가 초기화되었습니다.'); // 취소 TTS 피드백
  }

  void _toggleStart() {
    if (_secondsLeft <= 0) {
      setState(() {
        _draft = '0030';
        _secondsLeft = 30;
      });
      _speak('시간이 설정되지 않아 기본 30초로 설정되었습니다.'); // 시간 미설정 시 TTS 피드백
    }

    _speak('${_formatMMSS(_secondsLeft)} 타이머를 시작합니다.'); // 시작 전 TTS 피드백
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
    _speak('타이머가 정지되었습니다.'); // 정지 TTS 피드백
  }

  Widget _numberKey(int number) {
    final id = 'num_$number';
    final isArmed = _armedActionId == id;

    return Semantics( // 숫자 키 Semantics 추가
      label: '$number 숫자 버튼. ${isArmed ? '활성화됨. 다시 누르면 입력됩니다.' : ''}',
      button: true,
      child: _ActionKey(
        borderColor: const Color(0xFF2A2A2A),
        armed: isArmed,
        onTap: () {
          _armAndRun(
            id: id,
            guide: '$number 버튼입니다. 다시 누르면 입력됩니다.',
            onConfirmed: () => _appendDigit(number),
          );
        },
        child: Text(
          '$number',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _cancelKey() {
    final isArmed = _armedActionId == 'cancel';
    return Semantics( // 취소 키 Semantics 추가
      label: '취소 버튼. ${isArmed ? '활성화됨. 다시 누르면 타이머가 초기화됩니다.' : ''}',
      button: true,
      child: _ActionKey(
        color: const Color(0xFF1A0A0A),
        borderColor: const Color(0xFF3A1A1A),
        armed: isArmed,
        onTap: () {
          _armAndRun(
            id: 'cancel',
            guide: '취소 버튼입니다. 다시 누르면 타이머가 초기화됩니다.',
            onConfirmed: _cancelTimer,
          );
        },
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
      ),
    );
  }

  Widget _backspaceKey() {
    final isArmed = _armedActionId == 'backspace';
    return Semantics( // 지우기 키 Semantics 추가
      label: '지우기 버튼. ${isArmed ? '활성화됨. 다시 누르면 마지막 숫자를 지웁니다.' : ''}',
      button: true,
      child: _ActionKey(
        color: const Color(0xFF1A1A1A),
        borderColor: const Color(0xFF2A2A2A),
        armed: isArmed,
        onTap: () {
          _armAndRun(
            id: 'backspace',
            guide: '지우기 버튼입니다. 다시 누르면 마지막 숫자를 지웁니다.',
            onConfirmed: _backspaceDigit,
          );
        },
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
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _actionResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: SafeArea(
          child: Column(
          children: [
            // 상단 바 - 뒤로가기 버튼 포함
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
                  Semantics( // 뒤로가기 버튼 Semantics 추가
                    label: '뒤로 가기 버튼',
                    button: true,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFFFFEB00)),
                      tooltip: '뒤로 가기', // tooltip은 Semantics label과 중복될 수 있으므로 제거 고려
                    ),
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
                    const Text( // 남은 시간 텍스트는 Semantics로 감싸지 않고, 아래 Text 위젯에 label 추가
                      '남은 시간',
                      style: TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13, // rs 제거
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 6)),
                    Semantics( // 남은 시간 표시 Semantics 추가
                      label: '남은 시간 ${_formatMMSS(_secondsLeft).replaceAll(':', '분 ')}초',
                      liveRegion: true, // 시간이 변경될 때마다 자동으로 읽도록 설정
                      child: Text(
                        _formatMMSS(_secondsLeft),
                        style: TextStyle(
                          color: const Color(0xFFFFEB00),
                          fontSize: 72 * rs,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 8)),
                    Semantics(
                      label: '${widget.deviceName} 연결됨',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
                              decoration: const BoxDecoration(color: Color(0xFF00FF88), shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              '${widget.deviceName} 연결됨',
                              style: const TextStyle(color: Color(0xFF00FF88), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
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
                      child: Semantics( // 시작 버튼 Semantics 추가
                        label: _running ? '타이머 실행 중' : '타이머 시작 버튼. ${(_armedActionId == 'start_voice') ? '활성화됨. 다시 누르면 타이머가 시작됩니다.' : ''}',
                        button: true,
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
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 8)),
                    Semantics( // 타이머 정지 버튼 Semantics 추가
                      label: '타이머 정지 버튼. ${(_armedActionId == 'stop_timer') ? '활성화됨. 다시 누르면 정지합니다.' : ''}',
                      button: true,
                      child: TextButton.icon(
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
                    ),
                  ],
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
