import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../connection/device_connect_screen.dart';
import '../control/remote_control_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({super.key});

  @override
  State<VoiceListeningScreen> createState() => _VoiceListeningScreenState();
}

class _VoiceListeningScreenState extends State<VoiceListeningScreen> {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final math.Random _random = math.Random();

  bool _isSpeechReady = false;
  bool _isListening = false;
  String _statusMessage = '말씀해 주세요. 듣고 있습니다.';
  String _recognizedText = '아직 인식된 음성이 없어요.';

  Timer? _waveTimer;
  Timer? _navResetTimer;
  Timer? _actionResetTimer;
  int? _armedNavIndex;
  String? _armedActionId;

  List<double> _waveHeights = const [
    0.20,
    0.50,
    0.80,
    1.00,
    0.60,
    0.30,
    1.00,
    0.50,
    0.70,
    0.80,
    0.20,
  ];

  final List<String> _quickCommands = const [
    '거실 불 켜줘',
    '내일 오전 7시 알람',
    '오늘 날씨 어때?',
    '에어컨 24도로 설정',
    '음악 틀어줘',
  ];

  @override
  void initState() {
    super.initState();
    _initializeVoiceFeatures();
  }

  Future<void> _initializeVoiceFeatures() async {
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);

      final bool available = await _speech.initialize(
        onStatus: (status) {
          if (!mounted) {
            return;
          }
          setState(() {
            _statusMessage = '상태: $status';
            if (status == 'notListening' || status == 'done') {
              _isListening = false;
            }
          });
        },
        onError: (error) {
          if (!mounted) {
            return;
          }
          setState(() {
            _statusMessage = '오류: ${error.errorMsg}';
            _isListening = false;
          });
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isSpeechReady = available;
        _statusMessage = available ? '말씀해 주세요. 듣고 있습니다.' : '음성 인식을 사용할 수 없어요.';
      });

      if (available) {
        await _startListening();
      }
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeechReady = false;
        _isListening = false;
        _statusMessage = '음성 기능을 사용할 수 없는 기기예요.';
      });
      _stopWaveAnimation();
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeechReady = false;
        _isListening = false;
        _statusMessage = '음성 초기화 실패: ${e.message ?? e.code}';
      });
      _stopWaveAnimation();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSpeechReady = false;
        _isListening = false;
        _statusMessage = '음성 기능 준비 중 오류가 발생했어요.';
      });
      _stopWaveAnimation();
    }
  }

  Future<void> _speak(String message) async {
    try {
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.stop();
      await _tts.speak(message);
    } catch (_) {
      // TTS failure should not crash the voice screen.
    }
  }

  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted || !_isListening) {
        return;
      }

      setState(() {
        _waveHeights = List<double>.generate(
          _waveHeights.length,
          (index) => 0.18 + _random.nextDouble() * 0.82,
        );
      });
    });
  }

  void _stopWaveAnimation() {
    _waveTimer?.cancel();
    setState(() {
      _waveHeights = const [
        0.20,
        0.50,
        0.80,
        1.00,
        0.60,
        0.30,
        1.00,
        0.50,
        0.70,
        0.80,
        0.20,
      ];
    });
  }

  Future<void> _startListening() async {
    if (!_isSpeechReady) {
      await _speak('현재 기기에서 음성 인식을 사용할 수 없습니다.');
      return;
    }

    if (_speech.isListening) {
      return;
    }

    setState(() {
      _isListening = true;
      _statusMessage = '말씀해 주세요. 듣고 있습니다.';
    });
    _startWaveAnimation();

    try {
      await _speech.listen(
        onResult: (result) {
          if (!mounted) {
            return;
          }

          setState(() {
            _recognizedText = result.recognizedWords.isEmpty
                ? '음성을 인식하지 못했어요. 다시 천천히 말씀해 주세요.'
                : result.recognizedWords;
          });
        },
        localeId: 'ko_KR',
        listenOptions: SpeechListenOptions(listenMode: ListenMode.confirmation),
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 30),
      );
    } on MissingPluginException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _isSpeechReady = false;
        _statusMessage = '음성 기능 플러그인을 찾을 수 없어요.';
      });
      _stopWaveAnimation();
    } on PlatformException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _statusMessage = '음성 듣기 실패: ${e.message ?? e.code}';
      });
      _stopWaveAnimation();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
        _statusMessage = '음성 듣기 중 오류가 발생했어요.';
      });
      _stopWaveAnimation();
    }
  }

  Future<void> _stopListening() async {
    if (!_isListening) {
      return;
    }

    try {
      await _speech.stop();
    } catch (_) {
      // Ignore stop failures to keep UI stable.
    }
    if (!mounted) {
      return;
    }

    setState(() {
      _isListening = false;
      _statusMessage = '음성 대기를 종료했습니다.';
    });
    _stopWaveAnimation();
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
    await _tts.stop();
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
    await _tts.stop();

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
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const DeviceConnectScreen()),
        );
        break;
      case 2:
        return;
      case 3:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
        );
        break;
    }
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
    _speech.cancel();
    _waveTimer?.cancel();
    _navResetTimer?.cancel();
    _actionResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                        builder: (_) => const RemoteControlScreen(),
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
                    icon: const Icon(Icons.settings, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 500,
                      height: 500,
                      decoration: BoxDecoration(
                        color: const Color(0x0DFDE047),
                        borderRadius: BorderRadius.circular(250),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
                    child: Column(
                      children: [
                        const Text(
                          'Listening...',
                          style: TextStyle(
                            color: Color(0xFFFDE047),
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFCEC6AD),
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _recognizedText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFB6C6ED),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 34),
                        SizedBox(
                          height: 120,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: _waveHeights
                                .asMap()
                                .entries
                                .map(
                                  (entry) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 240,
                                      ),
                                      width: 6,
                                      height: 120 * entry.value,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFDE047)
                                            .withValues(
                                              alpha: _isListening
                                                  ? 0.35 + (entry.value * 0.65)
                                                  : 0.25,
                                            ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              _armAndRun(
                                id: 'cancel_voice',
                                guide: '취소 버튼입니다. 다시 누르면 음성 대기를 중지합니다.',
                                onConfirmed: _stopListening,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27354C),
                              foregroundColor: const Color(0xFFE2C62D),
                              minimumSize: const Size.fromHeight(84),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: _armedActionId == 'cancel_voice'
                                      ? Colors.white
                                      : const Color(0x334B4734),
                                  width: _armedActionId == 'cancel_voice'
                                      ? 2.5
                                      : 1,
                                ),
                              ),
                            ),
                            child: const Text(
                              '취소 (Cancel)',
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 10,
                          children: _quickCommands.map((command) {
                            final id = 'chip_$command';
                            final armed = _armedActionId == id;

                            return InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () {
                                _armAndRun(
                                  id: id,
                                  guide: '$command 명령입니다. 다시 누르면 이 문장을 선택합니다.',
                                  onConfirmed: () {
                                    setState(() {
                                      _recognizedText = command;
                                      _statusMessage = '추천 명령을 선택했습니다.';
                                    });
                                  },
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0D1C32),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: armed
                                        ? Colors.white
                                        : const Color(0x334B4734),
                                    width: armed ? 2.2 : 1,
                                  ),
                                ),
                                child: Text(
                                  '"$command"',
                                  style: const TextStyle(
                                    color: Color(0xFFCEC6AD),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
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
                    active: false,
                  ),
                  _bottomItem(
                    index: 2,
                    icon: Icons.mic,
                    label: 'VOICE',
                    active: true,
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
