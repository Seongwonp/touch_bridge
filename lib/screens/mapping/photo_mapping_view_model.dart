import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/device_mapping_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/device_service.dart';
import '../../services/mapping_coordinate_service.dart';
import '../../services/mapping_execution_service.dart';
import '../../services/home_device_store.dart';

class ButtonPoint {
  final String id;
  final Offset position;
  final String label;

  ButtonPoint({required this.id, required this.position, required this.label});
}

class PhotoMappingViewModel extends ChangeNotifier {
  final String deviceId;
  final String? applianceName;
  final String? applianceType;
  final String? imagePath;
  final String? bleId;
  final String? bleName;

  final List<ButtonPoint> _points = [];
  Offset? _redMarkerPosition;
  bool _isAiAnalyzing = false;
  bool _isUploading = false;
  int _mappingRows = 3;
  int _mappingCols = 3;

  final DeviceService _deviceService = MockDeviceService();
  final TtsService _tts = TtsService();

  PhotoMappingViewModel({
    required this.deviceId,
    this.applianceName,
    this.applianceType,
    this.imagePath,
    this.bleId,
    this.bleName,
  });

  List<ButtonPoint> get points => _points;
  Offset? get redMarkerPosition => _redMarkerPosition;
  bool get isAiAnalyzing => _isAiAnalyzing;
  bool get isUploading => _isUploading;

  set redMarkerPosition(Offset? value) {
    _redMarkerPosition = value;
    notifyListeners();
  }

  Future<void> initialize() async {
    await _loadProfileOnly();
    await _initHardwareConnection();
  }

