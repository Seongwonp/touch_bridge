
import '../models/appliance_config.dart';

class RecommendationService {
  RecommendationService._();

  // 추천 킷·부품·부착 가이드는 옛 하드웨어(랙&피니언·키캡) 기준이라 비웠다.
  // 지금 하드웨어(CoreXY 프레임 + SwitchBot Bot)는 가전 종류와 무관하게 같다.
  static final List<ApplianceConfig> presets = [
    ApplianceConfig(
      id: 'microwave_basic',
      name: '일반 전자레인지',
      type: ApplianceType.microwave,
      recommendedKit: '',
      parts: const [],
      assemblyGuide: '',
      defaultSensitivity: 60,
    ),
    ApplianceConfig(
      id: 'washer_front_load',
      name: '드럼 세탁기',
      type: ApplianceType.washer,
      recommendedKit: '',
      parts: const [],
      assemblyGuide: '',
      defaultSensitivity: 85,
    ),
    ApplianceConfig(
      id: 'dryer_tower',
      name: '워시타워 건조기',
      type: ApplianceType.dryer,
      recommendedKit: '',
      parts: const [],
      assemblyGuide: '',
      defaultSensitivity: 75,
    ),
    ApplianceConfig(
      id: 'air_conditioner_basic',
      name: '에어컨',
      type: ApplianceType.airConditioner,
      recommendedKit: '',
      parts: const [],
      assemblyGuide: '',
      defaultSensitivity: 65,
    ),
  ];

  static List<ApplianceConfig> getRecommendations() => presets;

  static ApplianceConfig? findById(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }
}
