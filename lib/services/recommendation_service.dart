import '../models/appliance_config.dart';

/// 가전별 추천 데이터를 제공하는 서비스
class RecommendationService {
  // 실제로는 서버에서 받아오거나 로컬 DB에 저장될 데이터
  static final List<ApplianceConfig> presets = [
    ApplianceConfig(
      id: 'microwave_basic',
      name: '일반 전자레인지',
      type: ApplianceType.microwave,
      recommendedKit: '랙&피니언 구조 1개',
      assemblyGuide: '회전 다이얼이 없는 버튼식 전자레인지의 경우, 중심부에 랙&피니언 킷을 부착하여 버튼을 직접 누르도록 설정하세요.',
      defaultSensitivity: 60,
    ),
    ApplianceConfig(
      id: 'washer_front_load',
      name: '드럼 세탁기',
      type: ApplianceType.washer,
      recommendedKit: '초슬림 키캡 4개 + 고무휠 1개',
      assemblyGuide: '전원 및 시작 버튼에는 키캡을, 다이얼 조작부에는 고무휠을 배치하여 회전과 클릭을 동시에 지원하도록 구성하세요.',
      defaultSensitivity: 85,
    ),
    ApplianceConfig(
      id: 'dryer_tower',
      name: '워시타워 건조기',
      type: ApplianceType.dryer,
      recommendedKit: '고정형 키캡 2개',
      assemblyGuide: '높은 위치에 있는 건조기 버튼은 터치 오류가 잦으므로, 기기를 수직으로 견고하게 고정하는 것이 중요합니다.',
      defaultSensitivity: 75,
    ),
  ];

  static List<ApplianceConfig> getRecommendations() => presets;
}
