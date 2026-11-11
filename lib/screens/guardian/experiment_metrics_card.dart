import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../services/accessibility_experiment_service.dart';
import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../settings/widgets/settings_form_widgets.dart';

/// 접근성 실험 지표(누적 작업·완료율·CSV 내보내기·초기화).
///
/// 당사자 검증 계획(USER_VALIDATION_PLAN)의 실측용이라 사용자 설정이 아니라 보호자
/// 설정에 둔다. 예전에는 사용자 설정 화면에 'CSV 복사', '지표 초기화'가 그대로 보여
/// 낭독기 사용자가 지나가야 했다(외부 평가).
class ExperimentMetricsCard extends StatelessWidget {
  const ExperimentMetricsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
              listenable: AccessibilityExperimentService.instance,
              builder: (context, _) {
                final exp = AccessibilityExperimentService.instance;
                Widget metricRow(String label, String value) => Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            value,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    );
                return SettingsCard(
                  children: [
                    const SizedBox(height: 8),
                    metricRow('총 작업 / 완료 / 중단',
                        '${exp.totalTasks} / ${exp.completedTasks} / ${exp.abortedTasks}'),
                    metricRow('완료율', '${exp.completionRate.toStringAsFixed(1)}%'),
                    metricRow('평균 완료 시간',
                        '${exp.averageCompletionSeconds.toStringAsFixed(1)}초'),
                    metricRow('음성 작업 (완료/평균)',
                        '${exp.voiceTasks} (${exp.voiceCompleted}/${exp.voiceAverageCompletionSeconds.toStringAsFixed(1)}초)'),
                    metricRow('수동 작업 (완료/평균)',
                        '${exp.manualTasks} (${exp.manualCompleted}/${exp.manualAverageCompletionSeconds.toStringAsFixed(1)}초)'),
                    metricRow('비상 정지 / 이중 탭 타임아웃',
                        '${exp.emergencyStops} / ${exp.doubleTapTimeouts}'),
                    const SettingsDivider(),
                    NavRow(
                      icon: Icons.copy_all_rounded,
                      title: '지표 내보내기 (CSV 복사)',
                      subtitle: '클립보드에 복사해 시트에 붙여넣기',
                      onTap: () async {
                        await Clipboard.setData(
                          ClipboardData(text: exp.buildExportCsv()),
                        );
                        TtsService().speak(
                          '지표를 CSV 형식으로 복사했어요. 메모장이나 시트에 붙여 넣으세요.',
                          source: 'ExperimentMetricsCard',
                          priority: TtsPriority.result,
                        );
                      },
                    ),
                    const SettingsDivider(),
                    NavRow(
                      icon: Icons.restart_alt_rounded,
                      title: '지표 초기화',
                      subtitle: '실험 배치를 새로 시작할 때',
                      onTap: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: AppColors.surfaceElevated,
                            title: const Text('지표 초기화',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                              '누적된 실험 지표를 모두 지웁니다. 내보내기를 먼저 했는지 확인하세요.',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('취소'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('초기화'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await exp.reset();
                          TtsService().speak(
                            '지표를 초기화했어요.',
                            source: 'ExperimentMetricsCard',
                            priority: TtsPriority.result,
                          );
                        }
                      },
                    ),
                  ],
                );
              },
            );
  }
}
