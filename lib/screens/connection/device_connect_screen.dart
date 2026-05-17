// TODO(hardware): BleService.scan() 결과로 _statusCard() 상태 동적 업데이트
// TODO(hardware): 블루투스 연결 버튼 → BleService.connect() 호출
// TODO(hardware): NFC 태그 → NFC 패키지로 ESP32 디바이스 ID 읽기
// TODO(hardware): 수동 입력 → IP/MAC 주소 입력 다이얼로그 → BleService.connect()

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart'; // TODO(hardware): BLE 연동 시 활성화
import 'qr_scan_screen.dart';

int _iconCodePointForType(String type) {
  return switch (type.toLowerCase()) {
    'microwave'                     => Icons.microwave_rounded.codePoint,
    'washer' || 'laundry'           => Icons.local_laundry_service_rounded.codePoint,
    'air' || 'air_purifier'         => Icons.air_rounded.codePoint,
    'ac' || 'aircon' || 'air_cond'  => Icons.ac_unit_rounded.codePoint,
    'light' || 'lamp'               => Icons.light_mode_rounded.codePoint,
    'tv'                            => Icons.tv_rounded.codePoint,
    'fridge' || 'refrigerator'      => Icons.kitchen_rounded.codePoint,
    _                               => Icons.devices_rounded.codePoint,
  };
}

class DeviceConnectScreen extends StatelessWidget {
  const DeviceConnectScreen({super.key});

  static const _prefKeyDevices = 'home_devices';

  static const _iconOptions = [
    (label: '전자레인지', icon: Icons.microwave_rounded,               type: 'microwave'),
    (label: '세탁기',    icon: Icons.local_laundry_service_rounded,   type: 'washer'),
    (label: '공기청정기', icon: Icons.air_rounded,                    type: 'air'),
    (label: '에어컨',    icon: Icons.ac_unit_rounded,                 type: 'ac'),
    (label: '전등',      icon: Icons.light_mode_rounded,              type: 'light'),
    (label: 'TV',        icon: Icons.tv_rounded,                      type: 'tv'),
    (label: '냉장고',    icon: Icons.kitchen_rounded,                 type: 'fridge'),
    (label: '기타',      icon: Icons.devices_rounded,                 type: ''),
  ];

