import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/tts_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../widgets/responsive_scale.dart';
import '../safety/emergency_stop_screen.dart';
import '../connection/device_connect_screen.dart';
import '../mapping/photo_mapping_screen.dart';
import '../settings/settings_screen.dart';

class VoiceListeningScreen extends StatefulWidget {
  const VoiceListeningScreen({super.key});

  @override
  State<VoiceListeningScreen> createState() => _VoiceListeningScreenState();
}

class _VoiceListeningScreenState extends State<VoiceListeningScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final TtsService _tts = TtsService();
  final math.Random _random = math.Random();

  bool _isRecording = false;
  bool _isProcessing = false;
  String _statusMessage = '버튼을 눌러 명령을 말씀해 주세요.';
  String _recognizedText = '아직 인식된 명령이 없어요.';

  Timer? _waveTimer;
  List<double> _waveHeights = const [
    0.20, 0.50, 0.80, 1.00, 0.60, 0.30, 1.00, 0.50, 0.70, 0.80, 0.20,
  ];

  // dotenv에서 서버 주소를 읽어옵니다.
  final String _serverUrl = dotenv.get('VOICE_SERVER_URL', fallback: 'http://localhost:8000/voice-command');

  Future<void> _speak(String message) async {
    await _tts.speak(message);
  }

  void _startWaveAnimation() {
    _waveTimer?.cancel();
    _waveTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && _isRecording) {
        setState(() {
          _waveHeights = List<double>.generate(
            _waveHeights.length,
            (index) => 0.2 + _random.nextDouble() * 0.8,
          );
        });
      }
    });
  }

  void _stopWaveAnimation() {
    _waveTimer?.cancel();
    setState(() {
      _waveHeights = const [
        0.20, 0.50, 0.80, 1.00, 0.60, 0.30, 1.00, 0.50, 0.70, 0.80, 0.20,
      ];
    });
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _statusMessage = '명령 분석 중...';
      });
      _stopWaveAnimation();
      if (path != null) {
        _sendAudioToServer(path);
      }
    } else {
      if (await _audioRecorder.hasPermission()) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/voice_cmd.m4a';
        
        const config = RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000);
        
        await _audioRecorder.start(config, path: path);
        setState(() {
          _isRecording = true;
          _statusMessage = '듣고 있습니다...';
        });
        _startWaveAnimation();
        HapticFeedback.mediumImpact();
      }
    }
  }

  Future<void> _sendAudioToServer(String path) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_serverUrl));
      request.files.add(await http.MultipartFile.fromPath('file', path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _handleCommand(data);
      } else {
        setState(() {
          _statusMessage = '서버 연결 오류가 발생했습니다.';
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = '네트워크 오류: $e';
        _isProcessing = false;
      });
    }
  }

  void _handleCommand(Map<String, dynamic> data) {
    final action = data['action'];
    final message = data['message'] ?? '';
    final recognized = data['text'] ?? '';

    setState(() {
      _isProcessing = false;
      _recognizedText = recognized.isNotEmpty ? recognized : (action == 'NONE' ? '명령을 이해하지 못함' : '명령 수행 중');
    });

    if (message.isNotEmpty) _speak(message);

    switch (action) {
      case 'EMERGENCY_STOP':
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyStopScreen()),
        );
        break;
      case 'NAVIGATE':
        final target = data['target'];
        Widget? screen;
        if (target == 'connection') screen = const DeviceConnectScreen();
        if (target == 'mapping') screen = const PhotoMappingScreen();
        if (target == 'settings') screen = const SettingsScreen();
        
        if (screen != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
        }
        break;
      case 'MICROWAVE_CONTROL':
        final commands = data['commands'] as List<dynamic>?;
        if (commands != null && commands.isNotEmpty) {
          setState(() {
            _statusMessage = '명령 수행 중: ${commands.join(" → ")}';
          });
          // 실제 환경에서는 여기서 하드웨어로 명령을 전송하거나 
          // UI 상에서 버튼이 눌리는 애니메이션을 보여줄 수 있습니다.
          _showMicrowaveAction(commands.cast<String>());
        }
        break;
      default:
        setState(() => _statusMessage = '다시 말씀해 주세요.');
    }
  }

  void _showMicrowaveAction(List<String> commands) {
    // 사용자에게 시각적 피드백을 주기 위한 스낵바
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('전자레인지 조작: ${commands.join(" → ")}'),
        backgroundColor: const Color(0xFFFFEB00),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: '확인',
          textColor: Colors.black,
          onPressed: () {},
        ),
      ),
    );
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    _audioRecorder.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: const Row(
                children: [
                  Text(
                    'Touch Bridge AI',
                    style: TextStyle(
                      color: Color(0xFFFFEB00),
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _isRecording ? const Color(0xFFFFEB00) : Colors.white,
                        fontSize: 24 * rs,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    
                    // 음성 파형 애니메이션
                    SizedBox(
                      height: 100,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _waveHeights.map((h) => AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 8,
                          height: 100 * h,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _isRecording ? const Color(0xFFFFEB00) : const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )).toList(),
                      ),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // 메인 녹음 버튼
                    GestureDetector(
                      onTap: _isProcessing ? null : _toggleRecording,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: _isRecording ? const Color(0xFF2A2A2A) : const Color(0xFFFFEB00),
                          shape: BoxShape.circle,
                          border: _isRecording ? Border.all(color: const Color(0xFFFFEB00), width: 4) : null,
                          boxShadow: [
                            BoxShadow(
                              color: _isRecording ? const Color(0x66FFEB00) : Colors.black45,
                              blurRadius: 20,
                              spreadRadius: 5,
                            )
                          ],
                        ),
                        child: Icon(
                          _isProcessing ? Icons.sync : (_isRecording ? Icons.stop : Icons.mic),
                          color: _isRecording ? const Color(0xFFFFEB00) : Colors.black,
                          size: 50,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // 인식된 결과 텍스트 박스
                    Container(
                      padding: const EdgeInsets.all(20),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '인식 결과',
                            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _recognizedText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18 * rs,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
