import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/course_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/tts_service.dart';
import '../../services/feedback_service.dart';
import '../../services/mapping_execution_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tts.speak('코스 선택 화면입니다. 원하시는 간편 조리 코스를 선택해 주세요.');
  }

  Future<void> _runCourse(Course course) async {
    if (_isExecuting) return;
    if (!BleService.instance.isConnected) {
      _tts.speak('블루투스 연결이 필요합니다.');
      return;
    }

    setState(() => _isExecuting = true);
    _tts.speak('${course.name} 코스를 시작합니다.');
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
        FeedbackService.instance.playFailure();
        _tts.speak(result.userMessage);
        return;
      }

      FeedbackService.instance.playSuccess();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmergencyStopScreen(
              deviceName: widget.deviceName,
              initialSeconds: 0, // 코스별 시간 계산 로직 추가 가능
            ),
          ),
        );
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
                return Card(
                  color: const Color(0xFF1A1A1A),
                  margin: EdgeInsets.only(bottom: 16 * rs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16 * rs),
                    side: const BorderSide(color: Color(0xFF333333)),
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
                );
              },
            ),
    );
  }
}
