import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/device_mapping_service.dart';
import '../../services/active_device_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../services/microwave_command_service.dart';
import '../../services/device_service.dart';
import '../../services/mapping_calibration_service.dart';
import '../../services/home_device_store.dart';
import '../../services/app_logger.dart';
import '../../services/mapping_verification_service.dart';
import '../../services/motion_controller.dart';
import '../../services/feedback_service.dart';

class ButtonPoint {
  final String id;
  final Offset position;
  final String label;

  ButtonPoint({required this.id, required this.position, required this.label});
}

class PointVerificationExecution {
  const PointVerificationExecution({
    required this.ok,
    required this.message,
    required this.buttonId,
    required this.label,
    required this.mode,
    this.targetXmm,
    this.targetYmm,
    this.controllerErrorMm,
    this.failure,
  });

  final bool ok;
  final String message;
  final String buttonId;
  final String label;
  final MappingVerificationMode mode;
  final double? targetXmm;
  final double? targetYmm;
  final double? controllerErrorMm;
  final String? failure;
}

class PhotoMappingViewModel extends ChangeNotifier {
  bool _disposed = false;
  final String deviceId;
  final String? applianceName;
  final String? applianceType;
  final String? imagePath;
  final String? bleId;
  final String? bleName;

  final List<ButtonPoint> _points = [];
  final List<Offset> _calibrationCorners = [];
  PanelCalibration? _panelCalibration;
  String? _imageFingerprint;
  int _calibrationRevision = 0;
  bool _isAiAnalyzing = false;
  bool _isUploading = false;
  int _mappingRows = 3;
  int _mappingCols = 3;
  List<MappingVerificationRecord> _verificationRecords = const [];

  final DeviceService _deviceService = MockDeviceService();
  final TtsService _tts = TtsService();
  late final MotionController _motionController;
  late final SafePressCoordinator _safePressCoordinator;

  PhotoMappingViewModel({
    required this.deviceId,
    this.applianceName,
    this.applianceType,
    this.imagePath,
    this.bleId,
    this.bleName,
    MotionTransport? motionTransport,
  }) {
    final transport = motionTransport ?? BleMotionTransport();
    _motionController = Esp32MotionController(transport: transport);
    _safePressCoordinator = SafePressCoordinator(
      motionController: _motionController,
      pressActuator: Esp32SwitchBotActuator(transport: transport),
    );
  }

  List<ButtonPoint> get points => _points;
  List<Offset> get calibrationCorners => List.unmodifiable(_calibrationCorners);
  bool get hasPanelCalibration => _panelCalibration?.isComplete ?? false;
  bool get needsCalibrationDimensions =>
      _calibrationCorners.length == 4 && !hasPanelCalibration;
  int get calibrationCornerCount => _calibrationCorners.length;
  bool get isAiAnalyzing => _isAiAnalyzing;
  bool get isUploading => _isUploading;
  bool get isMotionHomed => _motionController.isHomed;
  List<MappingVerificationRecord> get verificationRecords =>
      List.unmodifiable(_verificationRecords);
  String get verificationSummary {
    if (_verificationRecords.isEmpty) return '아직 저장된 위치 검증 결과가 없습니다.';
    final passed = _verificationRecords
        .where((record) => record.passesTolerance(0.7))
        .length;
    final latest = _verificationRecords.last;
    final radial = latest.measuredRadialErrorMm;
    final error = radial == null ? '' : ' · 실측 ${radial.toStringAsFixed(2)}mm';
    return '검증 ${_verificationRecords.length}회 중 통과 $passed회 · '
        '최근 ${latest.label}$error';
  }

  Future<void> initialize() async {
    _imageFingerprint = await _computeImageFingerprint();
    await _loadProfileOnly();
    _verificationRecords = await MappingVerificationService.instance.load(
      deviceId,
    );
    notifyListeners();
    await _initHardwareConnection();
  }

