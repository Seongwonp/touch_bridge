import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tts_service.dart';
import '../../services/accessibility_settings.dart';
import '../../services/active_device_service.dart';
import '../../services/home_device_store.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import '../voice/voice_listening_screen.dart';
import '../connection/device_connect_screen.dart';

import 'widgets/home_empty_state.dart';
import 'widgets/home_device_card.dart';
import 'widgets/home_add_device_card.dart';
import 'widgets/control_mode_sheet.dart';
import 'widgets/home_header.dart';
import 'widgets/home_voice_action_button.dart';
import 'widgets/device_page_indicator.dart';
import 'widgets/home_footer_nav_hint.dart';
import '../../widgets/ble_status_banner.dart';

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
  int _quickVoiceTapCount = 0;
  Timer? _quickVoiceTapTimer;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    // 기기 목록 갱신 감지 리스너 등록
    ActiveDeviceService.instance.deviceListUpdateNotifier.addListener(
      _loadDevices,
    );
  }

  // 홈 안내는 최초 로드에만 발화한다.
  // 홈은 IndexedStack에 상주하므로, 기기 목록 갱신(deviceListUpdateNotifier)마다
  // interrupt 안내를 하면 (a) 보호자가 기기 관리 화면에 있는데 백그라운드 홈이
  // 현재 안내를 선점하고, (b) 첫 실행 온보딩 TTS를 지워버리는 레이스가 있었다.
  bool _announcedOnce = false;

  Future<void> _loadDevices() async {
    try {
      final devices = await HomeDeviceStore.loadDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
      if (!_announcedOnce) {
        _announcedOnce = true;
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
    // interrupt를 쓰지 않는다 — 첫 실행 온보딩 안내(main_navigation)가 재생 중일
    // 수 있으므로 큐 뒤에 자연스럽게 이어 붙인다.
    if (_devices.isEmpty) {
      await _tts.speak(
        guardianMode
            ? '홈입니다. 등록된 기기가 없습니다. 기기 관리에서 새 기기를 추가하세요.'
            : '홈입니다. 등록된 기기가 없습니다. 화면의 기기 추가하기 버튼으로 직접 등록하거나, 보호자에게 요청하세요.',
        source: 'HomeScreen',
      );
      return;
    }

    await _tts.speak(
      guardianMode
          ? '홈입니다. 등록된 기기 ${_devices.length}개가 있습니다. 기기를 선택하거나 말하기 버튼을 누르세요.'
          : '홈입니다. 등록된 기기 ${_devices.length}개가 있습니다. 기기를 선택한 뒤 말하기 버튼을 누르세요.',
      source: 'HomeScreen',
    );
  }

  @override
  void dispose() {
    _quickVoiceTapTimer?.cancel();
    // 롱프레스 도중 화면이 사라지면 5초 뒤 죽은 context로 다이얼로그를 띄우려던
    // 누수(타이머 미취소) 방지.
    _deleteTimer?.cancel();
    _pageController.dispose();
    ActiveDeviceService.instance.deviceListUpdateNotifier.removeListener(
      _loadDevices,
    );
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
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

  Future<void> _openVoiceForCurrentDevice() async {
    final hasDevice =
        _currentDeviceIndex >= 0 && _currentDeviceIndex < _devices.length;
    if (!hasDevice) {
      await _tts.speak(
        '선택된 기기가 없습니다. 화면의 기기 추가하기 버튼으로 직접 등록하거나, 보호자에게 요청하세요.',
        source: 'HomeScreen',
        interrupt: true,
      );
      return;
    }

    HapticFeedback.mediumImpact();
    final device = _devices[_currentDeviceIndex];
    final deviceId = device['id'] as String? ?? '';
    final deviceName = device['name'] as String? ?? '스마트 기기';
    if (deviceId.isNotEmpty) {
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        bleId: device['bleId'] as String?,
        bleName: device['bleName'] as String?,
      );
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VoiceListeningScreen(
          deviceId: deviceId,
          deviceName: deviceName,
          autoStart: true,
        ),
      ),
    );
  }

  Future<void> _openVoiceForDevice(int index) async {
    if (index < 0 || index >= _devices.length) return;
    HapticFeedback.mediumImpact();
    final device = _devices[index];
    final deviceId = device['id'] as String? ?? '';
    final deviceName = device['name'] as String? ?? '스마트 기기';
    if (deviceId.isNotEmpty) {
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        bleId: device['bleId'] as String?,
        bleName: device['bleName'] as String?,
      );
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VoiceListeningScreen(
          deviceId: deviceId,
          deviceName: deviceName,
          autoStart: true,
        ),
      ),
    );
  }

  Future<void> _openDeviceConnect() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const DeviceConnectScreen()));
    _loadDevices();
  }

  void _handleQuickVoiceTap() {
    if (_devices.isEmpty) return;

    _quickVoiceTapTimer?.cancel();
    _quickVoiceTapCount += 1;

    if (_quickVoiceTapCount >= 3) {
      _quickVoiceTapCount = 0;
      HapticFeedback.heavyImpact();
      _tts.speak('음성 명령을 시작합니다.', source: 'HomeScreen', interrupt: true);
      _openVoiceForCurrentDevice();
      return;
    }

    _quickVoiceTapTimer = Timer(const Duration(milliseconds: 900), () {
      _quickVoiceTapCount = 0;
    });
  }

  Future<void> _deleteDevice(int index) async {
    try {
      final deviceName = _devices[index]['name'];
      setState(() {
        _devices.removeAt(index);
        if (_currentDeviceIndex >= _devices.length && _devices.isNotEmpty) {
          _currentDeviceIndex = _devices.length - 1;
        }
      });
      await HomeDeviceStore.saveDevices(_devices);
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
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borderDefault),
        ),
        title: const Text(
          '기기 삭제',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '$deviceName 기기를 삭제하시겠습니까?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text(
              '아니오',
              style: TextStyle(color: AppColors.textTertiary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _deleteDevice(index);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emergency,
            ),
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
      if (!mounted) return;
      _showDeleteConfirmation(index);
    });
  }

  void _onLongPressEnd() {
    _deleteTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final guardianMode = AccessibilitySettings.instance.guardianModeEnabled;
    // "기기 추가하기" 카드는 보호자 모드 여부와 상관없이 항상 마지막 페이지로 노출한다.
    // 혼자 쓰는 시각장애인 사용자도 보호자 모드를 켜지 않고 기기를 등록할 수 있어야 한다.
    final itemCount = _devices.length + 1;

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: 'Touch Bridge'),
      body: SafeArea(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerUp: (_) => _handleQuickVoiceTap(),
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
                      HomeHeader(scale: rs),
                      SizedBox(height: 8 * rs),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: BleStatusBanner(),
                      ),
                      SizedBox(height: 8 * rs),
                      if (_devices.isEmpty) ...[
                        HomeEmptyState(
                          guardianModeEnabled: guardianMode,
                          onAddDevicePressed: _openDeviceConnect,
                        ),
                        SizedBox(height: 24 * rs),
                      ] else ...[
                        HomeVoiceActionButton(
                          deviceName:
                              _currentDeviceIndex >= 0 &&
                                  _currentDeviceIndex < _devices.length
                              ? (_devices[_currentDeviceIndex]['name']
                                        as String? ??
                                    '선택된 기기')
                              : '선택된 기기',
                          enabled:
                              _currentDeviceIndex >= 0 &&
                              _currentDeviceIndex < _devices.length,
                          scale: rs,
                          onTap: _openVoiceForCurrentDevice,
                        ),
                        SizedBox(height: 14 * rs),
                        DevicePageIndicator(
                          count: _devices.length + 1,
                          currentIndex: _currentDeviceIndex,
                          scale: rs,
                        ),
                        SizedBox(height: 12 * rs),
                      ],
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          // 스크린리더 활성 시 좌우 스와이프가 요소 이동 제스처로
                          // 가로채이므로 PageView 스와이프를 잠근다.
                          // 이전/다음 버튼(HomeFooterNavHint)이 유일한 전환 수단이 된다.
                          physics: AccessibilitySettings.isScreenReaderActive
                              ? const NeverScrollableScrollPhysics()
                              : null,
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
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            if (index == _devices.length) {
                              return HomeAddDeviceCard(
                                onDeviceAdded: _loadDevices,
                              );
                            }

                            return HomeDeviceCard(
                              device: _devices[index],
                              onTap: () => _openDeviceControl(index),
                              managementEnabled: guardianMode,
                              onLongPressStart: guardianMode
                                  ? (_) => _onLongPressStart(index)
                                  : null,
                              onLongPressEnd: guardianMode
                                  ? (_) => _onLongPressEnd()
                                  : null,
                              onManage: guardianMode
                                  ? () => _showDeleteConfirmation(index)
                                  : null,
                              onVoiceControl: !guardianMode
                                  ? () => _openVoiceForDevice(index)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              HomeFooterNavHint(
                scale: rs,
                onPrevious: () => _pageController.previousPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                ),
                onNext: () => _pageController.nextPage(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
