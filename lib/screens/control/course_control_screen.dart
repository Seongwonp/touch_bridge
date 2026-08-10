import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/command_feedback_service.dart';
import '../../services/course_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/tts_service.dart';
import '../../services/feedback_service.dart';
import '../../services/mapping_execution_service.dart';
import '../../services/microwave_command_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import '../safety/emergency_stop_screen.dart';

class CourseControlScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;

  const CourseControlScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  @override
  State<CourseControlScreen> createState() => _CourseControlScreenState();
}

class _CourseControlScreenState extends State<CourseControlScreen> {
  final TtsService _tts = TtsService();
  bool _isExecuting = false;

  // 2단계 탭(첫 탭 안내 → 둘째 탭 실행) 상태
  String? _armedCourseName;
  Timer? _armResetTimer;

  @override
  void initState() {
    super.initState();
    _tts.speak('코스 선택 화면입니다. 원하시는 간편 조리 코스를 선택해 주세요.');
  }

  @override
  void dispose() {
    _armResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _runCourse(Course course) async {
    if (_isExecuting) return;
    if (!BleService.instance.isConnected) {
      _tts.speak('기기가 연결되어 있지 않습니다. 보호자에게 기기 연결을 요청해 주세요.');
      return;
    }

    // 2단계 탭: 첫 탭은 안내만, 둘째 탭에서 실제 코스를 실행한다(오작동 방지).
    if (_armedCourseName != course.name) {
      setState(() => _armedCourseName = course.name);
      FeedbackService.instance.vibrateSuccess();
      _armResetTimer?.cancel();
      _armResetTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) setState(() => _armedCourseName = null);
      });
      _tts.speak('${course.name} 코스. 다시 누르면 시작합니다.', interrupt: true);
      return;
    }

    _armResetTimer?.cancel();
    setState(() => _armedCourseName = null);
    await _executeCourse(course);
  }

  Future<void> _executeCourse(Course course) async {
    setState(() => _isExecuting = true);
    _tts.speak('${course.name} 코스를 시작합니다.', interrupt: true);
    FeedbackService.instance.vibrateSuccess();

    try {
      final profile = await DeviceMappingService.instance.load(widget.deviceId);

      final result = await MappingExecutionService.instance.pressSequence(
        deviceId: widget.deviceId,
        profile: profile,
        buttonIds: course.buttonIds,
        betweenPressDelay: const Duration(milliseconds: 1000),
      );
      if (!result.ok) {
        await CommandFeedbackService.instance.announce(
          result.toCommandResult(),
          source: 'CourseControlScreen',
        );
        return;
      }

      // "성공"이 아니라 "전송됨"이다: pressSequence의 ok=true는 BLE write
      // 성공일 뿐 GRBL 확인이 아니므로, 확인됨(success) earcon을 쓰지 않는다.
      FeedbackService.instance.signalSent();
      if (!mounted) return;

      // 코스의 실제 소요 시간을 프리셋 버튼 구성으로 계산한다. 시간 프리셋이
      // 없는 코스(예: 우유 데우기)는 0으로 나와 "타이머 완료" 화면으로
      // 넘기면 실제로는 계속 작동 중인데 "끝났다"고 거짓 안내하게 된다.
      final seconds = MicrowaveCommandService.calculateSeconds(
        course.buttonIds,
      );
      if (seconds > 0) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmergencyStopScreen(
              deviceName: widget.deviceName,
              initialSeconds: seconds,
            ),
          ),
        );
      } else {
        await _tts.speak(
          '${course.name} 코스를 시작했습니다. 소요 시간을 알 수 없어 타이머는 표시하지 않습니다. '
          '멈추려면 비상 정지를 사용하세요.',
          interrupt: true,
        );
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      _tts.speak('코스를 실행하지 못했습니다. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _isExecuting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final courses = CourseService.instance.getCoursesForDevice('microwave');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TopAppBar(title: '간편 코스', showBack: true),
      body: _isExecuting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 24 * rs),
                  Text(
                    '하드웨어가 버튼을 누르는 중입니다...',
                    style: TextStyle(color: Colors.white, fontSize: 16 * rs),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: EdgeInsets.all(20 * rs),
              itemCount: courses.length,
              itemBuilder: (context, index) {
                final c = courses[index];
                final armed = _armedCourseName == c.name;
                return Semantics(
                  button: true,
                  label: '${c.name} 코스',
                  hint: armed ? '다시 누르면 시작합니다' : '한 번 누르면 안내합니다',
                  child: Card(
                    color: armed
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : const Color(0xFF1A1A1A),
                    margin: EdgeInsets.only(bottom: 16 * rs),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16 * rs),
                      side: BorderSide(
                        color: armed ? Colors.white : const Color(0xFF333333),
                        width: armed ? 2.5 : 1,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(16 * rs),
                      leading: Container(
                        padding: EdgeInsets.all(12 * rs),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.stars_rounded,
                          color: AppColors.primary,
                          size: 28 * rs,
                        ),
                      ),
                      title: Text(
                        c.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18 * rs,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          c.description,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14 * rs,
                          ),
                        ),
                      ),
                      onTap: () => _runCourse(c),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