  Future<void> _loadProfileOnly() async {
    try {
      final profile = await DeviceMappingService.instance.load(deviceId);
      _mappingRows = profile.rows;
      _mappingCols = profile.cols;
      if (profile.buttonMap.isNotEmpty) {
        _points.clear();
        for (final entry in profile.buttonMap.entries) {
          final btId = entry.key;
          final row = entry.value.row;
          final col = entry.value.col;
          final savedPosition = profile.buttonPositions[btId];
          final label =
              profile.customLabels[btId] ??
              MicrowaveCommandService.buttonLabel[btId] ??
              btId;

          final x = savedPosition?.x ?? (col + 0.5) / profile.cols;
          final y = savedPosition?.y ?? (row + 0.5) / profile.rows;

          _points.add(
            ButtonPoint(id: btId, position: Offset(x, y), label: label),
          );
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _initHardwareConnection() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    await _deviceService.connect(deviceId);
  }

  void addPoint(Offset relativePosition) {
    if (_redMarkerPosition == null) {
      _redMarkerPosition = relativePosition;
      _tts.speak('기준점이 설정되었습니다. 이제 가전제품의 버튼들을 하나씩 터치하여 위치를 지정하세요.');
    } else if (_points.length < 9) {
      final btId = _nextButtonId();
      _points.add(
        ButtonPoint(
          id: btId,
          position: relativePosition,
          label:
              MicrowaveCommandService.buttonLabel[btId] ??
              '버튼 ${_points.length + 1}',
        ),
      );
    }
    notifyListeners();
  }

  String _nextButtonId() {
    final used = _points.map((point) => point.id).toSet();
    for (var k = 1; k <= 9; k++) {
      final candidate = 'BT-${k.toString().padLeft(2, '0')}';
      if (!used.contains(candidate)) return candidate;
    }
    return 'BT-${(_points.length + 1).toString().padLeft(2, '0')}';
  }

  void removePoint(int index) {
    if (index >= 0 && index < _points.length) {
      _points.removeAt(index);
      notifyListeners();
    }
  }

  void updatePointLabel(int index, String newLabel) {
    if (index >= 0 && index < _points.length) {
      _points[index] = ButtonPoint(
        id: _points[index].id,
        position: _points[index].position,
        label: newLabel,
      );
      _tts.speak('$newLabel로 변경되었습니다.');
      notifyListeners();
    }
  }

  String? _buttonIdForPoint(ButtonPoint point, {required Set<String> usedIds}) {
    String? btId = RegExp(r'^BT-\d{2}$').hasMatch(point.id)
        ? point.id
        : DeviceMappingService.instance.labelToButtonId(point.label);
    if (btId == null || usedIds.contains(btId)) {
      for (var k = 1; k <= 9; k++) {
        final cand = 'BT-${k.toString().padLeft(2, '0')}';
        if (!usedIds.contains(cand)) {
          btId = cand;
          break;
        }
      }
    }
    return btId;
  }

  Future<String> testPoint(int index) async {
    if (index < 0 || index >= _points.length) {
      return '테스트할 버튼을 찾지 못했습니다.';
    }
    if (!BleService.instance.isConnected) {
      await _tts.speak('기기가 연결되어 있지 않습니다. 기기 전원과 연결 상태를 확인한 뒤 다시 시도해 주세요.');
      return 'BLE 미연결';
    }

    final point = _points[index];
    final profile = await DeviceMappingService.instance.load(deviceId);
    final pointProfile = DeviceMappingProfile(
      rows: _mappingRows,
      cols: _mappingCols,
      originX: profile.originX,
      originY: profile.originY,
      pitchX: profile.pitchX,
      pitchY: profile.pitchY,
      buttonMap: {
        point.id: (
          row: (point.position.dy * _mappingRows).floor().clamp(
            0,
            _mappingRows - 1,
          ),
          col: (point.position.dx * _mappingCols).floor().clamp(
            0,
            _mappingCols - 1,
          ),
        ),
      },
      buttonPositions: {point.id: (x: point.position.dx, y: point.position.dy)},
      customLabels: {point.id: point.label},
      imagePath: imagePath,
    );
    final result = await MappingExecutionService.instance.pressButton(
      deviceId: deviceId,
      profile: pointProfile,
      buttonId: point.id,
    );

    if (result.ok) {
      await _tts.speak('${point.label} 위치를 테스트합니다.', priority: TtsPriority.result);
      return '${point.label} 테스트 명령 전송';
    }
    // message는 BT-xx 등 내부 용어가 섞인 개발자용 문구다 — 사용자에게는
    // userMessage(기술용어 비노출 원칙)를 읽어준다.
    await _tts.speak(result.userMessage, priority: TtsPriority.result);
    return result.userMessage;
  }

  Future<String> testAllPoints() async {
    if (_points.isEmpty) return '테스트할 버튼이 없습니다.';
    if (!BleService.instance.isConnected) {
      await _tts.speak('기기가 연결되어 있지 않습니다. 기기 전원과 연결 상태를 확인한 뒤 다시 시도해 주세요.');
      return 'BLE 미연결';
    }

    final baseProfile = await DeviceMappingService.instance.load(deviceId);
    final map = <String, ({int row, int col})>{};
    final positions = <String, ({double x, double y})>{};
    final labels = <String, String>{};
    final usedIds = <String>{};

    for (final point in _points) {
      final btId = _buttonIdForPoint(point, usedIds: usedIds);
      if (btId == null) continue;
      usedIds.add(btId);
      map[btId] = (
        row: (point.position.dy * _mappingRows).floor().clamp(
          0,
          _mappingRows - 1,
        ),
        col: (point.position.dx * _mappingCols).floor().clamp(
          0,
          _mappingCols - 1,
        ),
      );
      positions[btId] = (
        x: point.position.dx.clamp(0.0, 1.0),
        y: point.position.dy.clamp(0.0, 1.0),
      );
      labels[btId] = point.label;
    }

    final testProfile = DeviceMappingProfile(
      rows: _mappingRows,
      cols: _mappingCols,
      originX: baseProfile.originX,
      originY: baseProfile.originY,
      pitchX: baseProfile.pitchX,
      pitchY: baseProfile.pitchY,
      buttonMap: map,
      buttonPositions: positions,
      customLabels: labels,
      imagePath: imagePath,
    );

    await _tts.speak('전체 버튼 테스트를 시작합니다.');
    final results = await MappingExecutionService.instance.testAllButtons(
      deviceId: deviceId,
      profile: testProfile,
    );
    MappingExecutionResult? failed;
    for (final result in results) {
      if (!result.ok) {
        failed = result;
        break;
      }
    }
    if (failed != null) {
      // 내부 ID(BT-xx) 대신 사용자가 붙인 라벨로 안내한다.
      final failedLabel = labels[failed.buttonId] ?? '해당';
      await _tts.speak(
        '테스트에 실패했습니다. $failedLabel 버튼 위치를 다시 조정하세요.',
        priority: TtsPriority.result,
      );
      return failed.userMessage;
    }
    await _tts.speak('전체 버튼 테스트 명령을 전송했습니다.', priority: TtsPriority.result);
    return '전체 ${results.length}개 버튼 테스트 명령 전송';
  }

  void clearPoints() {
    _points.clear();
    _redMarkerPosition = null;
    notifyListeners();
  }

  Future<void> triggerAiMapping() async {
    if (imagePath == null || !AiBackendService.instance.isConfigured) return;

    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 500));

    _isAiAnalyzing = true;
    notifyListeners();

    try {
      await _tts.speak(
        '기기 사진을 분석합니다. 45초 정도 걸릴 수 있습니다.',
        source: 'PhotoMappingScreen',
        interrupt: true,
      );
      if (!imagePath!.startsWith('http')) {
        final file = File(imagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final mime = imagePath!.toLowerCase().endsWith('.png')
              ? 'image/png'
              : 'image/jpeg';
          final res = await AiBackendService.instance.analyzeMappingImage(
            imageBytes: bytes,
            mimeType: mime,
          );
          _applyAiMappingResult(res);
        }
      }
    } catch (e) {
      debugPrint('AI mapping failed: $e');
      await _tts.speak(
        '이미지 분석에 실패했습니다. 버튼 위치를 직접 눌러 저장해 주세요.',
        source: 'PhotoMappingScreen',
        interrupt: true,
      );
    } finally {
      _isAiAnalyzing = false;
      notifyListeners();
    }
  }

  /// 테스트 전용 진입점 — AI 응답 방어 로직(_applyAiMappingResult)을 검증한다.
  @visibleForTesting
  void applyAiMappingResultForTest(Map<String, dynamic> res) =>
      _applyAiMappingResult(res);

  /// AI가 다룰 수 있는 최대 버튼 수. 논리 버튼 ID 체계(BT-01~09)와 일치한다.
  /// 초과분은 저장 시 조용히 버려지는 문제가 있었으므로 적용 시점에 자르고 고지한다.
  static const int maxAiButtons = 9;

  /// 그리드 행/열 상한 — AI가 rows:1000 같은 값을 줘도 그대로 수용하지 않는다.
  static const int maxGridDimension = 10;

  void _applyAiMappingResult(Map<String, dynamic> res) {
    // AI 응답은 신뢰할 수 없는 외부 입력이다. 전부 파싱에 성공한 뒤에만 기존
    // 포인트를 교체한다 — 중간에 예외가 나면 기존 수동 포인트가 이미 지워진
    // 채 부분 적용 상태로 남던 버그(과거 `_points.clear()` 선행) 방지.
    final items =
        (res['buttons'] ?? res['items'] ?? res['detections']) as List<dynamic>?;
    if (items == null || items.isEmpty) {
      _tts.speak(
        '사진에서 버튼을 찾지 못했습니다. 버튼 위치를 직접 눌러 지정해 주세요.',
        source: 'PhotoMappingScreen',
        interrupt: true,
        priority: TtsPriority.result,
      );
      return;
    }

    var rows = _mappingRows;
    var cols = _mappingCols;
    final grid = res['grid'];
    if (grid is Map<String, dynamic>) {
      rows = (grid['rows'] as num?)?.toInt() ?? rows;
      cols = (grid['cols'] as num?)?.toInt() ?? cols;
    }
    rows = rows.clamp(1, maxGridDimension);
    cols = cols.clamp(1, maxGridDimension);

    final parsed = <ButtonPoint>[];
    var malformed = 0;
    for (final raw in items) {
      if (raw is! Map<String, dynamic>) {
        malformed++;
        continue;
      }
      // 타입 안전 파싱: AI가 "0.5" 같은 문자열이나 이상한 타입을 줘도
      // 해당 항목만 건너뛰고 전체 적용은 계속한다.
      final id = (raw['button_id'] ?? raw['id'] ?? '').toString();
      String label = (raw['label'] ?? raw['text'] ?? '').toString();
      double? nx = _asDouble(raw['x']);
      double? ny = _asDouble(raw['y']);
      if (nx == null || ny == null) {
        final row = _asDouble(raw['row'])?.toInt();
        final col = _asDouble(raw['col'])?.toInt();
        if (row != null && col != null) {
          nx = (col.clamp(0, cols - 1) + 0.5) / cols;
          ny = (row.clamp(0, rows - 1) + 0.5) / rows;
        }
      }
      if (nx == null || ny == null) {
        malformed++;
        continue;
      }
      if (label.isEmpty && id.isNotEmpty) {
        label = MicrowaveCommandService.buttonLabel[id] ?? id;
      }
      parsed.add(
        ButtonPoint(
          id: id,
          position: Offset(nx.clamp(0.0, 1.0), ny.clamp(0.0, 1.0)),
          label: label.isNotEmpty ? label : '버튼 ${parsed.length + 1}',
        ),
      );
    }

    if (parsed.isEmpty) {
      _tts.speak(
        '사진 분석 결과를 읽지 못했습니다. 버튼 위치를 직접 눌러 지정해 주세요.',
        source: 'PhotoMappingScreen',
        interrupt: true,
        priority: TtsPriority.result,
      );
      return;
    }

    // 버튼 수 상한: 초과분은 저장 시 ID를 못 받아 조용히 버려지므로,
    // 적용 시점에 자르고 사용자에게 알린다.
    final dropped = parsed.length > maxAiButtons
        ? parsed.length - maxAiButtons
        : 0;
    final applied = parsed.take(maxAiButtons).toList();

    // 빈 id는 순번 기반으로 보정한다(이전에는 DateTime 문자열이 들어갔다).
    final usedIds = <String>{};
    for (var i = 0; i < applied.length; i++) {
      var point = applied[i];
      if (point.id.isEmpty || usedIds.contains(point.id)) {
        for (var k = 1; k <= maxAiButtons; k++) {
          final cand = 'BT-${k.toString().padLeft(2, '0')}';
          if (!usedIds.contains(cand)) {
            point = ButtonPoint(
              id: cand,
              position: point.position,
              label: point.label,
            );
            break;
          }
        }
      }
      usedIds.add(point.id);
      applied[i] = point;
    }

    // 파싱이 모두 끝난 뒤에야 교체한다.
    _mappingRows = rows;
    _mappingCols = cols;
    _points
      ..clear()
      ..addAll(applied);
    notifyListeners();

    final extra = [
      if (dropped > 0) '버튼이 많아 $dropped개는 제외했습니다.',
      if (malformed > 0) '읽지 못한 항목 $malformed개는 건너뛰었습니다.',
    ].join(' ');
    _tts.speak(
      '버튼 ${applied.length}개의 위치를 찾았습니다. $extra 위치를 확인하고 저장하세요.',
      source: 'PhotoMappingScreen',
      interrupt: true,
      priority: TtsPriority.result,
    );
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Future<String> save() async {
    // 저장 전 셀 충돌 검사: 서로 다른 버튼이 같은 그리드 셀로 양자화되면
    // 하드웨어는 같은 지점을 누른다("시작" 자리에서 "취소"가 눌리는 최악의
    // 오작동). 침묵 저장하지 않고 보호자에게 조정을 요구한다.
    final collisions = MappingCoordinateService.detectCellCollisions(
      points: [
        for (final p in _points)
          (label: p.label, x: p.position.dx, y: p.position.dy),
      ],
      rows: _mappingRows,
      cols: _mappingCols,
    );
    if (collisions.isNotEmpty) {
      final desc = collisions.map((g) => g.join('·')).join(', ');
      final msg =
          '버튼 위치가 서로 너무 가까워 같은 칸에 겹칩니다: $desc. '
          '그리드 행·열을 늘리거나 겹친 버튼 위치를 조정한 뒤 다시 저장해 주세요.';
      await _tts.speak(
        msg,
        source: 'PhotoMappingScreen',
        interrupt: true,
        priority: TtsPriority.result,
      );
      return msg;
    }

    _isUploading = true;
    notifyListeners();

    try {
      final profile = await DeviceMappingService.instance.load(deviceId);
      final rows = _mappingRows;
      final cols = _mappingCols;
      final map = <String, ({int row, int col})>{};
      final positions = <String, ({double x, double y})>{};
      final customLabels = <String, String>{};
      final usedIds = <String>{};

      for (var i = 0; i < _points.length; i++) {
        final point = _points[i];
        int colIdx = (point.position.dx * cols).floor().clamp(0, cols - 1);
        int rowIdx = (point.position.dy * rows).floor().clamp(0, rows - 1);

        final btId = _buttonIdForPoint(point, usedIds: usedIds);
        if (btId == null) continue;
        usedIds.add(btId);
        map[btId] = (row: rowIdx, col: colIdx);
        positions[btId] = (
          x: point.position.dx.clamp(0.0, 1.0),
          y: point.position.dy.clamp(0.0, 1.0),
        );
        customLabels[btId] = point.label;
      }

      final newProfile = DeviceMappingProfile(
        rows: rows,
        cols: cols,
        originX: profile.originX,
        originY: profile.originY,
        pitchX: profile.pitchX,
        pitchY: profile.pitchY,
        buttonMap: map,
        buttonPositions: positions,
        customLabels: customLabels,
        imagePath: imagePath,
      );

      await DeviceMappingService.instance.save(deviceId, newProfile);
      await ActiveDeviceService.instance.setActiveDevice(
        deviceId: deviceId,
        deviceName: applianceName ?? deviceId,
        bleId: bleId,
        bleName: bleName,
      );

      // Register to home devices if needed
      final devices = await HomeDeviceStore.loadDevices();
      if (!devices.any((d) => d['id'] == deviceId)) {
        devices.add({
          'id': deviceId,
          'name': applianceName,
          'status': '작동 대기 중',
          'iconCodePoint': switch (applianceType?.toLowerCase()) {
            'microwave' => Icons.microwave_rounded.codePoint,
            'washer' ||
            'laundry' => Icons.local_laundry_service_rounded.codePoint,
            _ => Icons.devices_rounded.codePoint,
          },
          'bleId': bleId,
          'bleName': bleName,
        });
        await HomeDeviceStore.saveDevices(devices);
        ActiveDeviceService.instance.notifyDeviceListChanged(); // 목록 갱신 알림 트리거
      }

      if (BleService.instance.isConnected) {
        final res = await _executeBleUpload(
          newProfile,
          map,
          rows,
          cols,
          deviceId,
        );
        return res['message'];
      }
      return '매핑 저장 완료 (BLE 미연결)';
    } catch (e) {
      return '저장 중 오류: $e';
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _executeBleUpload(
    DeviceMappingProfile newProfile,
    Map<String, ({int row, int col})> map,
    int rows,
    int cols,
    String deviceId,
  ) async {
    final ok = await BleService.instance.sendSetGrid(
      rows: newProfile.rows,
      cols: newProfile.cols,
      originX: newProfile.originX,
      originY: newProfile.originY,
      pitchX: newProfile.pitchX,
      pitchY: newProfile.pitchY,
      deviceId: deviceId,
    );
    if (!ok) return {'message': 'BLE 전송 실패'};

    final response = await BleService.instance.readResponse(
      timeout: const Duration(seconds: 5),
    );
    if (response != null &&
        (response.contains('GRID_CONFIG_UPDATED') ||
            response.toLowerCase().contains('ok'))) {
      return {'message': '매핑 저장 및 BLE 보정 완료'};
    }
    return {'message': '매핑 저장 완료 (하드웨어 확인 지연)'};
  }

  @override
  void dispose() {
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
    _deviceService.disconnect();
    super.dispose();
  }
}
