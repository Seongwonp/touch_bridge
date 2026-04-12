import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../home/home_screen.dart';
import '../safety/emergency_stop_screen.dart';
import '../settings/settings_screen.dart';
import '../voice/voice_listening_screen.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  final TtsService _ttsService = TtsService();
  static const String _activeDeviceName = 'Kitchen Hub';

  Timer? _navResetTimer;
  int? _armedNavIndex;

  Timer? _actionResetTimer;
  String? _armedActionId;

  Timer? _countdownTimer;
  int _secondsLeft = 150;
  bool _running = false;
  String _draft = '0230';

  Future<void> _speak(String message) async {
    await _ttsService.speak(message);
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
        if (!mounted) {
          return;
        }
        setState(() {
          _armedActionId = null;
        });
      });

      await _speak(guide);
      return;
    }

    _actionResetTimer?.cancel();
    await _ttsService.stop();
    setState(() {
      _armedActionId = null;
    });
    HapticFeedback.selectionClick();
    onConfirmed();
  }

  Future<void> _handleBottomTap(int index) async {
    const labels = ['홈', '기기', '음성', '설정'];

    if (_armedNavIndex != index) {
      setState(() {
        _armedNavIndex = index;
      });
      HapticFeedback.mediumImpact();

      _navResetTimer?.cancel();
      _navResetTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted) {
          return;
        }
        setState(() {
          _armedNavIndex = null;
        });
      });

      await _speak('${labels[index]} 탭입니다. 다시 한 번 누르면 이동합니다.');
      return;
    }

    _navResetTimer?.cancel();
    setState(() {
      _armedNavIndex = null;
    });
    await _ttsService.stop();

    if (!mounted) {
      return;
    }

    switch (index) {
      case 0:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
        );
        break;
      case 1:
        return;
      case 2:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const VoiceListeningScreen()),
        );
        break;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        break;
    }
  }

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatKoreanDuration(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    if (minutes > 0 && seconds > 0) {
      return '$minutes분 $seconds초';
    }
    if (minutes > 0) {
      return '$minutes분';
    }
    return '$seconds초';
  }

  void _updateFromDraft() {
    final min = int.parse(_draft.substring(0, 2));
    final sec = int.parse(_draft.substring(2, 4)).clamp(0, 59);
    setState(() {
      _secondsLeft = min * 60 + sec;
    });
  }

  void _appendDigit(int value) {
    if (_running) {
      return;
    }
    setState(() {
      _draft = (_draft.substring(1) + value.toString());
    });
    _updateFromDraft();
  }

  void _backspaceDigit() {
    if (_running) {
      return;
    }
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
    if (!mounted) {
      return;
    }

    if (_secondsLeft <= 0) {
      setState(() {
        _draft = '0030';
        _secondsLeft = 30;
      });
    }

    final int startSeconds = _secondsLeft;
    final String runningLabel =
        '$_activeDeviceName ${_formatKoreanDuration(startSeconds)} 작동 중';
    _speak(
      '$_activeDeviceName가 ${_formatKoreanDuration(startSeconds)} 작동됩니다. 긴급 중단 화면으로 이동합니다.',
    );

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmergencyStopScreen(
          initialSeconds: startSeconds,
          runningLabel: runningLabel,
        ),
      ),
    );
  }

  Widget _numberKey(int number, double rs) {
    final id = 'num_$number';
    final isArmed = _armedActionId == id;
    final double numberFontSize = (26 * rs).clamp(20, 30).toDouble();

    return _ActionKey(
      borderColor: const Color(0x1A97917A),
      armed: isArmed,
      child: Text(
        '$number',
        style: TextStyle(
          color: Color(0xFFD6E3FF),
          fontSize: numberFontSize,
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

  Widget _cancelKey(double rs) {
    final isArmed = _armedActionId == 'cancel';
    final double iconSize = (24 * rs).clamp(20, 28).toDouble();
    final double labelSize = (11 * rs).clamp(10, 13).toDouble();
    return _ActionKey(
      color: const Color(0x3393000A),
      borderColor: const Color(0x22FFB4AB),
      armed: isArmed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cancel, color: const Color(0xFFFFB4AB), size: iconSize),
          const SizedBox(height: 4),
          Text(
            '취소',
            style: TextStyle(
              color: Color(0xFFFFB4AB),
              fontSize: labelSize,
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

  Widget _backspaceKey(double rs) {
    final isArmed = _armedActionId == 'backspace';
    final double iconSize = (22 * rs).clamp(18, 26).toDouble();
    final double labelSize = (11 * rs).clamp(10, 13).toDouble();
    return _ActionKey(
      color: const Color(0xFF27354C),
      borderColor: const Color(0x1A97917A),
      armed: isArmed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.backspace, color: const Color(0xFFD6E3FF), size: iconSize),
          const SizedBox(height: 4),
          Text(
            '지우기',
            style: TextStyle(
              color: Color(0xFFD6E3FF),
              fontSize: labelSize,
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

  Widget _bottomItem({
    required int index,
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final isArmed = _armedNavIndex == index;

    return InkWell(
      onTap: () => _handleBottomTap(index),
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        width: 80,
        height: 60,
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDE047) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isArmed ? Colors.white : Colors.transparent,
            width: isArmed ? 2.5 : 0,
          ),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x40FDE047),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF726300) : const Color(0xFF94A3B8),
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: active
                    ? const Color(0xFF726300)
                    : const Color(0xFF94A3B8),
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
    _navResetTimer?.cancel();
    _actionResetTimer?.cancel();
    _ttsService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: ResponsiveScale.v(context, 64),
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveScale.v(context, 16),
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x33FDE047))),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x1AFDE047),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const HomeScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.grid_view, color: Color(0xFFFDE047)),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Touch Bridge',
                    style: TextStyle(
                      color: Color(0xFFFDE047),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SettingsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.settings, color: Color(0xFFFDE047)),
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
                        color: Color(0xFFCEC6AD),
                        fontSize: 13 * rs,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 6)),
                    Text(
                      _formatMMSS(_secondsLeft),
                      style: TextStyle(
                        color: Color(0xFFFDE047),
                        fontSize: 72 * rs,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 6)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2A41),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Kitchen Hub Active',
                        style: TextStyle(
                          color: Color(0xFF38DEBB),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 14)),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double maxGridWidth = constraints.maxWidth > 520
                              ? 420
                              : constraints.maxWidth;
                          final double spacing = constraints.maxWidth > 420
                              ? 10
                              : 8;
                          final double ratio = constraints.maxWidth > 420
                              ? 1.15
                              : 1.0;

                          return Center(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: maxGridWidth,
                              ),
                              child: GridView.count(
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 3,
                                crossAxisSpacing: spacing,
                                mainAxisSpacing: spacing,
                                childAspectRatio: ratio,
                                children: [
                                  _numberKey(1, rs),
                                  _numberKey(2, rs),
                                  _numberKey(3, rs),
                                  _numberKey(4, rs),
                                  _numberKey(5, rs),
                                  _numberKey(6, rs),
                                  _numberKey(7, rs),
                                  _numberKey(8, rs),
                                  _numberKey(9, rs),
                                  _cancelKey(rs),
                                  _numberKey(0, rs),
                                  _backspaceKey(rs),
                                ],
                              ),
                            ),
                          );
                        },
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
                            guide:
                                '시작 음성 제어 버튼입니다. 시작하려면 한 번 더 탭하세요. 음성 인식으로 가려면 아래 VOICE 탭을 두 번 탭하세요.',
                            onConfirmed: _toggleStart,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFDE047),
                          foregroundColor: const Color(0xFF726300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: _armedActionId == 'start_voice'
                                  ? Colors.white
                                  : Colors.transparent,
                              width: _armedActionId == 'start_voice' ? 2.5 : 0,
                            ),
                          ),
                          elevation: 14,
                          shadowColor: const Color(0x40FDE047),
                        ),
                        icon: const Icon(Icons.mic, size: 28),
                        label: Text(
                          _running ? '실행 중...' : '시작 / 음성 제어',
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
                          id: 'reset_timer',
                          guide: '타이머 초기화 버튼입니다. 다시 누르면 2분 30초로 초기화합니다.',
                          onConfirmed: _cancelTimer,
                        );
                      },
                      icon: const Icon(Icons.restart_alt, size: 22),
                      label: const Text(
                        '타이머 초기화',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.3,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFCEC6AD),
                        side: BorderSide(
                          color: _armedActionId == 'reset_timer'
                              ? Colors.white
                              : Colors.transparent,
                          width: _armedActionId == 'reset_timer' ? 2 : 0,
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
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1C32), Color(0xFF041329)],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomItem(
                    index: 0,
                    icon: Icons.home_filled,
                    label: 'HOME',
                    active: false,
                  ),
                  _bottomItem(
                    index: 1,
                    icon: Icons.vibration,
                    label: 'DEVICES',
                    active: true,
                  ),
                  _bottomItem(
                    index: 2,
                    icon: Icons.mic,
                    label: 'VOICE',
                    active: false,
                  ),
                  _bottomItem(
                    index: 3,
                    icon: Icons.settings,
                    label: 'SETTINGS',
                    active: false,
                  ),
                ],
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
    this.color = const Color(0xFF0D1C32),
    this.borderColor = const Color(0x1A97917A),
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
