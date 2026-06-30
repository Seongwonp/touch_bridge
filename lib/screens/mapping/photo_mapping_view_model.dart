import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/device_mapping_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/device_service.dart';
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
      await _tts.speak('블루투스가 연결되어 있지 않습니다.');
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
      await _tts.speak('${point.label} 위치를 테스트합니다.');
      return '${point.label} 테스트 명령 전송';
    }
    await _tts.speak(result.message);
    return result.message;
  }

  Future<String> testAllPoints() async {
    if (_points.isEmpty) return '테스트할 버튼이 없습니다.';
    if (!BleService.instance.isConnected) {
      await _tts.speak('블루투스가 연결되어 있지 않습니다.');
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
      await _tts.speak(
        '테스트에 실패했습니다. ${failed.buttonId ?? '해당'} 버튼 위치를 다시 조정하세요.',
      );
      return failed.message;
    }
    await _tts.speak('전체 버튼 테스트 명령을 전송했습니다.');
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

  void _applyAiMappingResult(Map<String, dynamic> res) {
    final items =
        (res['buttons'] ?? res['items'] ?? res['detections']) as List<dynamic>?;
    if (items == null) return;

    final grid = res['grid'];
    if (grid is Map<String, dynamic>) {
      _mappingRows = (grid['rows'] as num?)?.toInt() ?? _mappingRows;
      _mappingCols = (grid['cols'] as num?)?.toInt() ?? _mappingCols;
      if (_mappingRows <= 0) _mappingRows = 3;
      if (_mappingCols <= 0) _mappingCols = 3;
    }

    _points.clear();
    for (final raw in items) {
      if (raw is Map<String, dynamic>) {
        double? nx;
        double? ny;
        final id = (raw['button_id'] ?? raw['id'] ?? '').toString();
        String label = (raw['label'] ?? raw['text'] ?? '').toString();
        if (raw.containsKey('x') && raw.containsKey('y')) {
          nx = (raw['x'] as num).toDouble();
          ny = (raw['y'] as num).toDouble();
        } else if (raw.containsKey('row') && raw.containsKey('col')) {
          final row = (raw['row'] as num).toInt().clamp(0, _mappingRows - 1);
          final col = (raw['col'] as num).toInt().clamp(0, _mappingCols - 1);
          nx = (col + 0.5) / _mappingCols;
          ny = (row + 0.5) / _mappingRows;
        }
        if (nx != null && ny != null) {
          final normalizedX = nx.clamp(0.0, 1.0);
          final normalizedY = ny.clamp(0.0, 1.0);
          if (label.isEmpty && id.isNotEmpty) {
            label = MicrowaveCommandService.buttonLabel[id] ?? id;
          }
          _points.add(
            ButtonPoint(
              id: id.isNotEmpty ? id : DateTime.now().toString(),
              position: Offset(normalizedX, normalizedY),
              label: label.isNotEmpty ? label : '버튼 ${_points.length + 1}',
            ),
          );
        }
      }
    }
    notifyListeners();
    _tts.speak(
      '버튼 위치를 찾았습니다. 위치를 확인하고 저장하세요.',
      source: 'PhotoMappingScreen',
      interrupt: true,
    );
  }

  Future<String> save() async {
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
    _tts.stop();
    _deviceService.disconnect();
    super.dispose();
  }
}
