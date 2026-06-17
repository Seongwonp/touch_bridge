import 'dart:io';
import 'package:flutter/material.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import 'widgets/button_marker.dart';
import 'widgets/mapping_header.dart';
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

  void _handleTap(TapUpDetails details, GlobalKey imageKey) {
    final RenderBox? renderBox = imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final relativeX = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
    final relativeY = (localPosition.dy / renderBox.size.height).clamp(0.0, 1.0);

    _viewModel.addPoint(Offset(relativeX, relativeY));
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    final GlobalKey imageKey = GlobalKey();

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      appBar: TopAppBar(
        title: '버튼 매핑',
        showBack: true,
        actions: [
          TextButton(
            onPressed: _viewModel.clearPoints,
            child: Text('초기화', style: TextStyle(color: Colors.white70, fontSize: 14 * rs)),
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
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GestureDetector(
                        onTapUp: (d) => _handleTap(d, imageKey),
                        child: _buildImage(imageKey),
                      ),
                      IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.3))),
                      if (_viewModel.isAiAnalyzing)
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(color: Color(0xFFFFEB00)),
                              SizedBox(height: 16 * rs),
                              Text('AI 분석 중...', style: TextStyle(color: Colors.white, fontSize: 16 * rs, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      LayoutBuilder(
                        builder: (context, constraints) => Stack(
                          children: [
                            if (_viewModel.redMarkerPosition != null)
                              Positioned(
                                left: _viewModel.redMarkerPosition!.dx * constraints.maxWidth - (20 * rs),
                                top: _viewModel.redMarkerPosition!.dy * constraints.maxHeight - (20 * rs),
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    _viewModel.redMarkerPosition = Offset(
                                      (_viewModel.redMarkerPosition!.dx + details.delta.dx / constraints.maxWidth).clamp(0.0, 1.0),
                                      (_viewModel.redMarkerPosition!.dy + details.delta.dy / constraints.maxHeight).clamp(0.0, 1.0),
                                    );
                                  },
                                  child: Container(
                                    width: 40 * rs, height: 40 * rs,
                                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.8), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2 * rs)),
                                    child: Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 20 * rs),
                                  ),
                                ),
                              ),
                            ..._viewModel.points.asMap().entries.map((entry) {
                              final idx = entry.key; final point = entry.value;
                              return Positioned(
                                left: point.position.dx * constraints.maxWidth - (20 * rs),
                                top: point.position.dy * constraints.maxHeight - (20 * rs),
                                child: ButtonMarker(
                                  index: idx,
                                  label: point.label,
                                  rs: rs,
                                  onTap: () => _viewModel.removePoint(idx),
                                  onLongPress: () => _showEditLabelDialog(idx),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      if (_viewModel.redMarkerPosition == null)
                        Center(
                          child: Container(
                            margin: EdgeInsets.all(24 * rs),
                            padding: EdgeInsets.all(20 * rs),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16 * rs),
                              border: Border.all(color: const Color(0xFFFFEB00), width: 2 * rs),
                              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 12 * rs)],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.gps_fixed_rounded, color: const Color(0xFFFFEB00), size: 40 * rs),
                                SizedBox(height: 16 * rs),
                                Text(
                                  '초기 위치 설정 (Calibration)',
                                  style: TextStyle(color: const Color(0xFFFFEB00), fontSize: 18 * rs, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8 * rs),
                                Text(
                                  '가전기기의 기준점(0,0) 위치를\n이미지 위에서 터치해 주세요.',
                                  style: TextStyle(color: Colors.white, fontSize: 14 * rs, height: 1.5),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16 * rs),
              Container(
                padding: EdgeInsets.all(12 * rs),
                decoration: BoxDecoration(color: const Color(0xFF0D1C32), borderRadius: BorderRadius.circular(12 * rs)),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: const Color(0xFFFDE047), size: 18 * rs),
                  SizedBox(width: 8 * rs),
                  Text('현재 ${_viewModel.points.length}/9개 매핑됨', style: TextStyle(color: Colors.white70, fontSize: 13 * rs)),
                ]),
              ),
              SizedBox(height: 16 * rs),
              ElevatedButton(
                onPressed: (_viewModel.points.isEmpty || _viewModel.isUploading) ? null : _onSavePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEB00), foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 60 * rs),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * rs)),
                ),
                child: _viewModel.isUploading
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text('이 구성으로 저장하기', style: TextStyle(fontSize: 18 * rs, fontWeight: FontWeight.w900)),
              ),
              SizedBox(height: 20 * rs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(GlobalKey key) {
    final imagePath = widget.imagePath;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.startsWith('http')) {
        return Image.network(
          imagePath, 
          key: key, 
          fit: BoxFit.cover, 
          errorBuilder: (c, e, s) {
            debugPrint('Error loading network image: $e');
            return Container(color: Colors.black26);
          }
        );
      } else {
        final file = File(imagePath);
        if (!file.existsSync()) {
          debugPrint('Image file does not exist at path: $imagePath');
          return Container(color: Colors.black45, child: const Center(child: Icon(Icons.broken_image, color: Colors.white54)));
        }
        return Image.file(
          file, 
          key: key, 
          fit: BoxFit.cover, 
          errorBuilder: (c, e, s) {
            debugPrint('Error loading file image: $e');
            return Container(color: Colors.black26);
          }
        );
      }
    }
    return Image.network(
      'https://lh3.googleusercontent.com/aida-public/AB6AXuBnqtd9QhBxdz_JPVKIqregy0_eQ3-Kmm7GhJ8UoFacsWE5PEO-nYQkiuURtdw1a2Cs-HJLoqEIedm0jvg30rAPgKdOP31oZW5vxfMBJbKgF91uW3lKKboV4zYLwECV2iUnU_UEVKndaTiSpa38QlC_tjoqt7_M9_T9vRF0bU4s2DcqnJHCe6dAFIbehXzzPXMcudEPtJGpt2aY-AFAF4Mn3vw5n7xiaxpHljgqh7f0myzhl1b-copBdl6DRlJsKMDkY-1Pm1K4y8ZO',
      key: key, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.black26),
    );
  }

  Future<void> _onSavePressed() async {
    final message = await _viewModel.save();
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    
    // [FIX] 등록 프로세스에서 pushReplacement를 여러 번 사용했으므로, 
    // 단순 pop이 아닌 Home 화면까지 안전하게 돌아가도록 popUntil 사용
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showEditLabelDialog(int index) async {
    final point = _viewModel.points[index];
    final controller = TextEditingController(text: point.label);
    
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('버튼 이름 설정', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '예: 시작, 30초, 해동',
            hintStyle: TextStyle(color: Colors.white30),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFFFFEB00))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFEB00)),
            child: const Text('확인', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty) {
      _viewModel.updatePointLabel(index, newLabel);
    }
  }
}
