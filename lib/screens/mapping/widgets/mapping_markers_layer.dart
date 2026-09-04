import 'package:flutter/material.dart';
import '../../../services/mapping_coordinate_service.dart';
import '../../../theme/app_colors.dart';
import '../photo_mapping_view_model.dart';
import 'button_marker.dart';

/// 매핑 이미지 위에 패널 모서리 4점과 등록된 버튼 마커들을 그린다.
class MappingMarkersLayer extends StatelessWidget {
  const MappingMarkersLayer({
    super.key,
    required this.calibrationCorners,
    required this.points,
    required this.imageRect,
    required this.scale,
    required this.onCalibrationCornerDrag,
    required this.onCalibrationCornerTap,
    required this.onMarkerTap,
    required this.onMarkerLongPress,
  });

  final List<Offset> calibrationCorners;
  final List<ButtonPoint> points;
  final Rect imageRect;
  final double scale;
  final void Function(int index, Offset position) onCalibrationCornerDrag;
  final ValueChanged<int> onCalibrationCornerTap;
  final ValueChanged<int> onMarkerTap;
  final ValueChanged<int> onMarkerLongPress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...calibrationCorners.asMap().entries.map(
          (entry) => _buildCalibrationMarker(entry.key, entry.value),
        ),
        ...points.asMap().entries.map((entry) {
          final idx = entry.key;
          final point = entry.value;
          final local = MappingCoordinateService.localFromNormalized(
            normalized: point.position,
            imageRect: imageRect,
          );
          return Positioned(
            left: local.dx - (20 * scale),
            top: local.dy - (20 * scale),
            child: ButtonMarker(
              index: idx,
              label: point.label,
              rs: scale,
              onTap: () => onMarkerTap(idx),
              onLongPress: () => onMarkerLongPress(idx),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCalibrationMarker(int index, Offset normalized) {
    final local = MappingCoordinateService.localFromNormalized(
      normalized: normalized,
      imageRect: imageRect,
    );
    final visualSize = 40.0 * scale;
    final hitSize = visualSize.clamp(48.0, double.infinity);
    const names = ['좌상단', '우상단', '우하단', '좌하단'];
    const colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.success,
      AppColors.warning,
    ];
    return Positioned(
      left: local.dx - (hitSize / 2),
      top: local.dy - (hitSize / 2),
      child: Semantics(
        label: '패널 ${names[index]} 모서리 ${index + 1}번. 두 번 탭하면 버튼으로 미세 조정',
        button: true,
        child: GestureDetector(
          onTap: () => onCalibrationCornerTap(index),
          onPanUpdate: (details) {
            if (imageRect.width <= 0 || imageRect.height <= 0) return;
            onCalibrationCornerDrag(
              index,
              Offset(
                (normalized.dx + details.delta.dx / imageRect.width).clamp(
                  0.0,
                  1.0,
                ),
                (normalized.dy + details.delta.dy / imageRect.height).clamp(
                  0.0,
                  1.0,
                ),
              ),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: hitSize,
            height: hitSize,
            child: Center(
              child: Container(
                width: visualSize,
                height: visualSize,
                decoration: BoxDecoration(
                  color: colors[index].withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2 * scale),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
