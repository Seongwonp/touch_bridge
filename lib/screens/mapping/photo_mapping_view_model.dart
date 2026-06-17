import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/device_mapping_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/device_service.dart';

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
      if (profile.buttonMap.isNotEmpty) {
        _points.clear();
        for (final entry in profile.buttonMap.entries) {
          final btId = entry.key;
          final row = entry.value.row;
          final col = entry.value.col;
          final label = profile.customLabels[btId] ?? 
                        MicrowaveCommandService.buttonLabel[btId] ?? 
                        btId;
          
          final x = (col + 0.5) / profile.cols;
          final y = (row + 0.5) / profile.rows;
          
          _points.add(ButtonPoint(
            id: btId,
            position: Offset(x, y),
            label: label,
          ));
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
      _points.add(ButtonPoint(
        id: DateTime.now().toString(),
        position: relativePosition,
        label: '버튼 ${_points.length + 1}',
      ));
    }
    notifyListeners();
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

  void clearPoints() {
    _points.clear();
    notifyListeners();
  }

  Future<void> triggerAiMapping() async {
    if (imagePath == null || !AiBackendService.instance.isConfigured) return;

    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 500));

    _isAiAnalyzing = true;
    notifyListeners();

    try {
      await _tts.speak('AI가 이미지 분석을 시작합니다. 잠시만 기다려주세요.', source: 'PhotoMappingScreen', interrupt: true);
      if (!imagePath!.startsWith('http')) {
        final file = File(imagePath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final mime = imagePath!.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
          final res = await AiBackendService.instance.analyzeMappingImage(imageBytes: bytes, mimeType: mime);
          _applyAiMappingResult(res);
        }
      }
    } catch (e) {
      debugPrint('AI mapping failed: $e');
      await _tts.speak('AI 분석에 실패했습니다.', source: 'PhotoMappingScreen', interrupt: true);
    } finally {
      _isAiAnalyzing = false;
      notifyListeners();
    }
  }

  void _applyAiMappingResult(Map<String, dynamic> res) {
    final items = (res['buttons'] ?? res['items'] ?? res['detections']) as List<dynamic>?;
    if (items == null) return;
    
    _points.clear();
    for (final raw in items) {
      if (raw is Map<String, dynamic>) {
        double? nx;
        double? ny;
        String label = (raw['label'] ?? raw['text'] ?? '') as String;
        if (raw.containsKey('x') && raw.containsKey('y')) {
          nx = (raw['x'] as num).toDouble();
          ny = (raw['y'] as num).toDouble();
        }
        if (nx != null && ny != null) {
          _points.add(ButtonPoint(id: DateTime.now().toString(), position: Offset(nx, ny), label: label.isNotEmpty ? label : '버튼 ${_points.length + 1}'));
        }
      }
    }
    notifyListeners();
    _tts.speak('AI 자동 매핑이 완료되었습니다. 위치를 확인하고 저장하세요.', source: 'PhotoMappingScreen', interrupt: true);
  }

  Future<String> save() async {
    _isUploading = true;
    notifyListeners();
    
    try {
      final profile = await DeviceMappingService.instance.load(deviceId);
      final rows = profile.rows;
      final cols = profile.cols;
      final map = <String, ({int row, int col})>{};
      final customLabels = <String, String>{};
      final usedIds = <String>{};

      for (var i = 0; i < _points.length; i++) {
        final point = _points[i];
        int colIdx = (point.position.dx * cols).floor().clamp(0, cols - 1);
        int rowIdx = (point.position.dy * rows).floor().clamp(0, rows - 1);

        String? btId = DeviceMappingService.instance.labelToButtonId(point.label);
        if (btId == null || usedIds.contains(btId)) {
          for (var k = 1; k <= 9; k++) {
            final cand = 'BT-${k.toString().padLeft(2, '0')}';
            if (!usedIds.contains(cand)) {
              btId = cand;
              break;
            }
          }
        }
        if (btId == null) continue;
        usedIds.add(btId);
        map[btId] = (row: rowIdx, col: colIdx);
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
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('home_devices');
      final devices = jsonStr != null ? (jsonDecode(jsonStr) as List).cast<Map<String, dynamic>>() : <Map<String, dynamic>>[];
      if (!devices.any((d) => d['id'] == deviceId)) {
        devices.add({
          'id': deviceId,
          'name': applianceName,
          'status': '작동 대기 중',
          'iconCodePoint': switch (applianceType?.toLowerCase()) {
            'microwave' => Icons.microwave_rounded.codePoint,
            'washer' || 'laundry' => Icons.local_laundry_service_rounded.codePoint,
            _ => Icons.devices_rounded.codePoint,
          },
          'bleId': bleId,
          'bleName': bleName,
        });
        await prefs.setString('home_devices', jsonEncode(devices));
        ActiveDeviceService.instance.notifyDeviceListChanged(); // 목록 갱신 알림 트리거
      }

      if (BleService.instance.isConnected) {
        final res = await _executeBleUpload(newProfile, map, rows, cols, deviceId);
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

  Future<Map<String, dynamic>> _executeBleUpload(DeviceMappingProfile newProfile, Map<String, ({int row, int col})> map, int rows, int cols, String deviceId) async {
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
    
    final response = await BleService.instance.readResponse(timeout: const Duration(seconds: 5));
    if (response != null && response.contains('GRID_OK')) {
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
