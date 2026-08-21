import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DeviceMappingProfile {
  const DeviceMappingProfile({
    required this.rows,
    required this.cols,
    required this.originX,
    required this.originY,
    required this.pitchX,
    required this.pitchY,
    required this.buttonMap,
    this.buttonPositions = const {},
    this.customLabels = const {},
    this.homeRow = 0,
    this.homeCol = 0,
    this.travelHeightZ = 5.0,
    this.pressDepthZ = -2.0,
    this.travelFeed = 1200,
    this.pressFeed = 200,
    this.dwellSeconds = 0.2,
    this.imagePath,
  });

  final int rows;
  final int cols;
  final double originX;
  final double originY;
  final double pitchX;
  final double pitchY;
  final Map<String, ({int row, int col})> buttonMap;
  final Map<String, ({double x, double y})> buttonPositions;
  final Map<String, String> customLabels;
  final int homeRow;
  final int homeCol;
  final double travelHeightZ;
  final double pressDepthZ;
  final int travelFeed;
  final int pressFeed;
  final double dwellSeconds;
  final String? imagePath;

  Map<String, dynamic> toJson() => {
    'grid': {
      'rows': rows,
      'cols': cols,
      'originX': originX,
      'originY': originY,
      'pitchX': pitchX,
      'pitchY': pitchY,
    },
    'buttonMap': {
      for (final e in buttonMap.entries)
        e.key: {'row': e.value.row, 'col': e.value.col},
    },
    'buttonPositions': {
      for (final e in buttonPositions.entries)
        e.key: {'x': e.value.x, 'y': e.value.y},
    },
    'customLabels': customLabels,
    'homePosition': {'row': homeRow, 'col': homeCol},
    'motion': {
      'travelHeightZ': travelHeightZ,
      'pressDepthZ': pressDepthZ,
      'travelFeed': travelFeed,
      'pressFeed': pressFeed,
      'dwellSeconds': dwellSeconds,
    },
    'imagePath': imagePath,
  };

  factory DeviceMappingProfile.fromJson(Map<String, dynamic> j) {
    final grid = (j['grid'] as Map<String, dynamic>? ?? const {});
    final buttonRaw = (j['buttonMap'] as Map<String, dynamic>? ?? const {});
    final positionRaw =
        (j['buttonPositions'] as Map<String, dynamic>? ?? const {});
    final labelsRaw = (j['customLabels'] as Map<String, dynamic>? ?? const {});
    final homePos = (j['homePosition'] as Map<String, dynamic>? ?? const {});
    final motion = (j['motion'] as Map<String, dynamic>? ?? const {});

    final map = <String, ({int row, int col})>{};
    for (final e in buttonRaw.entries) {
      final v = e.value as Map<String, dynamic>;
      map[e.key] = (
        row: (v['row'] as num).toInt(),
        col: (v['col'] as num).toInt(),
      );
    }

    final positions = <String, ({double x, double y})>{};
    for (final e in positionRaw.entries) {
      final v = e.value as Map<String, dynamic>;
      positions[e.key] = (
        x: ((v['x'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
        y: ((v['y'] as num?)?.toDouble() ?? 0).clamp(0.0, 1.0),
      );
    }

    final rows = (grid['rows'] as num?)?.toInt() ?? 3;
    final cols = (grid['cols'] as num?)?.toInt() ?? 3;
    final migratedPositions = positions.isNotEmpty
        ? positions
        : {
            for (final e in map.entries)
              e.key: (
                x: ((e.value.col + 0.5) / cols).clamp(0.0, 1.0),
                y: ((e.value.row + 0.5) / rows).clamp(0.0, 1.0),
              ),
          };

    return DeviceMappingProfile(
      rows: rows,
      cols: cols,
      originX: (grid['originX'] as num?)?.toDouble() ?? 0,
      originY: (grid['originY'] as num?)?.toDouble() ?? 0,
      pitchX: (grid['pitchX'] as num?)?.toDouble() ?? 1,
      pitchY: (grid['pitchY'] as num?)?.toDouble() ?? 1,
      buttonMap: map,
      buttonPositions: migratedPositions,
      customLabels: labelsRaw.cast<String, String>(),
      homeRow: (homePos['row'] as num?)?.toInt() ?? 0,
      homeCol: (homePos['col'] as num?)?.toInt() ?? 0,
      travelHeightZ: (motion['travelHeightZ'] as num?)?.toDouble() ?? 5.0,
      pressDepthZ: (motion['pressDepthZ'] as num?)?.toDouble() ?? -2.0,
      travelFeed: (motion['travelFeed'] as num?)?.toInt() ?? 1200,
      pressFeed: (motion['pressFeed'] as num?)?.toInt() ?? 200,
      dwellSeconds: (motion['dwellSeconds'] as num?)?.toDouble() ?? 0.2,
      imagePath: j['imagePath'] as String?,
    );
  }

  static DeviceMappingProfile defaultGrid({int rows = 3, int cols = 3}) =>
      DeviceMappingProfile(
        rows: rows,
        cols: cols,
        originX: 0,
        originY: 0,
        pitchX: 1,
        pitchY: 1,
        buttonMap: const {},
        buttonPositions: const {},
        homeRow: 0,
        homeCol: 0,
      );
}

class DeviceMappingService {
  DeviceMappingService._();
  static final DeviceMappingService instance = DeviceMappingService._();

  String _profileKey(String deviceId) => 'mapping_profile_$deviceId';
  String _legacyGridKey(String deviceId) => 'mapping_grid_$deviceId';

  Future<DeviceMappingProfile> load(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final profileRaw = prefs.getString(_profileKey(deviceId));
    if (profileRaw != null) {
      return DeviceMappingProfile.fromJson(
        jsonDecode(profileRaw) as Map<String, dynamic>,
      );
    }

    final legacyGrid = prefs.getString(_legacyGridKey(deviceId));
    if (legacyGrid != null) {
      final flat = (jsonDecode(legacyGrid) as List).cast<String?>();
      final map = <String, ({int row, int col})>{};
      for (var i = 0; i < flat.length; i++) {
        final label = flat[i] ?? '';
        final bt = _labelToButtonId(label);
        if (bt == null) continue;
        map[bt] = (row: i ~/ 3, col: i % 3);
      }
      return DeviceMappingProfile(
        rows: 3,
        cols: 3,
        originX: 0,
        originY: 0,
        pitchX: 1,
        pitchY: 1,
        buttonMap: map,
      );
    }

    return DeviceMappingProfile.defaultGrid();
  }

  Future<void> save(String deviceId, DeviceMappingProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey(deviceId), jsonEncode(profile.toJson()));
  }

  /// 좌표(그리드) 수동 설정을 기존 프로필에 **병합**한다.
  ///
  /// 수동 매핑 화면은 행/열/원점/간격/홈 위치만 편집하는데, 이전 구현은 빈
  /// 프로필을 새로 만들어 저장해서 사진 매핑이 만들어 둔 buttonMap ·
  /// buttonPositions · customLabels · 모션 파라미터 · imagePath가 재보정 한
  /// 번에 전부 소실됐다(데이터 손실 버그). 이 함수는 그리드 값만 갱신하고
  /// 나머지는 보존한다.
  ///
  /// 그리드가 줄어 새 범위(rows×cols)를 벗어나게 된 버튼은 잘못된 물리
  /// 좌표로 눌리는 것을 막기 위해 제거하고, 제거된 ID 목록을 함께 반환한다 —
  /// 호출부는 이를 사용자에게 반드시 고지해야 한다.
  static ({DeviceMappingProfile profile, List<String> droppedButtonIds})
  mergeGridUpdate({
    required DeviceMappingProfile existing,
    required int rows,
    required int cols,
    required double originX,
    required double originY,
    required double pitchX,
    required double pitchY,
    required int homeRow,
    required int homeCol,
  }) {
    final keptButtons = <String, ({int row, int col})>{};
    final dropped = <String>[];
    for (final e in existing.buttonMap.entries) {
      if (e.value.row < rows && e.value.col < cols) {
        keptButtons[e.key] = e.value;
      } else {
        dropped.add(e.key);
      }
    }
    dropped.sort();

    final merged = DeviceMappingProfile(
      rows: rows,
      cols: cols,
      originX: originX,
      originY: originY,
      pitchX: pitchX,
      pitchY: pitchY,
      homeRow: homeRow,
      homeCol: homeCol,
      buttonMap: keptButtons,
      buttonPositions: {
        for (final e in existing.buttonPositions.entries)
          if (!dropped.contains(e.key)) e.key: e.value,
      },
      customLabels: {
        for (final e in existing.customLabels.entries)
          if (!dropped.contains(e.key)) e.key: e.value,
      },
      travelHeightZ: existing.travelHeightZ,
      pressDepthZ: existing.pressDepthZ,
      travelFeed: existing.travelFeed,
      pressFeed: existing.pressFeed,
      dwellSeconds: existing.dwellSeconds,
      imagePath: existing.imagePath,
    );
    return (profile: merged, droppedButtonIds: dropped);
  }

  /// [load]는 저장된 게 없어도 [DeviceMappingProfile.defaultGrid]를 돌려주므로
  /// "정말 한 번이라도 저장됐는지"를 구분할 때는 이 메서드를 써야 한다.
  /// 사진 매핑(buttonMap 있음)과 좌표 매핑(그리드만 있음) 모두 저장 시점에
  /// 이 키가 생기므로 두 방식 어느 쪽으로 설정했든 true를 반환한다.
  Future<bool> hasSavedProfile(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_profileKey(deviceId));
  }

  String? _labelToButtonId(String label) {
    final t = label.trim();
    if (t.isEmpty) return null;
    const map = {
      '10초': 'BT-01',
      '30초': 'BT-02',
      '1분': 'BT-03',
      '5분': 'BT-04',
      '시작': 'BT-05',
      '취소': 'BT-06',
      '정지': 'BT-06',
      '해동': 'BT-07',
      '우유': 'BT-08',
      '자동조리': 'BT-09',
    };
    return map[t];
  }

  /// Public helper: convert a human label (from AI or user) into a logical button id (e.g. 'BT-02').
  String? labelToButtonId(String label) => _labelToButtonId(label);
}
