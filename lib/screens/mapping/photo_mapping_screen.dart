import 'package:flutter/material.dart';
import '../../services/device_service.dart';

/// 사용자가 사진 위에서 선택한 버튼의 좌표 정보
class ButtonPoint {
  final String id;
  final Offset position; // 0.0 ~ 1.0 사이의 상대 좌표 (기기 대응용)
  final String label;

  ButtonPoint({
    required this.id,
    required this.position,
    required this.label,
  });
}

class PhotoMappingScreen extends StatefulWidget {
  const PhotoMappingScreen({super.key});

  @override
  State<PhotoMappingScreen> createState() => _PhotoMappingScreenState();
}

class _PhotoMappingScreenState extends State<PhotoMappingScreen> {
  final List<ButtonPoint> _points = [];
  final GlobalKey _imageKey = GlobalKey();
  
  // 가상 서비스 사용
  final DeviceService _deviceService = MockDeviceService();

  @override
  void initState() {
    super.initState();
    // 테스트용 연결
    _deviceService.connect('TEST_DEVICE');
  }

  void _handleTap(TapUpDetails details) {
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    
    // 이미지 크기에 대한 상대적 좌표 계산 (0.0 ~ 1.0)
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
    setState(() {
      _points.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: SafeArea(
        child: Column(
          children: [
            // 상단 바
            _buildAppBar(context),
            
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 16),
                    
                    // 매핑 영역
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // 1. 배경 사진 (터치 감지 레이어)
                            GestureDetector(
                              onTapUp: _handleTap,
                              child: Image.network(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuBnqtd9QhBxdz_JPVKIqregy0_eQ3-Kmm7GhJ8UoFacsWE5PEO-nYQkiuURtdw1a2Cs-HJLoqEIedm0jvg30rAPgKdOP31oZW5vxfMBJbKgF91uW3lKKboV4zYLwECV2iUnU_UEVKndaTiSpa38QlC_tjoqt7_M9_T9vRF0bU4s2DcqnJHCe6dAFIbehXzzPXMcudEPtJGpt2aY-AFAF4Mn3vw5n7xiaxpHljgqh7f0myzhl1b-copBdl6DRlJsKMDkY-1Pm1K4y8ZO',
                                key: _imageKey,
                                fit: BoxFit.cover,
                                errorBuilder: (c, e, s) => Container(color: Colors.black26),
                              ),
                            ),
                            
                            // 2. 어두운 오버레이
                            IgnorePointer(
                              child: Container(color: Colors.black.withValues(alpha: 0.3)),
                            ),

                            // 3. 생성된 버튼 마커들
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Stack(
                                  children: _points.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final point = entry.value;
                                    return Positioned(
                                      left: point.position.dx * constraints.maxWidth - 20,
                                      top: point.position.dy * constraints.maxHeight - 20,
                                      child: _buildMarker(idx, point),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    _buildStatusFooter(),
                  ],
                ),
              ),
            ),
            
            // 하단 액션 바
            _buildBottomActionBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x33FDE047))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFFFDE047), size: 20),
          ),
          const Text(
            '버튼 매핑',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFFDE047)),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() => _points.clear()),
            child: const Text('초기화', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'STEP 2: 정밀 매핑',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFE2C62D)),
        ),
        SizedBox(height: 4),
        Text(
          '실제 버튼 위치를 터치하세요',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildMarker(int index, ButtonPoint point) {
    return GestureDetector(
      onTap: () => _removePoint(index),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEB00).withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 8),
              ],
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              '삭제',
              style: TextStyle(color: Colors.white, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFooter() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1C32),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFFFDE047), size: 18),
          const SizedBox(width: 8),
          Text(
            '현재 ${_points.length}/9개 매핑됨 (마커 클릭 시 삭제)',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(
        onPressed: _points.isEmpty ? null : () async {
          // 1. 상대 좌표 리스트 추출
          final offsets = _points.map((p) => p.position).toList();
          
          // 2. 하드웨어 전송 시뮬레이션
          await _deviceService.saveMappingData(offsets);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${_points.length}개의 버튼 위치가 기기에 저장되었습니다.'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFEB00),
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          '이 구성으로 저장하기',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
