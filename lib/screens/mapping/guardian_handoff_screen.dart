import 'package:flutter/material.dart';

import '../../models/handoff_report.dart';
import '../../services/accessibility_settings.dart';
import '../../services/guardian_handoff_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';

/// 보호자가 기기 설정(매핑/등록)을 마친 직후 보여주는 인수 체크리스트 화면.
///
/// "저장 완료" 스낵바 한 줄로 끝나던 흐름을 대체한다. 여기서 확인하는
/// 항목은 소프트웨어로 검증 가능한 것뿐이며(등록/연결/매핑/명령 생성),
/// 물리적으로 버튼이 정확히 눌리는지는 여전히 좌표 테스트로 직접 확인해야
/// 한다는 점을 화면에 명시한다.
class GuardianHandoffScreen extends StatefulWidget {
  const GuardianHandoffScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
  });

  final String deviceId;
  final String deviceName;

  @override
  State<GuardianHandoffScreen> createState() => _GuardianHandoffScreenState();
}

class _GuardianHandoffScreenState extends State<GuardianHandoffScreen> {
  final TtsService _tts = TtsService();
  HandoffReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tts.speak(
      '$deviceNameText 인수 점검입니다. 확인 중입니다.',
      source: 'GuardianHandoffScreen',
      interrupt: true,
    );
    _run();
  }

  String get deviceNameText => widget.deviceName;

  Future<void> _run() async {
    final report = await GuardianHandoffService.instance.run(
      deviceId: widget.deviceId,
    );
    if (!mounted) return;
    setState(() {
      _report = report;
      _loading = false;
    });
    await _tts.speak(
      report.spokenSummary,
      source: 'GuardianHandoffScreen',
      interrupt: true,
    );
  }

  Future<void> _finishHandoff() async {
    AccessibilitySettings.instance.setGuardianModeEnabled(false);
    await _tts.speak(
      '사용자 모드로 전환합니다.',
      source: 'GuardianHandoffScreen',
      interrupt: true,
    );
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _keepGuardianMode() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final report = _report;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TopAppBar(title: '${widget.deviceName} 인수 점검', showBack: false),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(20 * rs),
          child: _loading || report == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      liveRegion: true,
                      label: report.spokenSummary,
                      child: Container(
                        padding: EdgeInsets.all(16 * rs),
                        decoration: BoxDecoration(
                          color: report.allPassed
                              ? AppColors.success.withValues(alpha: 0.12)
                              : AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16 * rs),
                          border: Border.all(
                            color: report.allPassed
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              report.allPassed
                                  ? Icons.check_circle_rounded
                                  : Icons.error_outline_rounded,
                              color: report.allPassed
                                  ? AppColors.success
                                  : AppColors.warning,
                              size: 28 * rs,
                            ),
                            SizedBox(width: 12 * rs),
                            Expanded(
                              child: Text(
                                report.allPassed
                                    ? '점검을 모두 통과했습니다'
                                    : '${report.passCount}/${report.items.length}개 항목 확인됨',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16 * rs,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16 * rs),
                    Expanded(
                      child: ListView.separated(
                        itemCount: report.items.length,
                        separatorBuilder: (_, _) => SizedBox(height: 8 * rs),
                        itemBuilder: (context, index) {
                          final item = report.items[index];
                          return Semantics(
                            label:
                                '${item.label}. ${item.passed ? "통과" : "확인 필요: ${item.detail ?? ""}"}',
                            child: Container(
                              padding: EdgeInsets.all(14 * rs),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(12 * rs),
                                border: Border.all(
                                  color: AppColors.borderDefault,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    item.passed
                                        ? Icons.check_circle_rounded
                                        : Icons.error_outline_rounded,
                                    color: item.passed
                                        ? AppColors.success
                                        : AppColors.warning,
                                    size: 20 * rs,
                                  ),
                                  SizedBox(width: 10 * rs),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.label,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 14 * rs,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        if (item.detail != null) ...[
                                          SizedBox(height: 4 * rs),
                                          Text(
                                            item.detail!,
                                            style: TextStyle(
                                              color: AppColors.textTertiary,
                                              fontSize: 12 * rs,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 12 * rs),
                    Text(
                      '참고: 이 점검은 설정 오류만 확인합니다. 버튼이 실제로 정확히'
                      ' 눌리는지는 좌표 테스트로 직접 확인해야 합니다.',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 12 * rs,
                      ),
                    ),
                    SizedBox(height: 16 * rs),
                    SizedBox(
                      width: double.infinity,
                      height: 56 * rs,
                      child: ElevatedButton(
                        onPressed: _finishHandoff,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14 * rs),
                          ),
                        ),
                        child: Text(
                          '완료 — 사용자 모드로 전환',
                          style: TextStyle(
                            fontSize: 16 * rs,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8 * rs),
                    TextButton(
                      onPressed: _keepGuardianMode,
                      child: const Text(
                        '설정을 더 진행할게요 (보호자 모드 유지)',
                        style: TextStyle(color: AppColors.textTertiary),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
