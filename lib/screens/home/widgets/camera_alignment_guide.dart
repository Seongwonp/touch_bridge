import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/tts_service.dart';
import '../../../services/app_logger.dart';
import '../../../theme/app_colors.dart';

/// 이미지 피커는 실시간 프레임을 앱에 제공하지 않으므로 자동 판정 대신 촬영 직전
/// 방향성 안내를 한 단계씩 음성·진동으로 전달한다.
Future<bool> showCameraAlignmentGuide(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CameraAlignmentGuideDialog(),
  );
  return result == true;
}

class _CameraAlignmentGuideDialog extends StatefulWidget {
  const _CameraAlignmentGuideDialog();

  @override
  State<_CameraAlignmentGuideDialog> createState() =>
      _CameraAlignmentGuideDialogState();
}

class _CameraAlignmentGuideDialogState
    extends State<_CameraAlignmentGuideDialog> {
  static const _steps = [
    ('기기 전체가 잘리면 뒤로 이동', '터치패드 네 모서리가 모두 들어오도록 휴대폰을 뒤로 이동하세요.'),
    ('좌우 여백 맞추기', '왼쪽 여백이 좁으면 휴대폰을 왼쪽으로, 오른쪽 여백이 좁으면 오른쪽으로 이동하세요.'),
    ('위아래 여백 맞추기', '위쪽 여백이 좁으면 위로, 아래쪽 여백이 좁으면 아래로 이동하세요.'),
    ('수평과 반사 확인', '패널 윗변과 휴대폰을 평행하게 하고 빛 반사가 버튼을 가리지 않게 기울이세요.'),
  ];

  int _index = 0;
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  Future<void> _announce() async {
    AppLogger.info('mapping.camera_guide_step', {
      'step': _index + 1,
      'total_steps': _steps.length,
    });
    HapticFeedback.selectionClick();
    await _tts.speak(
      '${_index + 1}단계. ${_steps[_index].$2}',
      interrupt: true,
      priority: TtsPriority.result,
    );
  }

  void _next() {
    if (_index == _steps.length - 1) {
      AppLogger.info('mapping.camera_guide_completed', {
        'total_steps': _steps.length,
      });
      Navigator.pop(context, true);
      return;
    }
    setState(() => _index++);
    _announce();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surfaceElevated,
    title: const Text(
      '촬영 정렬 안내',
      style: TextStyle(color: AppColors.textPrimary),
    ),
    content: Semantics(
      liveRegion: true,
      label: '${_index + 1}단계. ${_steps[_index].$2}',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _index == 0
                ? Icons.zoom_out_map_rounded
                : _index == 1
                ? Icons.swap_horiz_rounded
                : _index == 2
                ? Icons.swap_vert_rounded
                : Icons.crop_rotate_rounded,
            color: AppColors.primary,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            _steps[_index].$1,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _steps[_index].$2,
            style: const TextStyle(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () {
          AppLogger.info('mapping.camera_guide_cancelled', {
            'step': _index + 1,
          });
          Navigator.pop(context, false);
        },
        child: const Text('취소'),
      ),
      ElevatedButton(
        onPressed: _next,
        child: Text(_index == _steps.length - 1 ? '카메라 열기' : '다음 안내'),
      ),
    ],
  );
}
