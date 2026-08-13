import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../widgets/responsive_scale.dart';
import '../../voice/voice_listening_screen.dart';
import '../../control/remote_control_screen.dart';
import '../../control/image_control_screen.dart';
import '../../control/course_control_screen.dart';
import '../../mapping/manual_mapping_screen.dart';
import '../../../services/device_mapping_service.dart';
import '../../../services/ble_service.dart';
import '../../../services/accessibility_settings.dart';
import '../../../services/active_device_service.dart';
import '../../../services/feedback_service.dart';
import '../../../services/tts_service.dart';
import '../../../theme/app_colors.dart';

class ControlModeSheet extends StatefulWidget {
  const ControlModeSheet({
    super.key,
    required this.deviceName,
    required this.deviceId,
    required this.deviceIcon,
  });

  final String deviceName;
  final String deviceId;
  final IconData deviceIcon;

  @override
  State<ControlModeSheet> createState() => _ControlModeSheetState();
}

class _ControlModeSheetState extends State<ControlModeSheet> {
  final TtsService _tts = TtsService();
  bool _isConnecting = false;
  bool _connectionFailed = false;

  // 2단계 탭(첫 탭 안내 → 둘째 탭 실행) 상태
  String? _armedActionId;
  Timer? _actionResetTimer;

  // BottomSheet 열릴 때 첫 버튼으로 포커스를 이동해 스크린리더가 즉시 탐색 가능하게 함.
  final FocusNode _firstButtonFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstButtonFocus.requestFocus();
    });
    // 여는 즉시 "무엇을 선택했고 어떤 제어가 있는지" 안내한다.
    // 좌표 매핑은 보호자 설정 기능이라 보호자 모드일 때만 안내/노출한다.
    final guardian = AccessibilitySettings.instance.guardianModeEnabled;
    final options = guardian
        ? '음성으로 제어, 이미지로 제어, 간편 코스, 숫자 패드, 좌표 매핑이 있습니다.'
        : '음성으로 제어, 이미지로 제어, 간편 코스, 숫자 패드가 있습니다.';
    _tts.speak(
      '${widget.deviceName}를 선택했습니다. 제어 방식을 선택하세요. $options '
      '각 버튼은 한 번 누르면 안내하고, 다시 누르면 실행합니다.',
      source: 'ControlModeSheet',
      interrupt: true,
    );
    _autoConnectBle();
  }

  @override
  void dispose() {
    _actionResetTimer?.cancel();
    _firstButtonFocus.dispose();
    super.dispose();
  }

  Future<void> _autoConnectBle() async {
    final bleId = ActiveDeviceService.instance.getActiveBleId();
    if (bleId == null || bleId.isEmpty) return;

    if (BleService.instance.isConnected &&
        BleService.instance.connectedDeviceId == bleId) {
      return;
    }

    setState(() {
      _isConnecting = true;
      _connectionFailed = false;
    });

    // 성공 시에는 음성으로 알리지 않는다(선택 안내와 겹치지 않도록). 실패만 안내.
    final ok = await BleService.instance.ensureConnected(bleId);

    if (mounted) {
      setState(() {
        _isConnecting = false;
        _connectionFailed = !ok;
      });
      if (!ok) {
        _tts.speak(
          '연결에 실패했습니다. 하드웨어가 켜져 있는지 확인해 주세요.',
          source: 'ControlModeSheet',
          interrupt: true,
        );
      }
    }
  }

  /// 첫 탭: 안내 + 햅틱, 둘째 탭(4초 이내): 실행.
  Future<void> _armAndRun({
    required String id,
    required String guide,
    required VoidCallback onConfirmed,
  }) async {
    if (_armedActionId != id) {
      setState(() => _armedActionId = id);
      FeedbackService.instance.vibrateSuccess();
      _actionResetTimer?.cancel();
      _actionResetTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) setState(() => _armedActionId = null);
      });
      await _tts.speak(guide, source: 'ControlModeSheet', interrupt: true);
      return;
    }
    _actionResetTimer?.cancel();
    await _tts.stop();
    if (mounted) setState(() => _armedActionId = null);
    HapticFeedback.selectionClick();
    onConfirmed();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final guardianMode = AccessibilitySettings.instance.guardianModeEnabled;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28 * rs)),
        border: const Border(top: BorderSide(color: AppColors.borderDefault)),
      ),
      padding: EdgeInsets.fromLTRB(24 * rs, 16 * rs, 24 * rs, 32 * rs),
      child: SingleChildScrollView(
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
            SizedBox(height: ResponsiveScale.v(context, 20)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.deviceIcon,
                  color: AppColors.primary,
                  size: 32 * rs,
                ),
                SizedBox(width: 12 * rs),
                Flexible(
                  child: Text(
                    widget.deviceName,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22 * rs,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            // liveRegion: true — 연결 중/실패 전환을 스크린리더가 자동으로
            // 안내한다(스크린리더 활성 시 navigation 우선순위 TTS는 억제되므로
            // 이 상태 변화를 알 다른 경로가 필요하다).
            if (_isConnecting) ...[
              SizedBox(height: ResponsiveScale.v(context, 12)),
              Semantics(
                liveRegion: true,
                label: '블루투스 연결 중',
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '블루투스 연결 중...',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ] else if (_connectionFailed) ...[
              SizedBox(height: ResponsiveScale.v(context, 12)),
              Semantics(
                liveRegion: true,
                label: '연결 실패. 재시도하려면 재시도 버튼을 누르세요.',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Colors.redAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '연결 실패',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    ),
                    TextButton(
                      onPressed: _autoConnectBle,
                      child: const Text(
                        '재시도',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: ResponsiveScale.v(context, 8)),
            Text(
              '한 번 누르면 안내, 다시 누르면 실행',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 14 * rs,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 20)),
            _buildActionButton(
              rs: rs,
              icon: Icons.mic_rounded,
              label: '음성으로 제어',
              hint: '말로 명령하면 기기를 조작합니다',
              armed: _armedActionId == 'voice',
              focusNode: _firstButtonFocus,
              onPressed: () => _armAndRun(
                id: 'voice',
                guide: '음성으로 제어. 다시 누르면 음성 제어를 시작합니다.',
                onConfirmed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VoiceListeningScreen(
                        deviceId: widget.deviceId,
                        deviceName: widget.deviceName,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 12)),
            _buildActionButton(
              rs: rs,
              icon: Icons.image_search_rounded,
              label: '이미지로 제어',
              hint: '버튼 그림을 눌러 조작합니다',
              armed: _armedActionId == 'image',
              onPressed: () => _armAndRun(
                id: 'image',
                guide: '이미지로 제어. 다시 누르면 이미지 제어를 시작합니다.',
                onConfirmed: () async {
                  final nav = Navigator.of(context);
                  nav.pop();
                  final profile = await DeviceMappingService.instance.load(
                    widget.deviceId,
                  );
                  nav.push(
                    MaterialPageRoute(
                      builder: (_) => ImageControlScreen(
                        deviceId: widget.deviceId,
                        deviceName: widget.deviceName,
                        imagePath: profile.imagePath,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 12)),
            _buildActionButton(
              rs: rs,
              icon: Icons.auto_awesome_motion_rounded,
              label: '간편 코스',
              hint: '자주 쓰는 동작을 한 번에 실행합니다',
              armed: _armedActionId == 'course',
              onPressed: () => _armAndRun(
                id: 'course',
                guide: '간편 코스. 다시 누르면 간편 코스를 시작합니다.',
                onConfirmed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CourseControlScreen(
                        deviceId: widget.deviceId,
                        deviceName: widget.deviceName,
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 12)),
            _buildActionButton(
              rs: rs,
              icon: Icons.numbers_rounded,
              label: '숫자 패드',
              hint: '숫자 버튼으로 직접 입력합니다',
              armed: _armedActionId == 'keypad',
              onPressed: () => _armAndRun(
                id: 'keypad',
                guide: '숫자 패드. 다시 누르면 숫자 패드를 엽니다.',
                onConfirmed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RemoteControlScreen(
                        deviceId: widget.deviceId,
                        deviceName: widget.deviceName,
                      ),
                    ),
                  );
                },
              ),
            ),
            // 좌표 매핑은 보호자 설정 기능 → 보호자 모드일 때만 노출.
            if (guardianMode) ...[
              SizedBox(height: ResponsiveScale.v(context, 12)),
              _buildActionButton(
                rs: rs,
                icon: Icons.settings_overscan_rounded,
                label: '좌표 매핑 (보호자용)',
                hint: '버튼 위치를 다시 설정합니다. 보호자용 설정입니다',
                armed: _armedActionId == 'mapping',
                onPressed: () => _armAndRun(
                  id: 'mapping',
                  guide: '좌표 매핑. 보호자용 설정입니다. 다시 누르면 엽니다.',
                  onConfirmed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManualMappingScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required double rs,
    required IconData icon,
    required String label,
    required String hint,
    required VoidCallback onPressed,
    required bool armed,
    FocusNode? focusNode,
  }) {
    // 노란 강조 = "지금 선택(대기)된 버튼". 기본은 모든 버튼이 동일한 어두운 스타일.
    final bg = armed ? AppColors.primary : AppColors.surface;
    final fg = armed ? Colors.black : AppColors.primary;
    // MergeSemantics + hint: 버튼 자체 라벨(Text)과 힌트를 하나의 노드로 합쳐
    // 스크린리더가 라벨을 중복해서 읽지 않게 한다.
    return MergeSemantics(
      child: Semantics(
        hint: armed ? '다시 누르면 실행합니다. $hint' : hint,
        child: SizedBox(
          width: double.infinity,
          height: 64 * rs,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            focusNode: focusNode,
            style: ElevatedButton.styleFrom(
              backgroundColor: bg,
              foregroundColor: fg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16 * rs),
                // 대기(armed) 상태는 두꺼운 흰색 테두리로 저시력 사용자에게도 표시.
                side: armed
                    ? const BorderSide(color: Colors.white, width: 3)
                    : BorderSide(color: AppColors.primary, width: 1.5 * rs),
              ),
              elevation: 0,
            ),
            icon: Icon(icon, size: 24 * rs),
            label: Text(
              armed ? '$label — 다시 누르면 실행' : label,
              style: TextStyle(fontSize: 18 * rs, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ),
    );
  }
}
