import 'package:flutter/material.dart';
import '../../services/device_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';

class ButtonPoint {
  final String id;
  final Offset position;
  final String label;

  ButtonPoint({required this.id, required this.position, required this.label});
}

class PhotoMappingScreen extends StatefulWidget {
  const PhotoMappingScreen({super.key});

  @override
  State<PhotoMappingScreen> createState() => _PhotoMappingScreenState();
}

class _PhotoMappingScreenState extends State<PhotoMappingScreen> {
  final List<ButtonPoint> _points = [];
  final GlobalKey _imageKey = GlobalKey();
  final DeviceService _deviceService = MockDeviceService();

  @override
  void initState() {
    super.initState();
    _deviceService.connect('TEST_DEVICE');
  }

  void _handleTap(TapUpDetails details) {
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final relativeX = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
    final relativeY = (localPosition.dy / renderBox.size.height).clamp(0.0, 1.0);

    setState(() {
      if (_points.length < 9) {
        _points.add(ButtonPoint(
          id: DateTime.now().toString(),
          position: Offset(relativeX, relativeY),
          label: '버튼 ${_points.length + 1}',
        ));
      }
    });
  }

  void _removePoint(int index) {
    setState(() => _points.removeAt(index));
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
            onPressed: () => setState(() => _points.clear()),
            child: Text('초기화', style: TextStyle(color: Colors.white70, fontSize: 14 * rs)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16 * rs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP 2: 정밀 매핑', style: TextStyle(fontSize: 13 * rs, fontWeight: FontWeight.w700, color: const Color(0xFFE2C62D))),
                    SizedBox(height: ResponsiveScale.v(context, 4)),
                    Text('실제 버튼 위치를 터치하세요', style: TextStyle(fontSize: 24 * rs, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16 * rs),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTapUp: _handleTap,
                              child: Image.network(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuBnqtd9QhBxdz_JPVKIqregy0_eQ3-Kmm7GhJ8UoFacsWE5PEO-nYQkiuURtdw1a2Cs-HJLoqEIedm0jvg30rAPgKdOP31oZW5vxfMBJbKgF91uW3lKKboV4zYLwECV2iUnU_UEVKndaTiSpa38QlC_tjoqt7_M9_T9vRF0bU4s2DcqnJHCe6dAFIbehXzzPXMcudEPtJGpt2aY-AFAF4Mn3vw5n7xiaxpHljgqh7f0myzhl1b-copBdl6DRlJsKMDkY-1Pm1K4y8ZO',
                                key: _imageKey, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.black26),
                              ),
                            ),
                            IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.3))),
                            LayoutBuilder(
                              builder: (context, constraints) => Stack(
                                children: _points.asMap().entries.map((entry) {
                                  final idx = entry.key; final point = entry.value;
                                  return Positioned(
                                    left: point.position.dx * constraints.maxWidth - (20 * rs),
                                    top: point.position.dy * constraints.maxHeight - (20 * rs),
                                    child: _buildMarker(idx, rs),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Container(
                      padding: EdgeInsets.all(12 * rs),
                      decoration: BoxDecoration(color: const Color(0xFF0D1C32), borderRadius: BorderRadius.circular(12 * rs)),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, color: const Color(0xFFFDE047), size: 18 * rs),
                        SizedBox(width: 8 * rs),
                        Text('현재 ${_points.length}/9개 매핑됨', style: TextStyle(color: Colors.white70, fontSize: 13 * rs)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(20 * rs),
              child: ElevatedButton(
                onPressed: _points.isEmpty ? null : () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEB00), foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 60 * rs),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * rs)),
                ),
                child: Text('이 구성으로 저장하기', style: TextStyle(fontSize: 18 * rs, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarker(int index, double rs) {
    return GestureDetector(
      onTap: () => _removePoint(index),
      child: Column(children: [
        Container(
          width: 40 * rs, height: 40 * rs,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEB00).withValues(alpha: 0.9), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2 * rs),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8 * rs)],
          ),
          child: Center(child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18 * rs))),
        ),
        SizedBox(height: 4 * rs),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * rs, vertical: 2 * rs),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4 * rs)),
          child: Text('삭제', style: TextStyle(color: Colors.white, fontSize: 10 * rs)),
        ),
      ]),
    );
  }
}
