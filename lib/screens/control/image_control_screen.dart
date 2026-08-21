import 'dart:async';
import 'dart:io';
import 'dart:math' show max;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../models/command_result.dart';
import '../../services/ble_service.dart';
import '../../services/command_feedback_service.dart';
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

  // 2단계 탭(첫 탭 안내 → 둘째 탭 실행) 상태
  String? _armedButtonId;
  Timer? _armResetTimer;

  @override
  void initState() {
    super.initState();
    _loadMapping();
  }

  @override
  void dispose() {
    _armResetTimer?.cancel();
    super.dispose();
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
      FeedbackService.instance.playFailure();
      _tts.speak(
        '매핑 데이터를 불러오는데 실패했습니다.',
        priority: TtsPriority.result,
      );
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
      // 무반응 dead-end 방지: 실패 earcon + result 우선순위(스크린리더에서도 들림).
      FeedbackService.instance.playFailure();
      _tts.speak(
        '기기가 연결되어 있지 않습니다. 보호자에게 기기 연결을 요청해 주세요.',
        priority: TtsPriority.result,
      );
      return;
    }

    // 2단계 탭: 첫 탭은 안내만, 둘째 탭에서 실제 하드웨어를 누른다(오작동 방지).
    if (_armedButtonId != btId) {
      setState(() => _armedButtonId = btId);
      FeedbackService.instance.vibrateSuccess();
      _armResetTimer?.cancel();
      _armResetTimer = Timer(const Duration(seconds: 15), () {
        if (mounted) setState(() => _armedButtonId = null);
      });
      // arm 안내는 스크린리더가 자동으로 읽어주지 않으므로 result 명시.
      _tts.speak(
        '$label 버튼. 다시 누르면 실행합니다.',
        interrupt: true,
        priority: TtsPriority.result,
      );
      return;
    }

    _armResetTimer?.cancel();
    setState(() => _armedButtonId = null);
    await _executePress(btId, label);
  }

  Future<void> _executePress(String btId, String label) async {
    _tts.speak(
      '$label 실행합니다.',
      interrupt: true,
      priority: TtsPriority.result,
    );

    final profile = _profile;
    if (profile == null) {
      await CommandFeedbackService.instance.announce(
        const CommandResult(
          phase: CommandPhase.failed,
          userMessage: '매핑 데이터를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        ),
        source: 'ImageControlScreen',
      );
      return;
    }

    final result = await MappingExecutionService.instance.pressButton(
      deviceId: widget.deviceId,
      profile: profile,
      buttonId: btId,
    );
    await CommandFeedbackService.instance.announce(
      result.toCommandResult(),
      source: 'ImageControlScreen',
    );
    if (!result.ok) return;

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

                                            // WCAG AA 최소 터치 타겟 44dp 보장.
                                            // rs=0.8(소형 화면)이면 48*0.8=38.4dp로
                                            // 44dp 미만이 되므로 하한을 강제한다.
                                            final markerSize =
                                                max(48.0 * rs, 44.0);
                                            final half = markerSize / 2;

                                            return Positioned(
                                              left: local.dx - half,
                                              top: local.dy - half,
                                              child: _buildButtonMarker(
                                                btId,
                                                row,
                                                col,
                                                rs,
                                                markerSize,
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

  Widget _buildButtonMarker(
    String btId,
    int row,
    int col,
    double rs,
    double markerSize,
  ) {
    final label = _getButtonLabel(btId);
    final armed = _armedButtonId == btId;

    return Semantics(
      label: '$label 버튼',
      hint: armed ? '다시 누르면 실행합니다' : '한 번 누르면 안내합니다',
      button: true,
      child: GestureDetector(
        onTap: () => _handleButtonPress(btId, row, col, label),
        child: Column(
          children: [
            Container(
              width: markerSize,
              height: markerSize,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: (armed ? 4 : 2) * rs,
                ),
                boxShadow: [
                  if (armed)
                    BoxShadow(
                      color: AppColors.primary,
                      blurRadius: 16 * rs,
                      spreadRadius: 2 * rs,
                    ),
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
