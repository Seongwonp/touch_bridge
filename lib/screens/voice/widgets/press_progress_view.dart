import 'package:flutter/material.dart';

import '../../../services/single_tap_stop_controller.dart';
import '../../../theme/app_colors.dart';

/// 버튼을 누르는 중 / 전달 완료 화면.
///
/// 실행 중에는 화면 아래에 **한 번 탭으로 동작하는 비상 정지 버튼**을 항상 둔다.
/// 확인창·두 번째 탭·길게 누르기가 없다. 정지 결과는 [SingleTapStopController]의
/// `lastOutcome`으로 받아 ACK 확인 / 미확인 / 실패를 구분해 보여준다.
/// 위젯 테스트가 가능하도록 화면 상태는 전부 인자로 받는다.
class PressProgressView extends StatelessWidget {
  const PressProgressView({
    super.key,
    required this.label,
    required this.done,
    required this.stopController,
    required this.onStopTap,
    this.awaitingStopResolution = false,
    this.scale = 1.0,
  });

  /// 실행 시퀀스는 끝났지만 정지가 확인되지 않은(미확인·실패·요청 중) 상태.
  /// 진행 표시 대신 경고 아이콘을 보이고 재시도 버튼을 유지한다.
  final bool awaitingStopResolution;

  /// "…누르는 중입니다" / "…전달했습니다".
  final String label;

  /// true면 전달 완료 상태(정지 버튼을 보이지 않는다).
  final bool done;

  final SingleTapStopController stopController;

  /// 단일 탭 정지. 위젯은 중복 탭을 [SingleTapStopController.inFlight]로 막는다.
  final VoidCallback onStopTap;

  final double scale;

  static const stopButtonKey = Key('press_progress_single_tap_stop');

  @override
  Widget build(BuildContext context) {
    final rs = scale;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24 * rs),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 140 * rs,
            height: 140 * rs,
            child: done
                ? Icon(Icons.check_circle, size: 128 * rs, color: AppColors.success)
                : awaitingStopResolution
                    ? Icon(Icons.warning_amber_rounded, size: 128 * rs, color: AppColors.warning)
                    : CircularProgressIndicator(strokeWidth: 8 * rs, color: AppColors.primary),
          ),
          SizedBox(height: 32 * rs),
          Semantics(
            liveRegion: true,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: done ? AppColors.success : AppColors.primary,
                fontSize: 30 * rs,
                fontWeight: FontWeight.w900,
                height: 1.25,
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(height: 16 * rs),
          Text(
            done
                ? '잠시 후 음성 화면으로 돌아갑니다.'
                : awaitingStopResolution
                    ? '기기가 멈췄는지 확인되지 않았습니다. 기기 상태를 확인하고, 필요하면 아래 버튼으로 다시 정지하세요.'
                    : '기기가 버튼을 누르고 있습니다. 멈추려면 아래 버튼을 한 번 누르세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 17 * rs,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          if (!done) ...[
            SizedBox(height: 28 * rs),
            ListenableBuilder(
              listenable: stopController,
              builder: (context, _) => _buildStopArea(rs),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStopArea(double rs) {
    final inFlight = stopController.inFlight;
    final outcome = stopController.lastOutcome;
    final retry = stopController.canRetry;

    final String buttonLabel;
    if (inFlight) {
      buttonLabel = '정지 요청 중';
    } else if (retry) {
      buttonLabel = '다시 정지';
    } else {
      buttonLabel = '즉시 정지';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (outcome != null)
          Padding(
            padding: EdgeInsets.only(bottom: 16 * rs),
            child: Semantics(
              liveRegion: true,
              child: Text(
                outcome.message,
                key: const Key('press_progress_stop_outcome'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: outcome.acknowledged ? AppColors.success : AppColors.warning,
                  fontSize: 18 * rs,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ),
          ),
        // FilledButton이 버튼 역할·활성 상태를 스스로 노출하고 자식(라벨 Text)의
        // 시맨틱을 자기 노드로 병합한다. 그래서 hint는 바깥이 아니라 **버튼 안쪽**
        // 라벨에 붙여야 버튼 노드에 남는다(바깥 Semantics의 hint는 버려졌다 —
        // 위젯 테스트로 확인).
        Semantics(
          label: buttonLabel,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 88 * rs, minWidth: double.infinity),
            child: FilledButton.icon(
              key: stopButtonKey,
              onPressed: inFlight ? null : onStopTap,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emergency,
                disabledBackgroundColor: AppColors.emergency.withValues(alpha: 0.45),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20 * rs)),
              ),
              icon: Icon(inFlight ? Icons.hourglass_top : Icons.pan_tool, size: 32 * rs),
              label: Semantics(
                hint: inFlight ? '정지 명령을 보내는 중입니다' : '한 번 누르면 바로 정지 명령을 보냅니다',
                child: Text(
                  buttonLabel,
                  style: TextStyle(fontSize: 24 * rs, fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