  Future<void> _loadProfileOnly() async {
    try {
      final profile = await DeviceMappingService.instance.load(deviceId);
      final calibration = profile.panelCalibration;
      if (calibration != null &&
          calibration.imageFingerprint == _imageFingerprint) {
        _panelCalibration = calibration;
        _calibrationCorners
          ..clear()
          ..addAll(
            calibration.corners.map(
              (corner) => Offset(corner.imageX, corner.imageY),
            ),
          );
      } else if (calibration != null) {
        final invalidated = DeviceMappingService.invalidatePanelCalibration(
          profile,
        );
        await DeviceMappingService.instance.save(deviceId, invalidated);
        AppLogger.warn('mapping.calibration_invalidated', {
          'device_id': deviceId,
          'reason': 'image_fingerprint_changed',
        });
      }
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

  Future<String> _computeImageFingerprint() async {
    final path = imagePath;
    if (path == null || path.isEmpty) return 'no-image';
    if (path.startsWith('http')) return 'url:$path';
    try {
      final stat = await File(path).stat();
      return '$path|${stat.size}|${stat.modified.millisecondsSinceEpoch}';
    } catch (_) {
      return 'path:$path';
    }
  }

  Future<void> _initHardwareConnection() async {
    await Future.delayed(const Duration(milliseconds: 1500));
    await _deviceService.connect(deviceId);
  }

  /// 이미지 탭을 처리한다. 네 번째 모서리가 등록되면 true를 반환해 화면이
  /// 실제 패널 크기 입력 창을 열 수 있게 한다.
  bool addPoint(Offset relativePosition) {
    if (!hasPanelCalibration) {
      if (_calibrationCorners.length < 4) {
        _calibrationCorners.add(relativePosition);
        const names = ['좌상단', '우상단', '우하단', '좌하단'];
        final selected = names[_calibrationCorners.length - 1];
        final next = _calibrationCorners.length < 4
            ? ' 다음은 ${names[_calibrationCorners.length]} 모서리를 터치하세요.'
            : ' 이제 실제 패널 크기를 입력하세요.';
        _tts.speak('$selected 모서리가 설정되었습니다.$next');
        notifyListeners();
        return _calibrationCorners.length == 4;
      }
      _tts.speak('실제 패널 크기를 먼저 입력해 주세요.');
      return false;
    }
    if (_points.length < maxAiButtons) {
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
    return false;
  }

  void updateCalibrationCorner(int index, Offset position) {
    if (index < 0 || index >= _calibrationCorners.length) return;
    final hadCalibration = _panelCalibration != null;
    _calibrationCorners[index] = position;
    _panelCalibration = null;
    if (hadCalibration) {
      final revision = ++_calibrationRevision;
      unawaited(_invalidateSavedCalibration('corner_moved', revision));
    }
    notifyListeners();
  }

  Future<void> nudgeCalibrationCorner(int index, Offset delta) async {
    if (index < 0 || index >= _calibrationCorners.length) return;
    final current = _calibrationCorners[index];
    updateCalibrationCorner(
      index,
      Offset(
        (current.dx + delta.dx).clamp(0.0, 1.0),
        (current.dy + delta.dy).clamp(0.0, 1.0),
      ),
    );
    AppLogger.info('mapping.calibration_corner_nudged', {
      'device_id': deviceId,
      'corner_index': index,
      'delta_x': delta.dx,
      'delta_y': delta.dy,
    });
    await _announceNudge(_cornerName(index), delta);
  }

  Future<void> nudgePoint(int index, Offset delta) async {
    if (index < 0 || index >= _points.length) return;
    final point = _points[index];
    _points[index] = ButtonPoint(
      id: point.id,
      label: point.label,
      position: Offset(
        (point.position.dx + delta.dx).clamp(0.0, 1.0),
        (point.position.dy + delta.dy).clamp(0.0, 1.0),
      ),
    );
    notifyListeners();
    AppLogger.info('mapping.button_position_nudged', {
      'device_id': deviceId,
      'button_id': point.id,
      'delta_x': delta.dx,
      'delta_y': delta.dy,
    });
    await _announceNudge(point.label, delta);
  }

  String _cornerName(int index) => const ['좌상단', '우상단', '우하단', '좌하단'][index];

  Future<void> _announceNudge(String label, Offset delta) async {
    final direction = delta.dx < 0
        ? '왼쪽'
        : delta.dx > 0
        ? '오른쪽'
        : delta.dy < 0
        ? '위쪽'
        : '아래쪽';
    FeedbackService.instance.vibrateSuccess();
    await _tts.speak('$label 위치를 $direction 방향으로 0.5퍼센트 이동했습니다.');
  }

  void restartCalibration() {
    final hadCalibration = _panelCalibration != null;
    _calibrationCorners.clear();
    _panelCalibration = null;
    if (hadCalibration) {
      final revision = ++_calibrationRevision;
      unawaited(_invalidateSavedCalibration('calibration_restarted', revision));
    }
    notifyListeners();
    _tts.speak('패널 보정을 다시 시작합니다. 좌상단 모서리를 터치하세요.');
  }

  Future<String> completeRectangularCalibration({
    required double originXmm,
    required double originYmm,
    required double widthMm,
    required double heightMm,
  }) async {
    if (_calibrationCorners.length != 4) {
      return '사진에서 패널 모서리 네 점을 먼저 지정해 주세요.';
    }
    final values = [originXmm, originYmm, widthMm, heightMm];
    if (values.any((value) => !value.isFinite) ||
        originXmm < 0 ||
        originYmm < 0 ||
        widthMm <= 0 ||
        heightMm <= 0 ||
        originXmm + widthMm > 2000 ||
        originYmm + heightMm > 2000) {
      return '원점은 0 이상이어야 하며 패널 끝 좌표는 2000mm 이하여야 합니다.';
    }
    _imageFingerprint ??= await _computeImageFingerprint();
    final machineCorners = [
      (x: originXmm, y: originYmm),
      (x: originXmm + widthMm, y: originYmm),
      (x: originXmm + widthMm, y: originYmm + heightMm),
      (x: originXmm, y: originYmm + heightMm),
    ];
    final calibration = PanelCalibration(
      imageFingerprint: _imageFingerprint!,
      corners: [
        for (var i = 0; i < 4; i++)
          PanelCalibrationPoint(
            imageX: _calibrationCorners[i].dx,
            imageY: _calibrationCorners[i].dy,
            machineXmm: machineCorners[i].x,
            machineYmm: machineCorners[i].y,
          ),
      ],
    );
    final validation = MappingCalibrationService.calculate(
      calibration: calibration,
      buttonPositions: {
        for (final point in _points)
          point.id: (x: point.position.dx, y: point.position.dy),
      },
    );
    if (!validation.isValid) {
      return _userFacingCalibrationErrors(validation.errors);
    }
    _panelCalibration = calibration;
    _calibrationRevision++;
    notifyListeners();
    await _tts.speak('패널 보정이 완료되었습니다. 이제 버튼 중심을 지정하세요.');
    return '패널 보정 완료';
  }

  Future<void> _invalidateSavedCalibration(String reason, int revision) async {
    final existing = await DeviceMappingService.instance.load(deviceId);
    if (revision != _calibrationRevision) return;
    if (existing.panelCalibration == null &&
        existing.buttonMachinePositions.isEmpty) {
      return;
    }
    await DeviceMappingService.instance.save(
      deviceId,
      DeviceMappingService.invalidatePanelCalibration(existing),
    );
    AppLogger.warn('mapping.calibration_invalidated', {
      'device_id': deviceId,
      'reason': reason,
    });
  }

  Future<void> announcePointTestConfirmation(
    int index, {
    bool moveOnly = false,
  }) async {
    if (index < 0 || index >= _points.length) return;
    await _tts.speak(
      moveOnly
          ? '${_points[index].label} 위치로 누르지 않고 이동합니다. 주변을 확인한 뒤 실행하세요.'
          : '${_points[index].label} 위치에서 실제 누름 테스트를 준비합니다. '
                '주변에 손이나 물건이 없는지 확인한 뒤 실행 버튼을 누르세요.',
      priority: TtsPriority.result,
    );
  }

  Future<String> homeMotion() async {
    final outcome = await _motionController.home(deviceId: deviceId);
    if (_disposed) return outcome.message;
    notifyListeners();
    await _tts.speak(outcome.message, priority: TtsPriority.result);
    return outcome.message;
  }

  Future<void> announceHomeConfirmation() => _tts.speak(
    '원점 설정 버튼입니다. 한 번 더 누르면 장치가 리미트 스위치 방향으로 이동합니다.',
    priority: TtsPriority.result,
  );

  Future<void> announceHighRiskConfirmation(int index) async {
    if (index < 0 || index >= _points.length) return;
    await _tts.speak(
      '${_points[index].label} 버튼은 실제 기기를 작동시키거나 상태를 바꿀 수 있습니다. '
      '실제 누름 허용 버튼을 선택해야 실행됩니다.',
      priority: TtsPriority.result,
    );
  }

  String _userFacingCalibrationErrors(List<String> errors) {
    var message = errors.join(' ');
    for (final point in _points) {
      message = message.replaceAll(point.id, point.label);
    }
    return message;
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

  Future<PointVerificationExecution> movePointOnly(int index) =>
      _executePoint(index, MappingVerificationMode.moveOnly);

  Future<PointVerificationExecution> testPointDetailed(int index) =>
      _executePoint(index, MappingVerificationMode.press);

  /// 기존 호출부 호환용. 새 UI는 좌표와 엔코더 오차를 받기 위해
  /// [testPointDetailed]을 사용한다.
  Future<String> testPoint(int index) async =>
      (await testPointDetailed(index)).message;

  Future<PointVerificationExecution> _executePoint(
    int index,
    MappingVerificationMode mode,
  ) async {
    if (index < 0 || index >= _points.length) {
      return PointVerificationExecution(
        ok: false,
        message: '테스트할 버튼을 찾지 못했습니다.',
        buttonId: '',
        label: '알 수 없는 버튼',
        mode: mode,
        failure: MotionFailure.invalidTarget.name,
      );
    }

    final point = _points[index];
    final calibration = _panelCalibration;
    if (calibration == null) {
      const message = '실제 좌표 보정을 완료한 뒤 버튼을 테스트해 주세요.';
      await _tts.speak(message);
      return PointVerificationExecution(
        ok: false,
        message: message,
        buttonId: point.id,
        label: point.label,
        mode: mode,
        failure: MotionFailure.invalidTarget.name,
      );
    }
    final calibrated = MappingCalibrationService.calculate(
      calibration: calibration,
      buttonPositions: {point.id: (x: point.position.dx, y: point.position.dy)},
    );
    if (!calibrated.isValid) {
      final message = _userFacingCalibrationErrors(calibrated.errors);
      await _tts.speak(message);
      return PointVerificationExecution(
        ok: false,
        message: message,
        buttonId: point.id,
        label: point.label,
        mode: mode,
        failure: MotionFailure.invalidTarget.name,
      );
    }

    final target = calibrated.machinePositions[point.id]!;
    final outcome = mode == MappingVerificationMode.moveOnly
        ? await _motionController.moveTo(
            deviceId: deviceId,
            xMm: target.xMm,
            yMm: target.yMm,
            toleranceMm: 0.7,
          )
        : await _safePressCoordinator.moveAndPress(
            deviceId: deviceId,
            xMm: target.xMm,
            yMm: target.yMm,
            toleranceMm: 0.7,
          );
    if (_disposed) {
      return PointVerificationExecution(
        ok: false,
        message: '화면을 닫아 동작 요청을 취소했습니다. 실제 기기 상태를 확인해 주세요.',
        buttonId: point.id,
        label: point.label,
        mode: mode,
        failure: MotionFailure.stopped.name,
      );
    }
    notifyListeners();

    final message = outcome.ok
        ? mode == MappingVerificationMode.moveOnly
              ? '${point.label} 위치 도착이 확인되었습니다. 실제 버튼 중심과 맞는지 확인해 주세요.'
              : '${point.label} 버튼 누름이 확인되었습니다.'
        : outcome.message;
    await _tts.speak(message, priority: TtsPriority.result);
    final execution = PointVerificationExecution(
      ok: outcome.ok,
      message: message,
      buttonId: point.id,
      label: point.label,
      mode: mode,
      targetXmm: target.xMm,
      targetYmm: target.yMm,
      controllerErrorMm: outcome.positionErrorMm,
      failure: outcome.ok ? null : outcome.failure.name,
    );
    if (!execution.ok) await _recordFailedExecution(execution);
    return execution;
  }

  Future<MappingVerificationRecord?> recordVerification({
    required PointVerificationExecution execution,
    required bool passed,
    double? measuredErrorXmm,
    double? measuredErrorYmm,
    String? note,
  }) async {
    if (execution.targetXmm == null || execution.targetYmm == null) return null;
    final hasX = measuredErrorXmm != null;
    final hasY = measuredErrorYmm != null;
    if (hasX != hasY ||
        (measuredErrorXmm != null && !measuredErrorXmm.isFinite) ||
        (measuredErrorYmm != null && !measuredErrorYmm.isFinite)) {
      throw ArgumentError('실측 X/Y 오차는 둘 다 유한한 숫자로 입력해야 합니다.');
    }
    final record = MappingVerificationRecord(
      id: 'verify-${DateTime.now().microsecondsSinceEpoch}',
      buttonId: execution.buttonId,
      label: execution.label,
      mode: execution.mode,
      targetXmm: execution.targetXmm!,
      targetYmm: execution.targetYmm!,
      executionOk: execution.ok,
      userPassed: passed,
      controllerErrorMm: execution.controllerErrorMm,
      measuredErrorXmm: measuredErrorXmm,
      measuredErrorYmm: measuredErrorYmm,
      failure: execution.failure,
      note: note?.trim(),
      createdAt: DateTime.now(),
    );
    await MappingVerificationService.instance.add(deviceId, record);
    _verificationRecords = [..._verificationRecords, record];
    if (_verificationRecords.length >
        MappingVerificationService.maxRecordsPerDevice) {
      _verificationRecords = _verificationRecords.sublist(
        _verificationRecords.length -
            MappingVerificationService.maxRecordsPerDevice,
      );
    }
    notifyListeners();
    return record;
  }

  Future<MappingVerificationRecord?> _recordFailedExecution(
    PointVerificationExecution execution,
  ) => recordVerification(execution: execution, passed: false);

  void clearPoints() {
    final hadCalibration = _panelCalibration != null;
    _points.clear();
    _calibrationCorners.clear();
    _panelCalibration = null;
    if (hadCalibration) {
      final revision = ++_calibrationRevision;
      unawaited(_invalidateSavedCalibration('mapping_cleared', revision));
    }
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
    final calibration = _panelCalibration;
    if (calibration == null) {
      const message = '패널 모서리와 실제 크기를 먼저 보정해 주세요.';
      await _tts.speak(message);
      return message;
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

      final calibrated = MappingCalibrationService.calculate(
        calibration: calibration,
        buttonPositions: positions,
      );
      if (!calibrated.isValid) {
        final message = _userFacingCalibrationErrors(calibrated.errors);
        await _tts.speak(message, priority: TtsPriority.result);
        return message;
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
        buttonMachinePositions: calibrated.machinePositions,
        panelCalibration: calibration,
        customLabels: customLabels,
        homeRow: profile.homeRow,
        homeCol: profile.homeCol,
        travelHeightZ: profile.travelHeightZ,
        pressDepthZ: profile.pressDepthZ,
        travelFeed: profile.travelFeed,
        pressFeed: profile.pressFeed,
        dwellSeconds: profile.dwellSeconds,
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
    // waiter 선등록 방식: 전송과 응답 대기를 한 호출로 묶어, write 직후 도착한
    // 하드웨어 확인 응답이 유실되던 경쟁(구 sendSetGrid+readResponse)을 없앤다.
    final response = await BleService.instance.sendSetGridWithResponse(
      rows: newProfile.rows,
      cols: newProfile.cols,
      originX: newProfile.originX,
      originY: newProfile.originY,
      pitchX: newProfile.pitchX,
      pitchY: newProfile.pitchY,
      deviceId: deviceId,
      timeout: const Duration(seconds: 5),
    );
    // null = 전송 실패/차단/응답 없음 — 로컬 저장은 됐지만 하드웨어 반영은 미확인.
    if (response == null) {
      return {'message': '매핑 저장 완료 (하드웨어 전송 미확인 — 연결 상태를 확인하세요)'};
    }
    if (response.contains('GRID_CONFIG_UPDATED') ||
        response.toLowerCase().contains('ok')) {
      return {'message': '매핑 저장 및 BLE 보정 완료'};
    }
    return {'message': '매핑 저장 완료 (하드웨어 확인 지연)'};
  }

  @override
  void dispose() {
    _disposed = true;
    _motionController.dispose();
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
    _deviceService.disconnect();
    super.dispose();
  }
}
