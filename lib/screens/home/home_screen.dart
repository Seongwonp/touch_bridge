import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tts_service.dart';
import '../../services/accessibility_settings.dart';
import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/home_device_store.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../voice/voice_listening_screen.dart';
import '../guardian/guardian_hub_screen.dart';

import 'widgets/home_empty_state.dart';
import 'widgets/home_device_card.dart';
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
    ActiveDeviceService.instance.deviceListUpdateNotifier.addListener(
      _loadDevices,
    );
  }

  // 홈 안내는 최초 로드에만 발화한다.
  // 홈은 IndexedStack에 상주하므로, 기기 목록 갱신(deviceListUpdateNotifier)마다
  // interrupt 안내를 하면 백그라운드 홈이 다른 화면(기기 관리 등)의 안내나
  // 첫 실행 온보딩 TTS를 끊는다.
  bool _announcedOnce = false;

  Future<void> _loadDevices() async {
    try {
      final devices = await HomeDeviceStore.loadDevices();
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _isLoading = false;
        // 다른 화면에서 기기가 지워져 목록이 줄면 현재 위치가 범위를 벗어난다.
        if (_currentDeviceIndex >= _devices.length) {
          _currentDeviceIndex = _devices.isEmpty ? 0 : _devices.length - 1;
        }
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
    // interrupt를 쓰지 않는다 — 첫 실행 온보딩 안내(main_navigation)가 재생 중일
    // 수 있으므로 큐 뒤에 자연스럽게 이어 붙인다.
    if (_devices.isEmpty) {
      await _tts.speak(
        '홈입니다. 등록된 가전이 없습니다. 보호자에게 설정의 보호자 설정에서 등록을 요청하세요.',
        source: 'HomeScreen',
      );
      return;
    }

    await _tts.speak(
      '홈입니다. 등록된 기기 ${_devices.length}개가 있습니다. 기기를 선택한 뒤 말하기 버튼을 누르세요.',
      source: 'HomeScreen',
    );
  }

  @override
  void dispose() {
    _quickVoiceTapTimer?.cancel();
    _pageController.dispose();
    ActiveDeviceService.instance.deviceListUpdateNotifier.removeListener(
      _loadDevices,
    );
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지운다.
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
      // 허브에 연결하는 동안 몇 초 걸릴 수 있다. 아무 소리 없이 멈춘 것처럼 보이지 않게 알리고,
      // 실패하면 실패를 알린다(메뉴는 열어 둔다: 연결 없이도 확인할 수 있는 항목이 있다).
      final needsConnect = bleId != null && BleService.instance.connectedDeviceId != bleId;
      if (needsConnect) {
        _tts.speak('$deviceName에 연결하는 중입니다.', source: 'HomeScreen', priority: TtsPriority.result);
      }
      final connected = await ActiveDeviceService.instance.setActiveDevice(
        deviceId: deviceId,
        deviceName: deviceName,
        bleId: bleId,
        bleName: bleName,
      );
      if (needsConnect && !connected) {
        _tts.speak(
          '$deviceName에 연결하지 못했습니다. 기기 전원과 거리를 확인해 주세요.',
          source: 'HomeScreen',
          priority: TtsPriority.result,
        );
      }
    }

    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ControlModeSheet(
        deviceName: deviceName,
        deviceId: deviceId,
        deviceIcon: iconFromCodePoint(device['iconCodePoint']),
      ),
    );
  }

  Future<void> _openVoiceForCurrentDevice() async {
    final hasDevice =
        _currentDeviceIndex >= 0 && _currentDeviceIndex < _devices.length;
    if (!hasDevice) {
      await _tts.speak(
        '선택된 기기가 없습니다. 보호자에게 설정의 보호자 설정에서 가전 등록을 요청하세요.',
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

  /// 기기가 없을 때 보호자가 바로 등록할 수 있게 보호자 설정을 연다.
  Future<void> _openGuardianHub() async {
    HapticFeedback.mediumImpact();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const GuardianHubScreen()));
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

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    // 홈에는 등록된 가전만 둔다. 가전 추가·삭제는 설정의 보호자 설정에서 한다.
    final itemCount = _devices.length;

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
                      // 기기가 없으면 안내 카드 하나만 둔다. 예전에는 아래 PageView의
                      // "새 기기 추가하기" 카드가 함께 떠서 같은 버튼이 두 번 나오고,
                      // 남은 높이가 모자라 그 카드 글자가 잘렸다(Galaxy A31 실기).
                      if (_devices.isEmpty)
                        Expanded(
                          child: SingleChildScrollView(
                            child: HomeEmptyState(
                              onOpenGuardianSettings: _openGuardianHub,
                            ),
                          ),
                        )
                      else ...[
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
                          count: _devices.length,
                          currentIndex: _currentDeviceIndex,
                          scale: rs,
                        ),
                        SizedBox(height: 12 * rs),
                      ],
                      if (_devices.isNotEmpty)
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
                            // 기기가 바뀐 결과 보고다. 낭독기는 이전·다음 버튼 이름만 읽고
                            // 바뀐 기기는 읽지 않으므로 result로 낭독기 사용 중에도 들리게 한다.
                            _tts.speak(
                              '${_devices[index]['name']}. ${_devices[index]['status']}.',
                              source: 'HomeScreen',
                              interrupt: true,
                              priority: TtsPriority.result,
                            );
                          },
                          itemCount: itemCount,
                          itemBuilder: (context, index) {
                            return HomeDeviceCard(
                              device: _devices[index],
                              onTap: () => _openDeviceControl(index),
                              onVoiceControl: () => _openVoiceForDevice(index),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_devices.isNotEmpty)
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
