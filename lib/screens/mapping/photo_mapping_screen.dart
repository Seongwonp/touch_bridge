import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/mapping_coordinate_service.dart';
import '../../services/mapping_safety_policy.dart';
import '../../services/mapping_verification_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import 'widgets/mapping_header.dart';
import 'widgets/calibration_prompt.dart';
import 'widgets/mapping_image_view.dart';
import 'widgets/mapping_markers_layer.dart';
import 'widgets/point_actions_sheet.dart';
import 'widgets/position_nudge_sheet.dart';
import 'guardian_handoff_screen.dart';
import 'photo_mapping_view_model.dart';

class PhotoMappingScreen extends StatefulWidget {
  final String deviceId;
  final String? imagePath;
  final String? applianceName;
  final String? applianceType;
  final String? bleId;
  final String? bleName;

  const PhotoMappingScreen({
    super.key,
    required this.deviceId,
    this.imagePath,
    this.applianceName,
    this.applianceType,
    this.bleId,
    this.bleName,
  });

  @override
  State<PhotoMappingScreen> createState() => _PhotoMappingScreenState();
}

class _PhotoMappingScreenState extends State<PhotoMappingScreen> {
  late PhotoMappingViewModel _viewModel;
  final GlobalKey _mappingAreaKey = GlobalKey();
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _viewModel = PhotoMappingViewModel(
      deviceId: widget.deviceId,
      applianceName: widget.applianceName,
      applianceType: widget.applianceType,
      imagePath: widget.imagePath,
      bleId: widget.bleId,
      bleName: widget.bleName,
    );
    _viewModel.addListener(_onViewModelUpdate);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.initialize();
      _loadImageSize();
    });
  }

  void _onViewModelUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelUpdate);
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _loadImageSize() async {
    final imagePath = widget.imagePath;
    if (imagePath == null ||
        imagePath.isEmpty ||
        imagePath.startsWith('http')) {
      return;
    }

    try {
      final file = File(imagePath);
      if (!await file.exists()) return;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      if (mounted) setState(() => _imageSize = size);
    } catch (e) {
      debugPrint('Failed to read mapping image size: $e');
    }
  }

  void _handleTap(TapUpDetails details, Rect imageRect) {
    final RenderBox? renderBox =
        _mappingAreaKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final normalized = MappingCoordinateService.normalizedFromLocal(
      localPosition: localPosition,
      imageRect: imageRect,
    );
    if (normalized == null) return;

    final needsDimensions = _viewModel.addPoint(normalized);
    if (needsDimensions) _showCalibrationDimensionsDialog();
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      appBar: TopAppBar(
        title: '설치 모드 · 버튼 매핑',
        showBack: true,
        actions: [
          IconButton(
            tooltip: '패널 다시 보정',
            onPressed: _viewModel.restartCalibration,
            icon: const Icon(Icons.crop_free_rounded),
          ),
          TextButton(
            onPressed: _viewModel.clearPoints,
            child: Text(
              '초기화',
              style: TextStyle(color: Colors.white70, fontSize: 14 * rs),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16 * rs),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16 * rs),
              MappingHeader(
                title: 'STEP 2: 정밀 매핑',
                subtitle: _viewModel.hasPanelCalibration
                    ? '실제 버튼 중심을 터치하세요'
                    : '패널 모서리 네 점을 먼저 지정하세요',
                isAiAnalyzing: _viewModel.isAiAnalyzing,
                hasImage: widget.imagePath != null,
                onAiAnalyze: _viewModel.triggerAiMapping,
                rs: rs,
              ),
              SizedBox(height: ResponsiveScale.v(context, 16)),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16 * rs),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageRect =
                          MappingCoordinateService.fittedImageRect(
                            containerSize: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            imageSize: _imageSize,
                          );
                      return GestureDetector(
                        key: _mappingAreaKey,
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) => _handleTap(d, imageRect),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(color: Colors.black),
                            Positioned.fromRect(
                              rect: imageRect,
                              child: MappingImageView(
                                imagePath: widget.imagePath,
                              ),
                            ),
                            Positioned.fromRect(
                              rect: imageRect,
                              child: IgnorePointer(
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                            MappingMarkersLayer(
                              calibrationCorners: _viewModel.calibrationCorners,
                              points: _viewModel.points,
                              imageRect: imageRect,
                              scale: rs,
                              onCalibrationCornerDrag: (index, pos) =>
                                  _viewModel.updateCalibrationCorner(
                                    index,
                                    pos,
                                  ),
                              onCalibrationCornerTap: _showCornerNudge,
                              onMarkerTap: _showPointActions,
                              onMarkerLongPress: _showEditLabelDialog,
                            ),
                            if (_viewModel.isAiAnalyzing)
                              Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(height: 16 * rs),
                                    Text(
                                      'AI 분석 중...',
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16 * rs,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (!_viewModel.hasPanelCalibration)
                              CalibrationPrompt(
                                scale: rs,
                                selectedCount:
                                    _viewModel.calibrationCornerCount,
                                needsDimensions:
                                    _viewModel.needsCalibrationDimensions,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              SizedBox(height: 16 * rs),
              Container(
                padding: EdgeInsets.all(12 * rs),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1C32),
                  borderRadius: BorderRadius.circular(12 * rs),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: const Color(0xFFFDE047),
                      size: 18 * rs,
                    ),
                    SizedBox(width: 8 * rs),
                    Text(
                      _viewModel.hasPanelCalibration
                          ? '보정 완료 · 현재 ${_viewModel.points.length}/${PhotoMappingViewModel.maxAiButtons}개 매핑됨'
                          : '패널 모서리 ${_viewModel.calibrationCornerCount}/4개 지정됨',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13 * rs,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16 * rs),
              OutlinedButton.icon(
                onPressed: _viewModel.isUploading
                    ? null
                    : _confirmAndHomeMotion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _viewModel.isMotionHomed
                      ? AppColors.success
                      : AppColors.primary,
                  side: BorderSide(
                    color: _viewModel.isMotionHomed
                        ? AppColors.success
                        : AppColors.primary,
                    width: 1.5 * rs,
                  ),
                  minimumSize: Size(double.infinity, 52 * rs),
                ),
                icon: Icon(Icons.home_rounded, size: 24 * rs),
                label: Text(
                  _viewModel.isMotionHomed ? '원점 설정 확인됨' : '검증 전 원점 설정',
                  style: TextStyle(
                    fontSize: 16 * rs,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(height: 10 * rs),
              Semantics(
                liveRegion: true,
                button: true,
                label: '${_viewModel.verificationSummary} 상세 기록 보기',
                child: InkWell(
                  onTap: _showVerificationHistory,
                  borderRadius: BorderRadius.circular(12 * rs),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12 * rs),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12 * rs),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _viewModel.verificationSummary,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13 * rs,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.history_rounded,
                          color: AppColors.secondary,
                          size: 20 * rs,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16 * rs),
              if (_viewModel.needsCalibrationDimensions) ...[
                OutlinedButton.icon(
                  onPressed: _showCalibrationDimensionsDialog,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 1.5 * rs),
                    minimumSize: Size(double.infinity, 52 * rs),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14 * rs),
                    ),
                  ),
                  icon: Icon(Icons.straighten_rounded, size: 24 * rs),
                  label: Text(
                    '실제 패널 크기 입력',
                    style: TextStyle(
                      fontSize: 16 * rs,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                SizedBox(height: 10 * rs),
              ],
              ElevatedButton(
                onPressed:
                    (_viewModel.points.isEmpty ||
                        !_viewModel.hasPanelCalibration ||
                        _viewModel.isUploading)
                    ? null
                    : _onSavePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 60 * rs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16 * rs),
                  ),
                ),
                child: _viewModel.isUploading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        '이 구성으로 저장하기',
                        style: TextStyle(
                          fontSize: 18 * rs,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
              SizedBox(height: 20 * rs),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onSavePressed() async {
    final message = await _viewModel.save();
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));

    if (!message.startsWith('매핑 저장')) return;

    // 저장만 하고 홈으로 돌아가는 대신, "사용자가 정말 혼자 쓸 수 있는지"
    // 확인하는 인수 점검 화면을 거친다(Codex Part B 보호자→사용자 핸드오프 갭).
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuardianHandoffScreen(
          deviceId: widget.deviceId,
          deviceName: widget.applianceName ?? '기기',
        ),
      ),
    );
  }

  Future<void> _showCalibrationDimensionsDialog() async {
    final originX = TextEditingController(text: '0');
    final originY = TextEditingController(text: '0');
    final width = TextEditingController();
    final height = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          '실제 패널 크기',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '프레임 원점에서 패널 좌상단까지의 X/Y와 패널의 실제 폭·높이를 mm로 입력하세요.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _millimeterField(originX, '좌상단 X'),
              _millimeterField(originY, '좌상단 Y'),
              _millimeterField(width, '패널 폭', autofocus: true),
              _millimeterField(height, '패널 높이'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('보정 완료'),
          ),
        ],
      ),
    );
    final controllers = [originX, originY, width, height];
    if (confirmed != true || !mounted) {
      for (final controller in controllers) {
        controller.dispose();
      }
      return;
    }
    final values = controllers
        .map((controller) => double.tryParse(controller.text.trim()))
        .toList(growable: false);
    for (final controller in controllers) {
      controller.dispose();
    }
    if (values.any((value) => value == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 값을 숫자로 입력해 주세요.')));
      return;
    }
    final message = await _viewModel.completeRectangularCalibration(
      originXmm: values[0]!,
      originYmm: values[1]!,
      widthMm: values[2]!,
      heightMm: values[3]!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _millimeterField(
    TextEditingController controller,
    String label, {
    bool autofocus = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(labelText: '$label (mm)'),
    ),
  );

  void _showEditLabelDialog(int index) async {
    final point = _viewModel.points[index];
    final controller = TextEditingController(text: point.label);

    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('버튼 이름 설정', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '예: 시작, 30초, 해동',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('확인', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty) {
      _viewModel.updatePointLabel(index, newLabel);
    }
  }

  void _showPointActions(int index) {
    final point = _viewModel.points[index];
    final rs = ResponsiveScale.factor(context);
    showPointActionsSheet(
      context: context,
      label: point.label,
      scale: rs,
      onMoveOnly: () => _confirmAndMovePoint(index),
      onTestTouch: () => _confirmAndTestPoint(index),
      onRename: () => _showEditLabelDialog(index),
      onNudge: () => _showPointNudge(index),
      onDelete: () => _viewModel.removePoint(index),
    );
  }

  void _showCornerNudge(int index) {
    const names = ['좌상단', '우상단', '우하단', '좌하단'];
    showPositionNudgeSheet(
      context: context,
      targetLabel: '패널 ${names[index]} 모서리',
      onNudge: (delta) => _viewModel.nudgeCalibrationCorner(index, delta),
    );
  }

  void _showPointNudge(int index) {
    showPositionNudgeSheet(
      context: context,
      targetLabel: _viewModel.points[index].label,
      onNudge: (delta) => _viewModel.nudgePoint(index, delta),
    );
  }

  Future<void> _confirmAndHomeMotion() async {
    await _viewModel.announceHomeConfirmation();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          '원점 설정',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '장치가 X/Y 리미트 스위치 방향으로 움직입니다. 이동 경로에 손이나 물건이 없는지 확인하세요.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            child: const Text('원점 설정 실행'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final message = await _viewModel.homeMotion();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _confirmAndMovePoint(int index) async {
    final point = _viewModel.points[index];
    await _viewModel.announcePointTestConfirmation(index, moveOnly: true);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          '위치만 확인',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '${point.label} 위치로 이동하지만 버튼은 누르지 않습니다. 이동 경로에 손이나 물건이 없는지 확인하세요.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('위치로 이동'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final execution = await _viewModel.movePointOnly(index);
    await _handleVerificationExecution(execution);
  }

  Future<void> _confirmAndTestPoint(int index) async {
    final point = _viewModel.points[index];
    await _viewModel.announcePointTestConfirmation(index);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          '실제 버튼 테스트',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          '${point.label} 위치로 이동한 뒤 실제 누름 동작을 수행합니다. 주변에 손이나 물건이 없는지 확인하세요.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.black,
            ),
            child: const Text('테스트 실행'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (MappingSafetyPolicy.requiresExtraConfirmation(
      buttonId: point.id,
      label: point.label,
    )) {
      await _viewModel.announceHighRiskConfirmation(index);
      if (!mounted) return;
      final extraConfirmed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: const Text(
            '위험 버튼 추가 확인',
            style: TextStyle(color: AppColors.warning),
          ),
          content: Text(
            '${point.label} 버튼은 기기를 시작·정지하거나 결과를 출력할 수 있습니다. 실제 작동을 허용하시겠습니까?',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('실행하지 않음'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emergency,
                foregroundColor: Colors.white,
              ),
              child: const Text('실제 누름 허용'),
            ),
          ],
        ),
      );
      if (extraConfirmed != true) return;
    }
    final execution = await _viewModel.testPointDetailed(index);
    await _handleVerificationExecution(execution);
  }

  Future<void> _handleVerificationExecution(
    PointVerificationExecution execution,
  ) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(execution.message)));
    if (!execution.ok) return;
    await _showVerificationRecordDialog(execution);
  }

  Future<void> _showVerificationRecordDialog(
    PointVerificationExecution execution,
  ) async {
    final errorX = TextEditingController();
    final errorY = TextEditingController();
    final note = TextEditingController();
    final input = await showDialog<_VerificationInput>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text(
          '검증 결과 기록',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '실제 포인터와 버튼 중심의 차이를 mm로 측정했다면 X/Y 오차를 입력하세요. '
                '오른쪽·아래쪽은 양수, 왼쪽·위쪽은 음수입니다.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              _millimeterField(errorX, '실측 X 오차'),
              _millimeterField(errorY, '실측 Y 오차'),
              TextField(
                controller: note,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  hintText: '예: 중심보다 약간 오른쪽',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('기록 안 함'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(
              ctx,
              _VerificationInput(
                passed: false,
                errorX: errorX.text,
                errorY: errorY.text,
                note: note.text,
              ),
            ),
            child: const Text('조정 필요'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              ctx,
              _VerificationInput(
                passed: true,
                errorX: errorX.text,
                errorY: errorY.text,
                note: note.text,
              ),
            ),
            child: const Text('통과 기록'),
          ),
        ],
      ),
    );
    errorX.dispose();
    errorY.dispose();
    note.dispose();
    if (input == null || !mounted) return;

    final xText = input.errorX.trim();
    final yText = input.errorY.trim();
    double? x;
    double? y;
    if (xText.isNotEmpty || yText.isNotEmpty) {
      x = double.tryParse(xText);
      y = double.tryParse(yText);
      if (x == null || y == null || !x.isFinite || !y.isFinite) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('실측 X/Y 오차를 모두 숫자로 입력해 주세요.')),
        );
        return;
      }
    }
    final saved = await _viewModel.recordVerification(
      execution: execution,
      passed: input.passed,
      measuredErrorXmm: x,
      measuredErrorYmm: y,
      note: input.note,
    );
    if (!mounted) return;
    final passedTolerance = saved?.passesTolerance(0.7) ?? false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          passedTolerance
              ? '통과 결과를 저장했습니다.'
              : '허용 오차를 넘었거나 조정이 필요한 결과로 저장했습니다.',
        ),
      ),
    );
  }

  void _showVerificationHistory() {
    final records = _viewModel.verificationRecords.reversed.take(20).toList();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '최근 위치 검증 기록',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              if (records.isEmpty)
                const Text(
                  '아직 기록이 없습니다.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (_, index) {
                      final record = records[index];
                      final passed = record.passesTolerance(0.7);
                      final measured = record.measuredRadialErrorMm;
                      final mode =
                          record.mode == MappingVerificationMode.moveOnly
                          ? '위치 확인'
                          : '실제 누름';
                      final details = <String>[
                        mode,
                        '목표 ${record.targetXmm.toStringAsFixed(1)}, '
                            '${record.targetYmm.toStringAsFixed(1)}mm',
                        if (record.controllerErrorMm != null)
                          '엔코더 ${record.controllerErrorMm!.toStringAsFixed(2)}mm',
                        if (measured != null)
                          '실측 ${measured.toStringAsFixed(2)}mm',
                      ].join(' · ');
                      return Semantics(
                        label:
                            '${record.label}, ${passed ? '통과' : '조정 필요'}, $details',
                        child: ListTile(
                          leading: Icon(
                            passed
                                ? Icons.check_circle_rounded
                                : Icons.warning_rounded,
                            color: passed
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          title: Text(
                            '${record.label} · ${passed ? '통과' : '조정 필요'}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            details,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerificationInput {
  const _VerificationInput({
    required this.passed,
    this.errorX = '',
    this.errorY = '',
    this.note = '',
  });

  final bool passed;
  final String errorX;
  final String errorY;
  final String note;
}
