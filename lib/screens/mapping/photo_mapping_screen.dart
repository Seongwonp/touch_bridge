import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/mapping_coordinate_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import 'widgets/mapping_header.dart';
import 'widgets/calibration_prompt.dart';
import 'widgets/mapping_image_view.dart';
import 'widgets/mapping_markers_layer.dart';
import 'widgets/point_actions_sheet.dart';
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

    _viewModel.addPoint(normalized);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      appBar: TopAppBar(
        title: '버튼 매핑',
        showBack: true,
        actions: [
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
                subtitle: '실제 버튼 위치를 터치하세요',
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
                              child: MappingImageView(imagePath: widget.imagePath),
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
                              redMarkerPosition: _viewModel.redMarkerPosition,
                              points: _viewModel.points,
                              imageRect: imageRect,
                              scale: rs,
                              onRedMarkerDrag: (pos) =>
                                  _viewModel.redMarkerPosition = pos,
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
                            if (_viewModel.redMarkerPosition == null)
                              CalibrationPrompt(scale: rs),
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
                      '현재 ${_viewModel.points.length}/9개 매핑됨',
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
                onPressed: (_viewModel.points.isEmpty || _viewModel.isUploading)
                    ? null
                    : _onTestAllPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                    color: AppColors.primary,
                    width: 1.5 * rs,
                  ),
                  minimumSize: Size(double.infinity, 52 * rs),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14 * rs),
                  ),
                ),
                icon: Icon(Icons.playlist_play_rounded, size: 24 * rs),
                label: Text(
                  '전체 버튼 테스트',
                  style: TextStyle(
                    fontSize: 16 * rs,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(height: 10 * rs),
              ElevatedButton(
                onPressed: (_viewModel.points.isEmpty || _viewModel.isUploading)
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

    // [FIX] 등록 프로세스에서 pushReplacement를 여러 번 사용했으므로,
    // 단순 pop이 아닌 Home 화면까지 안전하게 돌아가도록 popUntil 사용
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _onTestAllPressed() async {
    final message = await _viewModel.testAllPoints();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
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
      onTestTouch: () async {
        final message = await _viewModel.testPoint(index);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      },
      onRename: () => _showEditLabelDialog(index),
      onDelete: () => _viewModel.removePoint(index),
    );
  }
}
