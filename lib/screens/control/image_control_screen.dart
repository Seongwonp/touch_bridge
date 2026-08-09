import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/tts_service.dart';
import '../../services/feedback_service.dart';
import '../../services/mapping_coordinate_service.dart';
import '../../services/mapping_execution_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import '../safety/emergency_stop_screen.dart';

class ImageControlScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String? imagePath;

  const ImageControlScreen({
    super.key,
    required this.deviceId,
    required this.deviceName,
    this.imagePath,
  });

  @override
  State<ImageControlScreen> createState() => _ImageControlScreenState();
}

class _ImageControlScreenState extends State<ImageControlScreen> {
  final TtsService _tts = TtsService();
  DeviceMappingProfile? _profile;
  bool _isLoading = true;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _loadMapping();
  }

  Future<void> _loadMapping() async {
    try {
      final profile = await DeviceMappingService.instance.load(widget.deviceId);
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      _loadImageSize(profile.imagePath ?? widget.imagePath);
      _tts.speak('${widget.deviceName} 제어 화면입니다. 이미지의 버튼을 눌러 조작하세요.');
    } catch (e) {
      setState(() => _isLoading = false);
      _tts.speak('매핑 데이터를 불러오는데 실패했습니다.');
    }
  }

  Future<void> _loadImageSize(String? imagePath) async {
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
      debugPrint('Failed to read control image size: $e');
    }
  }

  Future<void> _handleButtonPress(
    String btId,
    int row,
    int col,
    String label,
  ) async {
    if (!BleService.instance.isConnected) {
      _tts.speak('블루투스가 연결되어 있지 않습니다.');
      return;
    }

    FeedbackService.instance.vibrateSuccess();
    _tts.speak('$label 누름');

    final profile = _profile;
    if (profile == null) {
      _tts.speak('매핑 데이터를 불러오지 못했습니다.');
      return;
    }

    final result = await MappingExecutionService.instance.pressButton(
      deviceId: widget.deviceId,
      profile: profile,
      buttonId: btId,
    );

    if (!result.ok) {
      FeedbackService.instance.playFailure();
      _tts.speak(result.userMessage);
      return;
    }

    FeedbackService.instance.playSuccess();

    // 만약 시작 버튼(BT-05)이라면 비상 정지 화면으로 이동 (예시 로직)
    if (btId == 'BT-05' && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmergencyStopScreen(
            deviceName: widget.deviceName,
            initialSeconds: 30, // 기본 30초
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final buttonPoints = _profile?.buttonMap.entries.toList() ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TopAppBar(title: widget.deviceName, showBack: true),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.all(16 * rs),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24 * rs),
                            child: AspectRatio(
                              aspectRatio: 3 / 4, // 일반적인 사진 비율 유지
                              child: LayoutBuilder(
                                builder: (context, stackConstraints) {
                                  final imageRect =
                                      MappingCoordinateService.fittedImageRect(
                                        containerSize: Size(
                                          stackConstraints.maxWidth,
                                          stackConstraints.maxHeight,
                                        ),
                                        imageSize: _imageSize,
                                      );
                                  return Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      Container(color: Colors.black),
                                      Positioned.fromRect(
                                        rect: imageRect,
                                        child: _buildImage(),
                                      ),
                                      Positioned.fromRect(
                                        rect: imageRect,
                                        child: Container(
                                          color: Colors.black.withValues(
                                            alpha: 0.2,
                                          ),
                                        ),
                                      ),
                                      if (_profile != null)
                                        Stack(
                                          children: buttonPoints.map((entry) {
                                            final btId = entry.key;
                                            final row = entry.value.row;
                                            final col = entry.value.col;

                                            final savedPosition =
                                                _profile!.buttonPositions[btId];
                                            final normalized = Offset(
                                              savedPosition?.x ??
                                                  (col + 0.5) / _profile!.cols,
                                              savedPosition?.y ??
                                                  (row + 0.5) / _profile!.rows,
                                            );
                                            final local =
                                                MappingCoordinateService.localFromNormalized(
                                                  normalized: normalized,
                                                  imageRect: imageRect,
                                                );

                                            return Positioned(
                                              left: local.dx - (24 * rs),
                                              top: local.dy - (24 * rs),
                                              child: _buildButtonMarker(
                                                btId,
                                                row,
                                                col,
                                                rs,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 하단 안내
                      Container(
                        padding: EdgeInsets.all(20 * rs),
                        child: Text(
                          '이미지의 노란 버튼을 눌러 하드웨어를 제어하세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14 * rs,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(height: 10 * rs),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imagePath = _profile?.imagePath ?? widget.imagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.fill,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(rs: 1.0, error: '이미지를 불러올 수 없습니다.');
          },
        );
      }
    }
    return _buildPlaceholder(rs: 1.0);
  }

  Widget _buildPlaceholder({required double rs, String? error}) {
    return Container(
      color: const Color(0xFF1A1A1A),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error != null
                  ? Icons.error_outline_rounded
                  : Icons.image_not_supported_rounded,
              color: Colors.white24,
              size: 64 * rs,
            ),
            if (error != null) ...[
              SizedBox(height: 12 * rs),
              Text(
                error,
                style: TextStyle(color: Colors.white24, fontSize: 14 * rs),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildButtonMarker(String btId, int row, int col, double rs) {
    final label = _getButtonLabel(btId);

    return Semantics(
      label: '$label 버튼',
      button: true,
      child: GestureDetector(
        onTap: () => _handleButtonPress(btId, row, col, label),
        child: Column(
          children: [
            Container(
              width: 48 * rs,
              height: 48 * rs,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2 * rs),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8 * rs,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.touch_app_rounded,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ),
            SizedBox(height: 4 * rs),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 8 * rs,
                vertical: 2 * rs,
              ),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(8 * rs),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10 * rs,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getButtonLabel(String btId) {
    if (_profile != null && _profile!.customLabels.containsKey(btId)) {
      return _profile!.customLabels[btId]!;
    }
    const labels = {
      'BT-01': '10초',
      'BT-02': '30초',
      'BT-03': '1분',
      'BT-04': '5분',
      'BT-05': '시작',
      'BT-06': '취소',
      'BT-07': '해동',
      'BT-08': '우유',
      'BT-09': '자동',
    };
    return labels[btId] ?? btId;
  }
}