  Future<void> _registerDevice(
    BuildContext context, {
    required String name,
    required String type,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefKeyDevices);
    final devices = jsonStr != null
        ? (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>()
        : <Map<String, dynamic>>[];

    if (devices.any((d) => d['name'] == name)) {
      if (context.mounted) {
        TtsService().speak('$name 기기는 이미 등록되어 있습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name 기기는 이미 등록되어 있습니다.'),
            backgroundColor: const Color(0xFFFFB020),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    devices.add({
      'name': name,
      'status': '작동 대기 중',
      'iconCodePoint': _iconCodePointForType(type),
    });
    await prefs.setString(_prefKeyDevices, jsonEncode(devices));

    if (context.mounted) {
      TtsService().speak('$name 기기가 홈에 추가되었습니다.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name 기기가 홈에 추가되었습니다.'),
          backgroundColor: const Color(0xFF00FF88),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showRegisterDialog(
    BuildContext context, {
    required String initialName,
    required String initialType,
  }) async {
    final nameCtrl = TextEditingController(text: initialName);
    int selectedIconIndex = _iconOptions.indexWhere((o) => o.type == initialType);
    if (selectedIconIndex < 0) selectedIconIndex = _iconOptions.length - 1; // 기타

    TtsService().speak(
      '등록된 기기가 없습니다. 기기 이름과 종류를 확인하고 등록 버튼을 눌러주세요.',
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            '기기 등록',
            style: TextStyle(color: Color(0xFFFFEB00), fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFB020),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB020)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFFFFB020), size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '등록된 모델 정보가 없습니다.\n이름과 종류를 직접 입력해 주세요.',
                          style: TextStyle(color: Color(0xFFFFB020), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
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
                  children: List.generate(_iconOptions.length, (i) {
                    final opt = _iconOptions[i];
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
                            Icon(
                              opt.icon,
                              color: selected ? const Color(0xFFFFEB00) : const Color(0xFF888888),
                              size: 24,
                            ),
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
                Navigator.of(ctx).pop();
                await _registerDevice(
                  context,
                  name: name,
                  type: _iconOptions[selectedIconIndex].type,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFEB00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('등록', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceholder(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 기능은 다음 단계에서 연결됩니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
    TtsService().speak('$label 기능은 다음 단계에서 연결됩니다.'); // TTS 안내 추가
  }

  Widget _statusCard() {
    return Semantics( // 상태 카드 Semantics 추가
      label: 'ESP32 Smart Hub, 연결 가능한 기기 감지됨',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF00FF88),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESP32 Smart Hub',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '연결 가능한 기기 감지됨',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00FF88),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool highlighted,
  }) {
    return Semantics( // 옵션 카드 Semantics 추가
      label: '$title. $subtitle. 버튼',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: highlighted ? const Color(0xFFFFEB00) : const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? Colors.transparent : const Color(0xFF2A2A2A),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? Colors.black.withValues(alpha: 0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: highlighted
                        ? null
                        : Border.all(color: const Color(0xFF333333)),
                  ),
                  child: Icon(
                    icon,
                    color: highlighted ? Colors.black : const Color(0xFFFFEB00),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: highlighted ? Colors.black : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: highlighted
                              ? Colors.black.withValues(alpha: 0.6)
                              : const Color(0xFF888888),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: highlighted
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFF555555),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallAction({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics( // 작은 액션 Semantics 추가
        label: '$title 버튼',
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF888888), size: 22),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
              child: Semantics( // 앱 타이틀 Semantics 추가
                label: 'Touch Bridge 앱',
                child: const Row(
                  children: [
                    Text(
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
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '기기 연결',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '기기를 연결하여 제어를 시작하세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF888888),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _statusCard(),
                    const SizedBox(height: 12),
                    _optionCard(
                      context: context,
                      icon: Icons.qr_code_scanner_rounded,
                      title: 'QR 코드 스캔',
                      subtitle: '허브의 QR을 촬영하여 즉시 연결',
                      highlighted: true,
                      onTap: () async {
                        TtsService().speak('QR 코드 스캔 화면으로 이동합니다.');
                        final result = await Navigator.of(context).push<Map<String, String>>(
                          MaterialPageRoute(builder: (_) => const QrScanScreen()),
                        );
                        if (result != null && context.mounted) {
                          final name = result['name'] ?? '알 수 없는 기기';
                          final type = result['type'] ?? '';

                          // 홈 기기 목록에 없는 기기면 등록 다이얼로그 표시
                          final prefs = await SharedPreferences.getInstance();
                          final jsonStr = prefs.getString(_prefKeyDevices);
                          final devices = jsonStr != null
                              ? (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>()
                              : <Map<String, dynamic>>[];
                          final alreadyExists = devices.any((d) => d['name'] == name);

                          if (!alreadyExists && context.mounted) {
                            await _showRegisterDialog(context, initialName: name, initialType: type);
                          } else if (context.mounted) {
                            TtsService().speak('$name 기기가 이미 등록되어 있습니다.');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$name 기기는 이미 등록되어 있습니다.'),
                                backgroundColor: const Color(0xFFFFB020),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _optionCard(
                      context: context,
                      icon: Icons.bluetooth_rounded,
                      title: '블루투스 연결',
                      subtitle: '주변 기기 자동 검색 및 페어링',
                      highlighted: false,
                      onTap: () {
        // TODO(hardware): BleService.instance.scan() 호출 → 결과 목록 BottomSheet 표시
        // TODO(hardware): 선택 시 BleService.instance.connect(deviceId)
        _showPlaceholder(context, '블루투스 연결');
      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _smallAction(
                          context: context,
                          title: 'NFC 태그',
                          icon: Icons.nfc_rounded,
                          onTap: () => _showPlaceholder(context, 'NFC 태그'),
                        ),
                        const SizedBox(width: 10),
                        _smallAction(
                          context: context,
                          title: '수동 입력',
                          icon: Icons.keyboard_rounded,
                          onTap: () => _showPlaceholder(context, '수동 입력'),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Semantics( // 도움말 텍스트 Semantics 추가
                      label: '연결에 문제가 있나요? 도움말 보기 버튼',
                      button: true,
                      child: Center(
                        child: Text(
                          '연결에 문제가 있나요? 도움말 보기',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary.withValues(alpha: 0.7),
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
    );
  }
}
