import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/tts_service.dart';

import '../control/remote_control_screen.dart';
import '../mapping/photo_mapping_screen.dart';
import '../voice/voice_listening_screen.dart';

class DeviceInfo {
  DeviceInfo({required this.name, this.status = '작동 대기 중', required this.iconCodePoint});

  final String name;
  final String status;
  final int iconCodePoint;

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  Map<String, dynamic> toJson() => {'name': name, 'status': status, 'iconCodePoint': iconCodePoint};

  factory DeviceInfo.fromJson(Map<String, dynamic> j) => DeviceInfo(
        name: j['name'] as String,
        status: j['status'] as String? ?? '작동 대기 중',
        iconCodePoint: j['iconCodePoint'] as int,
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TtsService _tts = TtsService();
  final PageController _pageController = PageController(viewportFraction: 0.92);

  int _currentDeviceIndex = 0;
  List<DeviceInfo> _devices = [];

  static const _prefKeyDevices = 'home_devices';

  static final _defaultDevices = [
    DeviceInfo(name: '스마트 전자레인지', status: '작동 대기 중', iconCodePoint: Icons.microwave_rounded.codePoint),
    DeviceInfo(name: '스마트 공기청정기', status: '공기 질 분석 중', iconCodePoint: Icons.air_rounded.codePoint),
    DeviceInfo(name: '스마트 전등 허브', status: '원격 제어 가능', iconCodePoint: Icons.light_mode_rounded.codePoint),
  ];

  static final _kIconOptions = [
    (label: '전자레인지', icon: Icons.microwave_rounded),
    (label: '세탁기', icon: Icons.local_laundry_service_rounded),
    (label: '공기청정기', icon: Icons.air_rounded),
    (label: '에어컨', icon: Icons.ac_unit_rounded),
    (label: '전등', icon: Icons.light_mode_rounded),
    (label: 'TV', icon: Icons.tv_rounded),
    (label: '냉장고', icon: Icons.kitchen_rounded),
    (label: '기타', icon: Icons.devices_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKeyDevices);
    if (jsonStr != null) {
      final list = (jsonDecode(jsonStr) as List)
          .map((e) => DeviceInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => _devices = list);
    } else {
      if (mounted) setState(() => _devices = List.from(_defaultDevices));
    }
    _announceScreen();
  }

  Future<void> _saveDevices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyDevices, jsonEncode(_devices.map((d) => d.toJson()).toList()));
  }

  Future<void> _announceScreen() async {
    if (_devices.isEmpty) {
      await _tts.speak('홈 화면입니다. 기기가 없습니다. 상단 추가 버튼을 눌러 기기를 등록하세요.');
    } else {
      await _tts.speak('홈 화면입니다. 현재 ${_devices[_currentDeviceIndex].name}, 상태: ${_devices[_currentDeviceIndex].status}. 좌우로 밀어서 기기를 전환하고, 기기를 눌러 제어하세요.');
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _pageController.dispose();
    super.dispose();
  }

  void _showAddDeviceDialog() {
    final nameCtrl = TextEditingController();
    int selectedIconIndex = 0;
    _tts.speak('기기 추가 화면입니다. 기기 이름을 입력하고 종류를 선택하세요.');
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('기기 추가', style: TextStyle(color: Color(0xFFFFEB00), fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('기기 이름', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: '예: 우리집 전자레인지',
                    hintStyle: const TextStyle(color: Color(0xFF555577)),
                    filled: true,
                    fillColor: const Color(0xFF0D1C32),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF333355)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFFEB00), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('기기 종류', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(_kIconOptions.length, (i) {
                    final opt = _kIconOptions[i];
                    final selected = i == selectedIconIndex;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedIconIndex = i),
                      child: Container(
                        width: 68,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0x33FFEB00) : const Color(0xFF0D1C32),
                          border: Border.all(
                            color: selected ? const Color(0xFFFFEB00) : const Color(0xFF333355),
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(opt.icon, color: selected ? const Color(0xFFFFEB00) : const Color(0xFF888888), size: 24),
                            const SizedBox(height: 4),
                            Text(
                              opt.label,
                              style: TextStyle(
                                color: selected ? const Color(0xFFFFEB00) : const Color(0xFF888888),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소', style: TextStyle(color: Color(0xFF888888))),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                final opt = _kIconOptions[selectedIconIndex];
                Navigator.of(ctx).pop();
                final device = DeviceInfo(name: name, iconCodePoint: opt.icon.codePoint);
                setState(() => _devices.add(device));
                await _saveDevices();
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    _devices.length - 1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
                _tts.speak('$name 기기가 추가되었습니다.');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFEB00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('추가', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceOptions(int index) {
    final device = _devices[index];
    _tts.speak('${device.name} 기기 옵션입니다. 수정 또는 삭제를 선택하세요.');
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111111),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFF444444), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(device.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: Color(0xFFFFEB00)),
              title: const Text('이름 수정', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showEditNameDialog(index);
              },
            ),
            ListTile(
              leading: const Icon(Icons.grid_view_rounded, color: Color(0xFFFFEB00)),
              title: const Text('버튼 매핑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: const Text('AI로 버튼 위치 설정', style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => PhotoMappingScreen(deviceId: device.name, deviceName: device.name),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Color(0xFFFF3B30)),
              title: const Text('기기 삭제', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(ctx).pop();
                _showDeleteDialog(index);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(int index) {
    final device = _devices[index];
    final ctrl = TextEditingController(text: device.name);
    _tts.speak('이름 수정 화면입니다. 새 이름을 입력하세요.');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('이름 수정', style: TextStyle(color: Color(0xFFFFEB00), fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0D1C32),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF333355))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFFEB00), width: 2)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소', style: TextStyle(color: Color(0xFF888888)))),
          ElevatedButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.of(ctx).pop();
              setState(() => _devices[index] = DeviceInfo(name: name, status: device.status, iconCodePoint: device.iconCodePoint));
              await _saveDevices();
              _tts.speak('$name 으로 이름이 변경되었습니다.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFEB00), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(int index) {
    final device = _devices[index];
    _tts.speak('${device.name} 기기를 삭제하려면 삭제 버튼을 누르세요.');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('기기 삭제', style: TextStyle(color: Color(0xFFFF3B30), fontWeight: FontWeight.w800)),
        content: Text('${device.name}을(를) 삭제하시겠어요?', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소', style: TextStyle(color: Color(0xFF888888)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              setState(() {
                _devices.removeAt(index);
                if (_currentDeviceIndex >= _devices.length && _currentDeviceIndex > 0) {
                  _currentDeviceIndex = _devices.length - 1;
                }
              });
              await _saveDevices();
              _tts.speak('${device.name} 기기가 삭제되었습니다.');
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF3B30), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('삭제', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _openDeviceControl(int index) {
    HapticFeedback.lightImpact();
    final device = _devices[index];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ControlModeSheet(
        deviceName: device.name,
        deviceIcon: device.icon,
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
              builder: (_) => RemoteControlScreen(deviceName: device.name),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
              ),
              child: Row(
                children: [
                  const Text(
                    'Touch Bridge',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Color(0xFFFFEB00),
                    ),
                  ),
                  const Spacer(),
                  Semantics(
                    label: '기기 추가',
                    button: true,
                    child: IconButton(
                      onPressed: _showAddDeviceDialog,
                      icon: const Icon(Icons.add_rounded, color: Color(0xFFFFEB00), size: 28),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '내 기기',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '기기를 눌러 제어하세요',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 페이지 인디케이터
                    Semantics( // 페이지 인디케이터 Semantics 추가
                      label: '현재 ${_currentDeviceIndex + 1}번째 기기, 총 ${_devices.length}개 기기',
                      liveRegion: true, // 내용 변경 시 스크린 리더가 자동으로 읽도록 설정
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_devices.length, (index) {
                          final bool active = index == _currentDeviceIndex;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: active ? 32 : 8,
                            height: 4,
                            decoration: BoxDecoration(
                              color: active
                                  ? const Color(0xFFFFEB00)
                                  : const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_devices.isEmpty)
                      Expanded(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF333333), size: 80),
                              const SizedBox(height: 16),
                              const Text('기기가 없습니다', style: TextStyle(color: Color(0xFF555555), fontSize: 18, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              const Text('상단 + 버튼을 눌러 기기를 추가하세요', style: TextStyle(color: Color(0xFF444444), fontSize: 13)),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: _showAddDeviceDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFEB00),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                ),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('기기 추가', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentDeviceIndex = index;
                          });
                          HapticFeedback.selectionClick();
                          _tts.speak('${_devices[index].name}, 상태: ${_devices[index].status}'); // 기기 전환 시 상세 안내
                        },
                        itemCount: _devices.length,
                        itemBuilder: (context, index) {
                          final device = _devices[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Semantics( // 기기 카드 Semantics 추가
                              label: '${device.name}, 상태: ${device.status}. 눌러서 제어 모드 선택. 길게 눌러서 삭제.',
                              button: true,
                              child: GestureDetector(
                                onTap: () => _openDeviceControl(index),
                                onLongPress: () => _showDeviceOptions(index),
                                child: Container(
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111111),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFF2A2A2A)),
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      return SingleChildScrollView(
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 120,
                                                height: 120,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1A1A1A),
                                                  borderRadius: BorderRadius.circular(24),
                                                  border: Border.all(color: const Color(0xFF333333)),
                                                ),
                                                child: Center(
                                                  child: Icon(
                                                    device.icon,
                                                    color: const Color(0xFFFFEB00),
                                                    size: 56,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 24),
                                              Text(
                                                device.name,
                                                style: const TextStyle(
                                                  fontSize: 26,
                                                  fontWeight: FontWeight.w800,
                                                  color: Colors.white,
                                                  height: 1.2,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 10),
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF00FF88),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    device.status,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w600,
                                                      color: Color(0xFFAAAAAA),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 28),
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(vertical: 14),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFFEB00),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  '눌러서 제어하기',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.5,
                                                    color: Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
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
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Semantics( // 이전 기기 버튼 Semantics 추가
                            label: '이전 기기',
                            button: true,
                            child: IconButton(
                              onPressed: () {
                                _pageController.previousPage(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                              icon: const Icon(
                                Icons.chevron_left_rounded,
                                color: Color(0xFF555555),
                                size: 28,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8), // 아이콘 버튼 사이 간격 조정
                          const Text(
                            '좌우로 밀어서 기기 전환',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                              color: Color(0xFF555555),
                            ),
                          ),
                          const SizedBox(width: 8), // 아이콘 버튼 사이 간격 조정
                          Semantics( // 다음 기기 버튼 Semantics 추가
                            label: '다음 기기',
                            button: true,
                            child: IconButton(
                              onPressed: () {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                );
                              },
                              icon: const Icon(
                                Icons.chevron_right_rounded,
                                color: Color(0xFF555555),
                                size: 28,
                              ),
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

class _ControlModeSheet extends StatefulWidget {
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
  State<_ControlModeSheet> createState() => _ControlModeSheetState();
}

class _ControlModeSheetState extends State<_ControlModeSheet> {
  final TtsService _tts = TtsService();
  Timer? _actionResetTimer;
  String? _armedAction;

  @override
  void initState() {
    super.initState();
    _tts.speak('${widget.deviceName} 제어 방식 선택 화면입니다. 원하는 버튼을 한 번 누르면 선택되고, 한 번 더 누르면 실행됩니다.');
  }

  @override
  void dispose() {
    _actionResetTimer?.cancel();
    _tts.stop();
    super.dispose();
  }

  void _armAndRun({
    required String id,
    required String guide,
    required VoidCallback onConfirmed,
  }) {
    if (_armedAction != id) {
      setState(() {
        _armedAction = id;
      });
      HapticFeedback.mediumImpact();
      _actionResetTimer?.cancel();
      _actionResetTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _armedAction = null;
          });
        }
      });
      _tts.speak(guide);
      return;
    }

    _actionResetTimer?.cancel();
    setState(() {
      _armedAction = null;
    });
    onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF444444),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Semantics( // 기기 이름 및 제어 방식 선택 안내 Semantics 추가
            label: '${widget.deviceName} 제어 방식을 선택하세요.',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.deviceIcon, color: const Color(0xFFFFEB00), size: 32),
                const SizedBox(width: 12),
                Text(
                  widget.deviceName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const ExcludeSemantics( // 상위 Semantics에서 이미 안내하므로 중복 방지
            child: Text(
              '제어 방식을 선택하세요',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: Semantics( // 음성으로 제어 버튼 Semantics 추가
              label: '${widget.deviceName}을 음성으로 제어. ${_armedAction == 'voice' ? '선택됨. 한 번 더 탭하면 실행됩니다.' : ''}',
              button: true,
              child: ElevatedButton.icon(
                onPressed: () {
                  _armAndRun(
                    id: 'voice',
                    guide: '음성으로 제어 버튼입니다. 한 번 더 누르면 음성 인식 화면으로 이동합니다.',
                    onConfirmed: widget.onVoice,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEB00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _armedAction == 'voice' ? Colors.white : Colors.transparent,
                      width: _armedAction == 'voice' ? 2.5 : 0,
                    ),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.mic_rounded, size: 28),
                label: const Text(
                  '음성으로 제어',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 72,
            child: Semantics( // 수동으로 조작 버튼 Semantics 추가
              label: '${widget.deviceName}을 수동으로 조작. ${_armedAction == 'manual' ? '선택됨. 한 번 더 탭하면 실행됩니다.' : ''}',
              button: true,
              child: ElevatedButton.icon(
                onPressed: () {
                  _armAndRun(
                    id: 'manual',
                    guide: '수동으로 조작 버튼입니다. 한 번 더 누르면 수동 조작 화면으로 이동합니다.',
                    onConfirmed: widget.onManual,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xFFFFEB00),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: _armedAction == 'manual' ? Colors.white : const Color(0xFFFFEB00),
                      width: _armedAction == 'manual' ? 3 : 2,
                    ),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.touch_app_rounded, size: 28),
                label: const Text(
                  '수동으로 조작',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
