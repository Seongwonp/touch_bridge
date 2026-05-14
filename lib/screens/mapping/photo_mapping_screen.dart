import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/tts_service.dart'; // TtsService 임포트
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
    TtsService().speak('$label 기능은 다음 단계에서 연결됩니다.'); // TTS 안내 추가
  }

  Widget _mappingCell({
    required BuildContext context,
    required String tag,
    required bool active,
  }) {
    return Semantics( // 매핑 셀 Semantics 추가
      label: active ? '$tag 활성화됨. 매핑 완료.' : '$tag 매핑. 버튼',
      button: true,
      child: Material(
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
    return Semantics( // 하단 아이템 Semantics 추가
      label: '$label 탭. ${active ? '현재 선택됨' : ''} 버튼',
      selected: active,
      button: true,
      child: InkWell(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: Stack(
        children: [
          // Background Decoration (Semantics는 필요 없음)
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
                      Semantics( // 메뉴 아이콘 Semantics 추가
                        label: '메뉴 버튼',
                        button: true,
                        child: IconButton(
                          onPressed: () {
                            TtsService().speak('메뉴 화면으로 이동합니다.'); // TTS 안내 추가
                            Navigator.of(context).pop(); // 현재는 뒤로가기 역할
                          },
                          icon: const Icon(Icons.menu, color: Color(0xFFFDE047)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Semantics( // 앱 타이틀 Semantics 추가
                        label: 'Touch Bridge 앱',
                        child: const Text(
                          'Touch Bridge',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            color: Color(0xFFFDE047),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Semantics( // 설정 아이콘 Semantics 추가
                        label: '설정 버튼',
                        button: true,
                        child: Container(
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
                        Semantics( // 단계 안내 Semantics 추가
                          label: '단계 2: 버튼 위치 매핑',
                          child: const Text(
                            'STEP 2: 버튼 위치 매핑',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              color: Color(0xFFE2C62D),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Semantics( // 상세 지시 Semantics 추가
                          label: '2단계: 사진 매핑. 3x3 그리드입니다.',
                          child: const Text(
                            '2단계: 사진 매핑 (3x3 그리드)',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.15,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Semantics(
                                  label: '기기 버튼 매핑을 위한 배경 사진 (카메라로 촬영 필요)',
                                  image: true,
                                  child: Container(
                                    color: const Color(0xFF0D1C32),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_camera_rounded,
                                          size: 64,
                                          color: Color(0x66FDE047),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          '카메라로 기기를 촬영하세요',
                                          style: TextStyle(
                                            color: Color(0x99FDE047),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
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
                          child: Semantics( // 사진 다시 촬영하기 버튼 Semantics 추가
                            label: '사진 다시 촬영하기 버튼',
                            button: true,
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
            child: Semantics( // 매핑 완료 버튼 Semantics 추가
              label: '매핑 완료 버튼',
              button: true,
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
                    onTap: () {
                      TtsService().speak('홈 화면으로 이동합니다.'); // TTS 안내 추가
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const HomeScreen(),
                        ),
                      );
                    },
                  ),
                  _bottomItem(
                    context: context,
                    icon: Icons.photo_camera_rounded,
                    label: '기기',
                    active: true,
                    onTap: () {
                      TtsService().speak('현재 기기 매핑 화면입니다.'); // TTS 안내 추가
                    },
                  ),
                  _bottomItem(
                    context: context,
                    icon: Icons.volume_up_rounded,
                    label: '음성',
                    active: false,
                    onTap: () {
                      TtsService().speak('음성 명령 화면으로 이동합니다.'); // TTS 안내 추가
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute<void>(
                          builder: (_) => const VoiceListeningScreen(),
                        ),
                      );
                    },
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
