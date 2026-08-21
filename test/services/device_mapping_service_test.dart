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

  group('DeviceMappingService.mergeGridUpdate (수동 매핑 병합 저장)', () {
    // 과거 버그: 수동 매핑 저장이 빈 프로필로 덮어써서 사진 매핑의 버튼/라벨/
    // 모션/이미지가 재보정 한 번에 전부 소실됐다. 병합이 이를 보존해야 한다.
    const existing = DeviceMappingProfile(
      rows: 3,
      cols: 3,
      originX: 1,
      originY: 2,
      pitchX: 10,
      pitchY: 11,
      buttonMap: {
        'BT-01': (row: 0, col: 0),
        'BT-05': (row: 1, col: 1),
        'BT-09': (row: 2, col: 2),
      },
      buttonPositions: {
        'BT-01': (x: 0.1, y: 0.1),
        'BT-05': (x: 0.5, y: 0.5),
        'BT-09': (x: 0.9, y: 0.9),
      },
      customLabels: {'BT-05': '시작', 'BT-09': '자동조리'},
      travelHeightZ: 7.5,
      pressDepthZ: -1.5,
      travelFeed: 900,
      pressFeed: 150,
      dwellSeconds: 0.35,
      imagePath: '/tmp/panel.jpg',
    );

    test('그리드 값만 갱신하고 사진 매핑 데이터는 보존한다', () {
      final result = DeviceMappingService.mergeGridUpdate(
        existing: existing,
        rows: 3,
        cols: 3,
        originX: 5,
        originY: 6,
        pitchX: 20,
        pitchY: 21,
        homeRow: 1,
        homeCol: 2,
      );

      expect(result.droppedButtonIds, isEmpty);
      final p = result.profile;
      expect(p.originX, 5);
      expect(p.originY, 6);
      expect(p.pitchX, 20);
      expect(p.pitchY, 21);
      expect(p.homeRow, 1);
      expect(p.homeCol, 2);
      // 사진 매핑 산출물 보존 검증 — 이게 깨지면 데이터 손실 버그 재발.
      expect(p.buttonMap, existing.buttonMap);
      expect(p.buttonPositions, existing.buttonPositions);
      expect(p.customLabels, existing.customLabels);
      expect(p.travelHeightZ, 7.5);
      expect(p.pressDepthZ, -1.5);
      expect(p.travelFeed, 900);
      expect(p.pressFeed, 150);
      expect(p.dwellSeconds, 0.35);
      expect(p.imagePath, '/tmp/panel.jpg');
    });

    test('그리드 축소 시 범위 밖 버튼을 제거하고 목록으로 보고한다', () {
      final result = DeviceMappingService.mergeGridUpdate(
        existing: existing,
        rows: 2,
        cols: 2,
        originX: 0,
        originY: 0,
        pitchX: 10,
        pitchY: 10,
        homeRow: 0,
        homeCol: 0,
      );

      // (1,1)까지는 2x2 안, (2,2)는 밖.
      expect(result.droppedButtonIds, ['BT-09']);
      expect(result.profile.buttonMap.keys, containsAll(['BT-01', 'BT-05']));
      expect(result.profile.buttonMap.containsKey('BT-09'), isFalse);
      // 제거된 버튼의 위치/라벨도 함께 정리되어야 한다(고아 데이터 방지).
      expect(result.profile.buttonPositions.containsKey('BT-09'), isFalse);
      expect(result.profile.customLabels.containsKey('BT-09'), isFalse);
      // 살아남은 버튼의 라벨은 유지.
      expect(result.profile.customLabels['BT-05'], '시작');
    });

    test('그리드 확대는 아무 버튼도 제거하지 않는다', () {
      final result = DeviceMappingService.mergeGridUpdate(
        existing: existing,
        rows: 5,
        cols: 5,
        originX: 0,
        originY: 0,
        pitchX: 10,
        pitchY: 10,
        homeRow: 0,
        homeCol: 0,
      );

      expect(result.droppedButtonIds, isEmpty);
      expect(result.profile.buttonMap.length, 3);
    });
  });
}
