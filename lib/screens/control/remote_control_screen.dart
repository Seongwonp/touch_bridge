import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/accessibility_settings.dart';
import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/command_feedback_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/mapping_execution_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/tts_service.dart';
import '../../services/accessibility_experiment_service.dart';
import '../../services/feedback_service.dart';

import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../safety/emergency_stop_screen.dart';
import '../../theme/app_colors.dart';

class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({
    super.key,
    this.deviceId,
    this.deviceName = '스마트 기기',
  });

  final String? deviceId;
  final String deviceName;

  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen>
    with WidgetsBindingObserver {
  final TtsService _tts = TtsService();

  Timer? _actionResetTimer;
  String? _armedActionId;

  int _secondsLeft = 150;
  bool _running = false;
  String _draft = '0230';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _speak('${widget.deviceName} 제어 화면입니다. 숫자 버튼을 입력하여 시간을 설정하세요.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 백그라운드 전환 시 armed 상태 초기화 — 포어그라운드 복귀 후 의도치 않은
    // 버튼 실행을 방지한다.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.inactive) {
      _actionResetTimer?.cancel();
      if (mounted && _armedActionId != null) {
        setState(() {
          _armedActionId = null;
        });
      }
    }
  }

  Future<void> _speak(
    String message, {
    String source = 'RemoteControlScreen',
    bool interrupt = false,
    TtsPriority priority = TtsPriority.navigation,
  }) async {
    await _tts.speak(
      message,
      source: source,
      interrupt: interrupt,
      priority: priority,
    );
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
      FeedbackService.instance.vibrateSuccess();

      _actionResetTimer?.cancel();
      // WCAG 2.2.1: 이중 탭 대기(armed)는 앱 전체 20초로 통일.
      _actionResetTimer = Timer(kDoubleTapArmTimeout, () {
        if (!mounted) return;
        setState(() {
          _armedActionId = null;
        });
      });

      // arm 안내는 스크린리더가 자동으로 다시 읽어주지 않으므로 result
      // 우선순위를 명시한다(interrupt만으로는 스크린리더 활성 시 억제됨).
      // "다시 누르면 실행" 힌트를 붙여 이중 탭 패턴을 모르는 사용자도 안내받게 한다.
      await _speak(
        '$guide. 한 번 더 누르면 실행합니다.',
        interrupt: true,
        priority: TtsPriority.result,
      );
      return;
    }

    _actionResetTimer?.cancel();
    await _tts.stop();
    setState(() {
      _armedActionId = null;
    });
    FeedbackService.instance.vibrateSuccess();
    onConfirmed();
  }

  String _formatMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _updateFromDraft() {
    final min = int.parse(_draft.substring(0, 2));
    final sec = int.parse(_draft.substring(2, 4)).clamp(0, 59);
    setState(() {
      _secondsLeft = min * 60 + sec;
    });
  }

  void _appendDigit(int value) {
    if (_running) return;
    setState(() {
      _draft = (_draft.substring(1) + value.toString());
    });
    _updateFromDraft();
    // 입력 피드백은 스크린리더가 자동으로 읽어주지 않는 상태 변화 → result.
    _speak('$value 입력됨', priority: TtsPriority.result);
  }

  void _backspaceDigit() {
    if (_running) return;
    setState(() {
      _draft = '0${_draft.substring(0, 3)}';
    });
    _updateFromDraft();
    _speak('마지막 숫자 지움', priority: TtsPriority.result);
  }

  void _cancelTimer() {
    setState(() {
      _running = false;
      _draft = '0000';
      _secondsLeft = 0;
    });
    _speak('초기화되었습니다.', priority: TtsPriority.result);
  }

  bool _isSending = false;

  Future<void> _toggleStart() async {
    if (_isSending) return;
    if (_secondsLeft <= 0) {
      setState(() {
        _draft = '0030';
        _secondsLeft = 30;
      });
      _speak('30초로 설정했습니다. 시작하려면 다시 누르세요.', priority: TtsPriority.result);
      return; // 시간만 채웠을 뿐 아직 시작하지 않았으므로 다시 눌러야 한다.
    }

    if (!BleService.instance.isConnected) {
      // 이중 탭까지 마친 사용자가 무반응 상태에 빠지지 않도록 실패 earcon과
      // result 우선순위 안내를 함께 준다(스크린리더 활성 시에도 들림).
      FeedbackService.instance.playFailure();
      _speak(
        '기기가 연결되어 있지 않습니다. 보호자에게 기기 연결을 요청해 주세요.',
        priority: TtsPriority.result,
      );
      return;
    }

    final deviceId =
        widget.deviceId ?? ActiveDeviceService.instance.getActiveDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      FeedbackService.instance.playFailure();
      _speak(
        '기기를 찾지 못했습니다. 홈에서 기기를 먼저 선택해 주세요.',
        priority: TtsPriority.result,
      );
      return;
    }

    setState(() => _isSending = true);
    // 이 기기는 숫자 키패드가 아니라 프리셋 버튼(10초/30초/1분/5분/시작)만
    // 물리적으로 존재하므로, 입력한 시간을 실제 프리셋 조합으로 눌러야 한다.
    final sequence = MicrowaveCommandService.buildStartSequence(_secondsLeft);
    // buildStartSequence는 1~4초를 10초로 올리지만, 만약 actualSeconds == 0이
    // 되는 edge case가 생기면 카운트다운 화면이 즉시 완료로 보이므로 막는다.
    if (sequence.actualSeconds <= 0) {
      // 여기서 그냥 return하면 _isSending이 true로 남아 시작 버튼이 영구
      // 무반응이 된다(과거 잠재 버그) — 반드시 해제하고 나간다.
      setState(() => _isSending = false);
      _speak(
        '시간을 10초 이상 입력해 주세요.',
        interrupt: true,
        priority: TtsPriority.result,
      );
      return;
    }
    if (sequence.actualSeconds != _secondsLeft) {
      _speak(
        '${_formatMMSS(sequence.actualSeconds)}로 맞춰 시작합니다.',
        interrupt: true,
        priority: TtsPriority.result,
      );
    } else {
      _speak(
        '${_formatMMSS(_secondsLeft)} 시작합니다.',
        interrupt: true,
        priority: TtsPriority.result,
      );
    }

    try {
      final profile = await DeviceMappingService.instance.load(deviceId);
      final result = await MappingExecutionService.instance.pressSequence(
        deviceId: deviceId,
        profile: profile,
        buttonIds: sequence.buttons,
      );

      if (!mounted) return;
      if (!result.ok) {
        await CommandFeedbackService.instance.announce(
          result.toCommandResult(),
          source: 'RemoteControlScreen',
        );
        return; // 실패 시 작동 화면으로 이동하지 않는다(거짓 완료 방지).
      }

      // "성공"이 아니라 "전송됨"이다: pressSequence의 ok=true는 BLE write
      // 성공일 뿐 GRBL 확인이 아니므로, 확인됨(success) earcon을 쓰지 않는다.
      FeedbackService.instance.signalSent();
      AccessibilityExperimentService.instance.recordTaskStarted(
        TaskMode.manual,
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              EmergencyStopScreen(initialSeconds: sequence.actualSeconds),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _numberKey(int number, double rs) {
    // 숫자 입력은 하드웨어를 건드리지 않고 화면의 임시 시간 값만 바꾸며
    // 지우기로 언제든 되돌릴 수 있다. 매번 2단계 확인+20초 대기를 강제하면
    // "0230" 같은 네 자리 입력에도 안내를 계속 들어야 해 반복 사용 피로가
    // 크다. 실제 하드웨어를 움직이는 "시작"만 2단계로 유지한다.
    return Semantics(
      label: '$number 숫자 버튼',
      hint: '누르면 바로 입력됩니다',
      button: true,
      child: _ActionKey(
        borderColor: AppColors.borderDefault,
        armed: false,
        onTap: () {
          HapticFeedback.selectionClick();
          _appendDigit(number);
        },
        child: Text(
          '$number',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28 * rs,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _cancelKey(double rs) {
    final isArmed = _armedActionId == 'cancel';
    return Semantics(
      label: '취소 버튼',
      button: true,
      child: _ActionKey(
        color: const Color(0xFF1A0A0A),
        borderColor: const Color(0xFF3A1A1A),
        armed: isArmed,
        onTap: () {
          _armAndRun(id: 'cancel', guide: '취소', onConfirmed: _cancelTimer);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cancel_rounded,
              color: AppColors.emergency,
              size: 24 * rs,
            ),
            SizedBox(height: 4 * rs),
            Text(
              '취소',
              style: TextStyle(
                color: AppColors.emergency,
                fontSize: 12 * rs,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _backspaceKey(double rs) {
    // 숫자 입력과 같은 이유로 1단계(즉시 실행): 하드웨어에 영향 없고
    // 되돌릴 수 있는 로컬 편집 동작이다.
    return Semantics(
      label: '지우기 버튼',
      hint: '누르면 마지막 숫자가 지워집니다',
      button: true,
      child: _ActionKey(
        color: AppColors.surfaceElevated,
        borderColor: AppColors.borderDefault,
        armed: false,
        onTap: () {
          HapticFeedback.selectionClick();
          _backspaceDigit();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.backspace_rounded,
              color: AppColors.textTertiary,
              size: 22 * rs,
            ),
            SizedBox(height: 4 * rs),
            Text(
              '지우기',
              style: TextStyle(
                color: AppColors.textTertiary,
                fontSize: 12 * rs,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actionResetTimer?.cancel();
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TopAppBar(title: widget.deviceName, showBack: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: 20 * rs,
                vertical: 12 * rs,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (24 * rs),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '남은 시간',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13 * rs,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 8)),
                    Semantics(
                      label: '현재 시간 ${_formatMMSS(_secondsLeft)}',
                      child: Text(
                        _formatMMSS(_secondsLeft),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 72 * rs,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      crossAxisSpacing: 12 * rs,
                      mainAxisSpacing: 12 * rs,
                      childAspectRatio: 1.3, // 명도와 크기를 위해 비율 조정
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
                    SizedBox(height: ResponsiveScale.v(context, 24)),
                    SizedBox(
                      width: double.infinity,
                      height: 72 * rs,
                      child: Semantics(
                        label: '시작 버튼',
                        button: true,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _armAndRun(
                              id: 'start',
                              guide: '시작',
                              onConfirmed: _toggleStart,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16 * rs),
                              side: _armedActionId == 'start'
                                  ? const BorderSide(
                                      color: Colors.white,
                                      width: 3,
                                    )
                                  : BorderSide.none,
                            ),
                            elevation: 0,
                          ),
                          icon: Icon(Icons.play_arrow_rounded, size: 32 * rs),
                          label: Text(
                            '조리 시작',
                            style: TextStyle(
                              fontSize: 22 * rs,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16 * rs), // 하단 여백 추가
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionKey extends StatelessWidget {
  const _ActionKey({
    required this.child,
    required this.onTap,
    this.color = AppColors.surfaceElevated,
    this.borderColor = AppColors.borderDefault,
    this.armed = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final Color borderColor;
  final bool armed;

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16 * rs),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16 * rs),
          border: Border.all(
            color: armed ? Colors.white : borderColor,
            width: armed ? 3 : 1,
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}
