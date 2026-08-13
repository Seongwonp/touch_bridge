import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/services/device_mapping_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('기기별 매핑 프로필을 저장하고 다시 불러온다', () async {
    const profile = DeviceMappingProfile(
      rows: 4,
      cols: 3,
      originX: 2.0,
      originY: 3.0,
      pitchX: 8.5,
      pitchY: 6.5,
      buttonMap: {'BT-02': (row: 3, col: 1), 'BT-05': (row: 0, col: 0)},
      buttonPositions: {
        'BT-02': (x: 0.42, y: 0.84),
        'BT-05': (x: 0.51, y: 0.31),
      },
      customLabels: {'BT-02': '30초', 'BT-05': '시작'},
      imagePath: '/tmp/panel.jpg',
    );

    await DeviceMappingService.instance.save('device-a', profile);
    final loaded = await DeviceMappingService.instance.load('device-a');

    expect(loaded.rows, 4);
    expect(loaded.cols, 3);
    expect(loaded.originX, 2.0);
    expect(loaded.originY, 3.0);
    expect(loaded.pitchX, 8.5);
    expect(loaded.pitchY, 6.5);
    expect(loaded.buttonMap['BT-02'], (row: 3, col: 1));
    expect(loaded.buttonMap['BT-05'], (row: 0, col: 0));
    expect(loaded.buttonPositions['BT-02'], (x: 0.42, y: 0.84));
    expect(loaded.buttonPositions['BT-05'], (x: 0.51, y: 0.31));
    expect(loaded.customLabels['BT-05'], '시작');
    expect(loaded.imagePath, '/tmp/panel.jpg');
  });

  test('기존 row/col 프로필은 사진 좌표를 그리드 중심점으로 보정한다', () {
    final loaded = DeviceMappingProfile.fromJson({
      'grid': {
        'rows': 3,
        'cols': 3,
        'originX': 0,
        'originY': 0,
        'pitchX': 1,
        'pitchY': 1,
      },
      'buttonMap': {
        'BT-01': {'row': 0, 'col': 0},
        'BT-09': {'row': 2, 'col': 2},
      },
    });

    expect(loaded.buttonPositions['BT-01']?.x, closeTo(1 / 6, 0.0001));
    expect(loaded.buttonPositions['BT-01']?.y, closeTo(1 / 6, 0.0001));
    expect(loaded.buttonPositions['BT-09']?.x, closeTo(5 / 6, 0.0001));
    expect(loaded.buttonPositions['BT-09']?.y, closeTo(5 / 6, 0.0001));
  });
}
