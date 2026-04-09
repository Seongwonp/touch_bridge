import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/home_screen.dart';
import '../voice/voice_listening_screen.dart';

class PhotoMappingScreen extends StatelessWidget {
  const PhotoMappingScreen({super.key});

  void _showPlaceholder(BuildContext context, String label) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label 기능은 다음 단계에서 연결됩니다.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _mappingCell({
    required BuildContext context,
    required String tag,
    required bool active,
  }) {
    return Material(
      color: active ? const Color(0x33FDE047) : Colors.transparent,
      child: InkWell(
        onTap: () => _showPlaceholder(context, '$tag 매핑'),
        child: Center(
          child: active
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Color(0xFFE2C62D),
                      size: 22,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'BT-01 ACTIVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE2C62D),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFCEC6AD),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ASSIGN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFDE047),
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _bottomItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: active ? 18 : 8,
          vertical: active ? 8 : 4,
        ),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFFDE047) : Colors.transparent,
          borderRadius: BorderRadius.circular(28),
          boxShadow: active
              ? const [BoxShadow(color: Color(0x66FDE047), blurRadius: 14)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? const Color(0xFF726300) : const Color(0xB3D6E3FF),
              size: 24,
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active
                    ? const Color(0xFF726300)
                    : const Color(0xB3D6E3FF),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -0.7),
                radius: 1.2,
                colors: [Color(0x2200B8FF), Color(0xFF041329)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0x33FDE047)),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.menu, color: Color(0xFFFDE047)),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Touch Bridge',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: Color(0xFFFDE047),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0x221C2A41),
                        ),
                        child: IconButton(
                          onPressed: () => _showPlaceholder(context, '설정'),
                          icon: const Icon(
                            Icons.settings,
                            color: Color(0xFFFDE047),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STEP 2: 버튼 위치 매핑',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            color: Color(0xFFE2C62D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '2단계: 사진 매핑 (3x3 그리드)',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBnqtd9QhBxdz_JPVKIqregy0_eQ3-Kmm7GhJ8UoFacsWE5PEO-nYQkiuURtdw1a2Cs-HJLoqEIedm0jvg30rAPgKdOP31oZW5vxfMBJbKgF91uW3lKKboV4zYLwECV2iUnU_UEVKndaTiSpa38QlC_tjoqt7_M9_T9vRF0bU4s2DcqnJHCe6dAFIbehXzzPXMcudEPtJGpt2aY-AFAF4Mn3vw5n7xiaxpHljgqh7f0myzhl1b-copBdl6DRlJsKMDkY-1Pm1K4y8ZO',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                        color: const Color(0xFF0D1C32),
                                        child: const Icon(
                                          Icons.image,
                                          size: 96,
                                          color: Color(0x55D6E3FF),
                                        ),
                                      ),
                                ),
                                Container(color: const Color(0x66041329)),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0x55FDE047),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: GridView.count(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    crossAxisCount: 3,
                                    children: [
                                      for (int i = 0; i < 9; i++)
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0x22FDE047),
                                            ),
                                          ),
                                          child: _mappingCell(
                                            context: context,
                                            tag: 'BT-0${i + 1}',
                                            active: i == 4,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: () =>
                                _showPlaceholder(context, '사진 다시 촬영하기'),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF27354C),
                              foregroundColor: const Color(0xFFE2C62D),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(
                              Icons.photo_camera_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              '사진 다시 촬영하기',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(height: 118),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 104,
            child: ElevatedButton.icon(
              onPressed: () => _showPlaceholder(context, '매핑 완료'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDE047),
                foregroundColor: const Color(0xFF726300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 12,
              ),
              icon: const Text(
                '매핑 완료',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              label: const Icon(Icons.arrow_forward_rounded),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 88,
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              decoration: const BoxDecoration(
                color: Color(0xFF0D1C32),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _bottomItem(
                    context: context,
                    icon: Icons.home_rounded,
                    label: '홈',
                    active: false,
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const HomeScreen(),
                      ),
                    ),
                  ),
                  _bottomItem(
                    context: context,
                    icon: Icons.photo_camera_rounded,
                    label: '기기',
                    active: true,
                    onTap: () {},
                  ),
                  _bottomItem(
                    context: context,
                    icon: Icons.volume_up_rounded,
                    label: '음성',
                    active: false,
                    onTap: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute<void>(
                        builder: (_) => const VoiceListeningScreen(),
                      ),
                    ),
                  ),
                  _bottomItem(
                    context: context,
                    icon: Icons.settings_rounded,
                    label: '설정',
                    active: false,
                    onTap: () => _showPlaceholder(context, '설정'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
