import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance_config.dart';
import '../../services/recommendation_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../mapping/photo_mapping_screen.dart';

class ApplianceSelectionScreen extends StatefulWidget {
  const ApplianceSelectionScreen({super.key});

  @override
  State<ApplianceSelectionScreen> createState() =>
      _ApplianceSelectionScreenState();
}

class _ApplianceSelectionScreenState extends State<ApplianceSelectionScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _announceScreen();
  }

  Future<void> _announceScreen() async {
    await _tts.speak('가전 종류 추천 화면입니다. 추가할 가전을 선택하세요.');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  void _openGuide(ApplianceConfig appliance) {
    HapticFeedback.selectionClick();
    _tts.speak('${appliance.name}를 선택하셨습니다. 추천 가이드를 확인하세요.');
    final hostContext = context;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final rs = ResponsiveScale.factor(sheetContext);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            ResponsiveScale.v(sheetContext, 24),
            ResponsiveScale.v(sheetContext, 24),
            ResponsiveScale.v(sheetContext, 24),
            ResponsiveScale.v(sheetContext, 40),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getIcon(appliance),
                    color: const Color(0xFFFFEB00),
                    size: 28 * rs,
                  ),
                  SizedBox(width: ResponsiveScale.v(sheetContext, 8)),
                  Expanded(
                    child: Text(
                      appliance.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20 * rs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: ResponsiveScale.v(sheetContext, 24)),
              const Text(
                '필요한 부품 구성',
                style: TextStyle(
                  color: Color(0xFFFFEB00),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: ResponsiveScale.v(sheetContext, 12)),
              SizedBox(
                height: ResponsiveScale.v(sheetContext, 104),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: appliance.parts.length,
                  separatorBuilder: (context, index) =>
                      SizedBox(width: ResponsiveScale.v(sheetContext, 12)),
                  itemBuilder: (context, index) {
                    final part = appliance.parts[index];
                    return Container(
                      width: ResponsiveScale.v(sheetContext, 92),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A2A)),
                      ),
                      padding: EdgeInsets.all(
                        ResponsiveScale.v(sheetContext, 8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(part.icon, color: Colors.white70, size: 28 * rs),
                          SizedBox(height: ResponsiveScale.v(sheetContext, 8)),
                          Text(
                            part.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11 * rs,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${part.count}개',
                            style: TextStyle(
                              color: const Color(0xFFFFEB00),
                              fontSize: 11 * rs,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: ResponsiveScale.v(sheetContext, 24)),
              const Text(
                '추천 부착 가이드',
                style: TextStyle(
                  color: Color(0xFFFFEB00),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: ResponsiveScale.v(sheetContext, 8)),
              Text(
                appliance.assemblyGuide,
                style: TextStyle(
                  color: Colors.white70,
                  height: 1.5,
                  fontSize: 14 * rs,
                ),
              ),
              SizedBox(height: ResponsiveScale.v(sheetContext, 24)),
              SizedBox(
                width: double.infinity,
                height: ResponsiveScale.v(sheetContext, 60),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(hostContext).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoMappingScreen(
                          deviceId: appliance.id,
                          deviceName: appliance.name,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFEB00),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    '가이드 확인 및 매핑 시작',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17 * rs,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIcon(ApplianceConfig appliance) {
    return switch (appliance.type) {
      ApplianceType.washer => Icons.wash_rounded,
      ApplianceType.microwave => Icons.microwave_rounded,
      ApplianceType.dryer => Icons.dry_cleaning_rounded,
      ApplianceType.airConditioner => Icons.ac_unit_rounded,
      ApplianceType.other => Icons.settings_remote_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = RecommendationService.getRecommendations();
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFFFFEB00)),
        title: Text(
          '가전 종류 선택',
          style: TextStyle(
            color: const Color(0xFFFFEB00),
            fontWeight: FontWeight.bold,
            fontSize: 20 * rs,
          ),
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(ResponsiveScale.v(context, 20)),
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final appliance = recommendations[index];
          return Container(
            margin: EdgeInsets.only(bottom: ResponsiveScale.v(context, 16)),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF2A2A2A)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openGuide(appliance),
              child: Padding(
                padding: EdgeInsets.all(ResponsiveScale.v(context, 20)),
                child: Row(
                  children: [
                    Container(
                      width: ResponsiveScale.v(context, 60),
                      height: ResponsiveScale.v(context, 60),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getIcon(appliance),
                        color: const Color(0xFFFFEB00),
                        size: 32 * rs,
                      ),
                    ),
                    SizedBox(width: ResponsiveScale.v(context, 18)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appliance.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18 * rs,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: ResponsiveScale.v(context, 4)),
                          Text(
                            '추천 킷: ${appliance.recommendedKit}',
                            style: TextStyle(
                              color: const Color(0xFF888888),
                              fontSize: 13 * rs,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Color(0xFF444444),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
