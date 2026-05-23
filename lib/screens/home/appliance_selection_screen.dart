import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../models/appliance_config.dart';
import '../../services/recommendation_service.dart';
import '../mapping/photo_mapping_screen.dart';

class ApplianceSelectionScreen extends StatefulWidget {
  const ApplianceSelectionScreen({super.key});

  @override
  State<ApplianceSelectionScreen> createState() => _ApplianceSelectionScreenState();
}

class _ApplianceSelectionScreenState extends State<ApplianceSelectionScreen> {
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _announceScreen();
  }

  Future<void> _announceScreen() async {
    await _tts.setLanguage('ko-KR');
    await _tts.setSpeechRate(0.45);
    await _tts.speak('가전 종류 선택 화면입니다. 추가할 가전을 선택하세요.');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = RecommendationService.getRecommendations();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('가전 종류 선택', style: TextStyle(color: Color(0xFFFFEB00), fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Color(0xFFFFEB00)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final appliance = recommendations[index];
          return _ApplianceCard(
            appliance: appliance,
            onTap: () {
              HapticFeedback.selectionClick();
              _tts.speak('${appliance.name}를 선택하셨습니다. 추천 가이드를 확인하세요.');
            },
          );
        },
      ),
    );
  }
}

class _ApplianceCard extends StatelessWidget {
  final ApplianceConfig appliance;
  final VoidCallback onTap;
  
  const _ApplianceCard({
    required this.appliance,
    required this.onTap,
  });

  IconData _getIcon() {
    switch (appliance.type) {
      case ApplianceType.washer: return Icons.wash_rounded;
      case ApplianceType.microwave: return Icons.microwave_rounded;
      case ApplianceType.dryer: return Icons.dry_cleaning_rounded;
      case ApplianceType.airConditioner: return Icons.ac_unit_rounded;
      default: return Icons.settings_remote_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: InkWell(
        onTap: () {
          onTap();
          _showGuide(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_getIcon(), color: const Color(0xFFFFEB00), size: 32),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appliance.name,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '추천 킷: ${appliance.recommendedKit}',
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF444444), size: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIcon(), color: const Color(0xFFFFEB00)),
                const SizedBox(width: 8),
                Text(appliance.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 20),
            const Text('추천 부착 가이드', style: TextStyle(color: Color(0xFFFFEB00), fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(appliance.assemblyGuide, style: const TextStyle(color: Colors.white70, height: 1.5)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PhotoMappingScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEB00),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('가이드 확인 및 매핑 시작', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
