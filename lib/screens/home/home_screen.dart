import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../control/remote_control_screen.dart';
import '../voice/voice_listening_screen.dart';
import 'appliance_selection_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TtsService _tts = TtsService();
  final PageController _pageController = PageController(viewportFraction: 0.9);

  int _currentDeviceIndex = 0;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _announceScreen();
  }

  Future<void> _loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('home_devices');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _devices = decoded.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        // Start with an empty list if no devices exist
        _devices = [];
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _announceScreen() async {
    await _tts.speak('홈 화면입니다. 기기를 선택하여 제어하세요.', interrupt: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openDeviceControl(int index) {
    HapticFeedback.lightImpact();
    final device = _devices[index];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ControlModeSheet(
        deviceName: device['name'] as String,
        deviceIcon: IconData(device['iconCodePoint'] as int, fontFamily: 'MaterialIcons'),
        onVoice: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const VoiceListeningScreen(),
            ),
          );
        },
        onManual: () {
          Navigator.of(ctx).pop();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const RemoteControlScreen(),
            ),
          );
        },
      ),
    );
  }

  Future<void> _deleteDevice(int index) async {
    try {
      final deviceName = _devices[index]['name'];
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _devices.removeAt(index);
        if (_currentDeviceIndex >= _devices.length && _devices.isNotEmpty) {
          _currentDeviceIndex = _devices.length - 1;
        }
      });
      await prefs.setString('home_devices', jsonEncode(_devices));
      await _tts.speak('$deviceName 기기가 삭제되었습니다.', interrupt: true);
    } catch (e) {
      debugPrint('Error deleting device: $e');
    }
  }

  void _showDeleteConfirmation(int index) {
    HapticFeedback.heavyImpact();
    final deviceName = _devices[index]['name'];
    _tts.speak('$deviceName 기기를 삭제하시겠습니까? 삭제하려면 예 버튼을 누르세요.', interrupt: true);
    
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text('기기 삭제', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('$deviceName 기기를 삭제하시겠습니까?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('아니오', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteDevice(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text('예', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Timer? _deleteTimer;

  void _onLongPressStart(int index) {
    HapticFeedback.mediumImpact();
    _tts.speak('삭제 확인 중... 5초간 더 누르면 삭제 창이 뜹니다.', interrupt: true);
    _deleteTimer = Timer(const Duration(seconds: 5), () {
      _showDeleteConfirmation(index);
    });
  }

  void _onLongPressEnd() {
    _deleteTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    if (_isLoading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Color(0xFFFFEB00))));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveScale.v(context, 20),
                  ResponsiveScale.v(context, 20),
                  ResponsiveScale.v(context, 20),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '내 기기',
                          style: TextStyle(
                            fontSize: 28 * rs,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: ResponsiveScale.v(context, 4)),
                        Text(
                          '기기를 눌러 제어하세요',
                          style: TextStyle(
                            fontSize: 14 * rs,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF888888),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    // 페이지 인디케이터
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_devices.length + 1, (index) {
                        final bool active = index == _currentDeviceIndex;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: EdgeInsets.symmetric(horizontal: 4 * rs),
                          width: active ? 32 * rs : 8 * rs,
                          height: 4 * rs,
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFFFEB00)
                                : const Color(0xFF333333),
                            borderRadius: BorderRadius.circular(2 * rs),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentDeviceIndex = index;
                          });
                          HapticFeedback.selectionClick();
                          if (index < _devices.length) {
                            _tts.speak('${_devices[index]['name']}. ${_devices[index]['status']}.', interrupt: true);
                          } else {
                            _tts.speak('새 기기 추가하기.', interrupt: true);
                          }
                        },
                        itemCount: _devices.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _devices.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6 * rs),
                              child: Semantics(
                                label: '새 기기 추가하기. 터치 브리지를 새로운 가전에 연결합니다.',
                                button: true,
                                child: GestureDetector(
                                  onTap: () async {
                                    HapticFeedback.mediumImpact();
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const ApplianceSelectionScreen()),
                                    );
                                    _loadDevices(); // Refresh list after returning
                                  },
                                  child: Container(
                                    padding: EdgeInsets.all(28 * rs),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1A1A1A),
                                      borderRadius: BorderRadius.circular(24 * rs),
                                      border: Border.all(color: const Color(0xFFFFEB00), width: 2 * rs),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 100 * rs,
                                          height: 100 * rs,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2A2A2A),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Icon(
                                              Icons.add_rounded,
                                              color: const Color(0xFFFFEB00),
                                              size: 64 * rs,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: ResponsiveScale.v(context, 32)),
                                        Text(
                                          '새 기기 추가하기',
                                          style: TextStyle(
                                            fontSize: 24 * rs,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFFFEB00),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                        SizedBox(height: ResponsiveScale.v(context, 12)),
                                        Text(
                                          '터치 브리지를 새로운 가전에\n연결하고 매핑을 시작합니다',
                                          style: TextStyle(
                                            fontSize: 14 * rs,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF888888),
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }

                          final device = _devices[index];
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6 * rs),
                            child: Semantics(
                              label: '${device['name']}. 현재 상태 ${device['status']}. 선택하려면 두 번 누르세요. 삭제하려면 5초간 길게 누르세요.',
                              button: true,
                              child: GestureDetector(
                                onTap: () => _openDeviceControl(index),
                                onLongPressStart: (_) => _onLongPressStart(index),
                                onLongPressEnd: (_) => _onLongPressEnd(),
                                onLongPressCancel: () => _onLongPressEnd(),
                                child: Container(
                                  padding: EdgeInsets.all(28 * rs),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111111),
                                    borderRadius: BorderRadius.circular(24 * rs),
                                    border: Border.all(color: const Color(0xFF2A2A2A)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 120 * rs,
                                        height: 120 * rs,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A1A),
                                          borderRadius: BorderRadius.circular(24 * rs),
                                          border: Border.all(color: const Color(0xFF333333)),
                                        ),
                                        child: Center(
                                          child: Icon(
                                            IconData(device['iconCodePoint'] as int, fontFamily: 'MaterialIcons'),
                                            color: const Color(0xFFFFEB00),
                                            size: 56 * rs,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: ResponsiveScale.v(context, 24)),
                                      Text(
                                        device['name'] as String,
                                        style: TextStyle(
                                          fontSize: 26 * rs,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      SizedBox(height: ResponsiveScale.v(context, 10)),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 8 * rs,
                                            height: 8 * rs,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF00FF88),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: 8 * rs),
                                          Text(
                                            device['status'] as String,
                                            style: TextStyle(
                                              fontSize: 15 * rs,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFFAAAAAA),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: ResponsiveScale.v(context, 28)),
                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.symmetric(vertical: 14 * rs),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFFEB00),
                                          borderRadius: BorderRadius.circular(12 * rs),
                                        ),
                                        child: Text(
                                          '눌러서 제어하기',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15 * rs,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                            color: Colors.black,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // 하단 스와이프 안내
                    Padding(
                      padding: EdgeInsets.only(
                        top: ResponsiveScale.v(context, 12),
                        bottom: ResponsiveScale.v(context, 8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: Icon(
                              Icons.chevron_left_rounded,
                              color: const Color(0xFF555555),
                              size: 28 * rs,
                            ),
                          ),
                          Text(
                            '좌우로 밀어서 기기 전환',
                            style: TextStyle(
                              fontSize: 12 * rs,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: const Color(0xFF555555),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOut,
                              );
                            },
                            icon: Icon(
                              Icons.chevron_right_rounded,
                              color: const Color(0xFF555555),
                              size: 28 * rs,
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

class _ControlModeSheet extends StatelessWidget {
  const _ControlModeSheet({
    required this.deviceName,
    required this.deviceIcon,
    required this.onVoice,
    required this.onManual,
  });

  final String deviceName;
  final IconData deviceIcon;
  final VoidCallback onVoice;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28 * rs)),
        border: const Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      padding: EdgeInsets.fromLTRB(24 * rs, 16 * rs, 24 * rs, 40 * rs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40 * rs,
            height: 4 * rs,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2 * rs),
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 24)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(deviceIcon, color: const Color(0xFFFFEB00), size: 32 * rs),
              SizedBox(width: 12 * rs),
              Text(
                deviceName,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22 * rs,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: ResponsiveScale.v(context, 8)),
          Text(
            '제어 방식을 선택하세요',
            style: TextStyle(
              color: const Color(0xFF888888),
              fontSize: 14 * rs,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 24)),
          SizedBox(
            width: double.infinity,
            height: 72 * rs,
            child: ElevatedButton.icon(
              onPressed: onVoice,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFEB00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16 * rs),
                ),
                elevation: 0,
              ),
              icon: Icon(Icons.mic_rounded, size: 28 * rs),
              label: Text(
                '음성으로 제어',
                style: TextStyle(fontSize: 20 * rs, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          SizedBox(height: ResponsiveScale.v(context, 12)),
          SizedBox(
            width: double.infinity,
            height: 72 * rs,
            child: ElevatedButton.icon(
              onPressed: onManual,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: const Color(0xFFFFEB00),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16 * rs),
                  side: BorderSide(color: const Color(0xFFFFEB00), width: 2 * rs),
                ),
                elevation: 0,
              ),
              icon: Icon(Icons.touch_app_rounded, size: 28 * rs),
              label: Text(
                '수동으로 조작',
                style: TextStyle(fontSize: 20 * rs, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
