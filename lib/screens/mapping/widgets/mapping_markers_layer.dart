import 'package:flutter/material.dart';
import '../../../services/mapping_coordinate_service.dart';
import '../photo_mapping_view_model.dart';
import 'button_marker.dart';

/// 매핑 이미지 위에 기준점(빨간 마커, 드래그 가능)과 등록된 버튼 마커들을 그린다.
class MappingMarkersLayer extends StatelessWidget {
  const MappingMarkersLayer({
    super.key,
    required this.redMarkerPosition,
    required this.points,
    required this.imageRect,
    required this.scale,
    required this.onRedMarkerDrag,
    required this.onMarkerTap,
    required this.onMarkerLongPress,
  });

  final Offset? redMarkerPosition;
  final List<ButtonPoint> points;
  final Rect imageRect;
  final double scale;
  final ValueChanged<Offset> onRedMarkerDrag;
  final ValueChanged<int> onMarkerTap;
  final ValueChanged<int> onMarkerLongPress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (redMarkerPosition != null)
          _buildRedMarker(redMarkerPosition!),
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

  Widget _buildRedMarker(Offset normalized) {
    final local = MappingCoordinateService.localFromNormalized(
      normalized: normalized,
      imageRect: imageRect,
    );
    return Positioned(
      left: local.dx - (20 * scale),
      top: local.dy - (20 * scale),
      child: GestureDetector(
        onPanUpdate: (details) {
          if (imageRect.width <= 0 || imageRect.height <= 0) return;
          onRedMarkerDrag(
            Offset(
              (normalized.dx + details.delta.dx / imageRect.width).clamp(0.0, 1.0),
              (normalized.dy + details.delta.dy / imageRect.height).clamp(0.0, 1.0),
            ),
          );
        },
        child: Container(
          width: 40 * scale,
          height: 40 * scale,
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2 * scale),
          ),
          child: Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 20 * scale),
        ),
      ),
    );
  }
}
