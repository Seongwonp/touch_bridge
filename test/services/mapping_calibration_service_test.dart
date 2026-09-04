import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/services/device_mapping_service.dart';
import 'package:touch_bridge/services/mapping_calibration_service.dart';

void main() {
  const rectangularCalibration = PanelCalibration(
    imageFingerprint: 'photo-a',
    corners: [
      PanelCalibrationPoint(
        imageX: 0.1,
        imageY: 0.2,
        machineXmm: 10,
        machineYmm: 20,
      ),
      PanelCalibrationPoint(
        imageX: 0.9,
        imageY: 0.2,
        machineXmm: 90,
        machineYmm: 20,
      ),
      PanelCalibrationPoint(
        imageX: 0.9,
        imageY: 0.8,
        machineXmm: 90,
        machineYmm: 80,
      ),
      PanelCalibrationPoint(
        imageX: 0.1,
        imageY: 0.8,
        machineXmm: 10,
        machineYmm: 80,
      ),
    ],
  );

  test('4점 캘리브레이션은 사진 중심을 실제 패널 중심 mm로 변환한다', () {
    final result = MappingCalibrationService.calculate(
      calibration: rectangularCalibration,
      buttonPositions: {'BT-01': (x: 0.5, y: 0.5)},
    );

    expect(result.isValid, isTrue);
    expect(result.machinePositions['BT-01']?.xMm, closeTo(50, 0.0001));
    expect(result.machinePositions['BT-01']?.yMm, closeTo(50, 0.0001));
  });

  test('원근 왜곡된 사각형도 네 모서리와 중심을 안정적으로 변환한다', () {
    const calibration = PanelCalibration(
      imageFingerprint: 'photo-perspective',
      corners: [
        PanelCalibrationPoint(
          imageX: 0.2,
          imageY: 0.1,
          machineXmm: 0,
          machineYmm: 0,
        ),
        PanelCalibrationPoint(
          imageX: 0.85,
          imageY: 0.2,
          machineXmm: 100,
          machineYmm: 0,
        ),
        PanelCalibrationPoint(
          imageX: 0.9,
          imageY: 0.9,
          machineXmm: 100,
          machineYmm: 50,
        ),
        PanelCalibrationPoint(
          imageX: 0.1,
          imageY: 0.8,
          machineXmm: 0,
          machineYmm: 50,
        ),
      ],
    );

    final result = MappingCalibrationService.calculate(
      calibration: calibration,
      buttonPositions: {
        'BT-01': (x: 0.2, y: 0.1),
        'BT-02': (x: 0.85, y: 0.2),
        'BT-03': (x: 0.9, y: 0.9),
        'BT-04': (x: 0.1, y: 0.8),
      },
    );

    expect(result.isValid, isTrue);
    expect(result.machinePositions['BT-01']?.xMm, closeTo(0, 0.0001));
    expect(result.machinePositions['BT-02']?.xMm, closeTo(100, 0.0001));
    expect(result.machinePositions['BT-03']?.yMm, closeTo(50, 0.0001));
    expect(result.machinePositions['BT-04']?.yMm, closeTo(50, 0.0001));
  });

  test('버튼이 패널 밖이면 실제 좌표 전체를 폐기한다', () {
    final result = MappingCalibrationService.calculate(
      calibration: rectangularCalibration,
      buttonPositions: {'BT-01': (x: 0.99, y: 0.5)},
    );

    expect(result.isValid, isFalse);
    expect(result.machinePositions, isEmpty);
    expect(result.errors.single, contains('패널 영역 밖'));
  });

  test('실제 좌표가 최소 간격보다 가까운 버튼들을 거부한다', () {
    final result = MappingCalibrationService.calculate(
      calibration: rectangularCalibration,
      buttonPositions: {'BT-01': (x: 0.5, y: 0.5), 'BT-02': (x: 0.51, y: 0.5)},
    );

    expect(result.isValid, isFalse);
    expect(result.machinePositions, isEmpty);
    expect(result.errors.single, contains('2.0mm보다 가깝습니다'));
  });

  test('뒤틀린 모서리 순서는 변환 전에 거부한다', () {
    const calibration = PanelCalibration(
      imageFingerprint: 'photo-bad',
      corners: [
        PanelCalibrationPoint(
          imageX: 0.1,
          imageY: 0.1,
          machineXmm: 0,
          machineYmm: 0,
        ),
        PanelCalibrationPoint(
          imageX: 0.9,
          imageY: 0.9,
          machineXmm: 100,
          machineYmm: 0,
        ),
        PanelCalibrationPoint(
          imageX: 0.9,
          imageY: 0.1,
          machineXmm: 100,
          machineYmm: 50,
        ),
        PanelCalibrationPoint(
          imageX: 0.1,
          imageY: 0.9,
          machineXmm: 0,
          machineYmm: 50,
        ),
      ],
    );

    final result = MappingCalibrationService.calculate(
      calibration: calibration,
      buttonPositions: const {},
    );

    expect(result.isValid, isFalse);
    expect(result.errors.first, contains('시계 방향'));
  });
}
