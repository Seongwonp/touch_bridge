import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/tts_service.dart';
import '../../services/accessibility_settings.dart';
import '../../services/active_device_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';

import 'widgets/home_empty_state.dart';
import 'widgets/home_device_card.dart';
import 'widgets/home_add_device_card.dart';
import 'widgets/control_mode_sheet.dart';

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
    // 기기 목록 갱신 감지 리스너 등록
    ActiveDeviceService.instance.deviceListUpdateNotifier.addListener(_loadDevices);
  }

  Future<void> _loadDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('home_devices');
      if (jsonStr != null) {
        if (!mounted) return;
        final List<dynamic> decoded = jsonDecode(jsonStr);
        setState(() {
          _devices = decoded.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
        await _announceScreen();
      } else {
        _devices = [];
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        await _announceScreen();
      }
    } catch (e) {
      debugPrint('Error loading devices: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _announceScreen() async {
    final guardianMode = AccessibilitySettings.instance.guardianModeEnabled;
    if (_devices.isEmpty) {
      await _tts.speak(
        guardianMode
            ? '홈 화면입니다. 등록된 기기가 없습니다. 보호자께서는 연결 탭에서 먼저 기기를 추가해 주세요.'
            : '홈 화면입니다. 등록된 기기가 없습니다. 연결 탭에서 기기를 추가해 주세요.',
        source: 'HomeScreen',
        interrupt: true,
      );
      return;
    }

    await _tts.speak(
      guardianMode
          ? '홈 화면입니다. 등록된 기기 ${_devices.length}개가 있습니다. 기기를 두 번 눌러 제어하고, 음성 탭에서 만두 데워줘처럼 말씀하실 수 있습니다.'
          : '홈 화면입니다. 등록된 기기 ${_devices.length}개가 있습니다.',
      source: 'HomeScreen',
      interrupt: true,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    ActiveDeviceService.instance.deviceListUpdateNotifier.removeListener(_loadDevices);
    _tts.stop();
    super.dispose();
  }

  Future<void> _openDeviceControl(int index) async {
    HapticFeedback.lightImpact();
    final device = _devices[index];
    final deviceId = device['id'] as String? ?? '';
    final deviceName = device['name'] as String? ?? '스마트 기기';
    final bleId = device['bleId'] as String?;
    final bleName = device['bleName'] as String?;
    
    if (deviceId.isNotEmpty) {
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        bleId: bleId,
        bleName: bleName,
      );
    }
    
    if (!mounted) return;
    
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ControlModeSheet(
        deviceName: deviceName,
        deviceId: deviceId,
        deviceIcon: IconData(
          device['iconCodePoint'] as int,
          fontFamily: 'MaterialIcons',
        ),
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
      await _tts.speak(
        '$deviceName 기기가 삭제되었습니다.',
        source: 'HomeScreen',
        interrupt: true,
      );
    } catch (e) {
      debugPrint('Error deleting device: $e');
    }
  }

  void _showDeleteConfirmation(int index) {
    HapticFeedback.heavyImpact();
    final deviceName = _devices[index]['name'];
    _tts.speak(
      '$deviceName 기기를 삭제하시겠습니까? 삭제하려면 예 버튼을 누르세요.',
      source: 'HomeScreen',
      interrupt: true,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text(
          '기기 삭제',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '$deviceName 기기를 삭제하시겠습니까?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('아니오', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteDevice(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              '예',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Timer? _deleteTimer;

  void _onLongPressStart(int index) {
    HapticFeedback.mediumImpact();
    _tts.speak(
      '삭제 확인 중... 5초간 더 누르면 삭제 창이 뜹니다.',
      source: 'HomeScreen',
      interrupt: true,
    );
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
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFEB00)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  ResponsiveScale.v(context, 20),
                  ResponsiveScale.v(context, 10),
                  ResponsiveScale.v(context, 20),
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(rs),
                    SizedBox(height: 16 * rs),
                    if (_devices.isEmpty) ...[
                      const HomeEmptyState(),
                      SizedBox(height: 24 * rs),
                    ] else ...[
                      _buildPageIndicator(rs),
                      SizedBox(height: 12 * rs),
                    ],
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentDeviceIndex = index;
                          });
                          HapticFeedback.selectionClick();
                          if (index < _devices.length) {
                            _tts.speak(
                              '${_devices[index]['name']}. ${_devices[index]['status']}.',
                              source: 'HomeScreen',
                              interrupt: true,
                            );
                          } else {
                            _tts.speak(
                              '새 기기 추가하기.',
                              source: 'HomeScreen',
                              interrupt: true,
                            );
                          }
                        },
                        itemCount: _devices.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _devices.length) {
                            return HomeAddDeviceCard(
                              onDeviceAdded: _loadDevices,
                            );
                          }

                          return HomeDeviceCard(
                            device: _devices[index],
                            onTap: () => _openDeviceControl(index),
                            onLongPressStart: (_) => _onLongPressStart(index),
                            onLongPressEnd: (_) => _onLongPressEnd(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildFooterNavigation(rs),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(double rs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '내 기기',
          style: TextStyle(
            fontSize: 24 * rs,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        SizedBox(height: ResponsiveScale.v(context, 2)),
        Text(
          '기기를 눌러 제어하세요',
          style: TextStyle(
            fontSize: 13 * rs,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF888888),
          ),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(double rs) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_devices.length + 1, (index) {
        final bool active = index == _currentDeviceIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.symmetric(horizontal: 4 * rs),
          width: active ? 32 * rs : 8 * rs,
          height: 4 * rs,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFFEB00) : const Color(0xFF333333),
            borderRadius: BorderRadius.circular(2 * rs),
          ),
        );
      }),
    );
  }

  Widget _buildFooterNavigation(double rs) {
    return Padding(
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
    );
  }
}
