import 'package:flutter/material.dart';

/// 가전의 유형 (아이콘 및 추천 로직 분기용)
enum ApplianceType {
  washer,       // 세탁기
  microwave,    // 전자레인지
  dryer,        // 건조기
  airConditioner, // 에어컨
  other         // 기타
}

/// 가전별 설정 및 추천 정보를 담는 모델 클래스
/// 나중에 클라우드(Firebase 등)에 이 데이터 덩어리를 그대로 저장할 수 있습니다.
class ApplianceConfig {
  final String id;
  final String name;
  final ApplianceType type;
  
  // 권장 하드웨어 구성
  final String recommendedKit; // 예: "초슬림 키캡 4개 + 고무휠 1개"
  final String assemblyGuide;  // 부착 가이드 문구
  
  // 기본 제어 값
  final int defaultSensitivity;
  final int defaultSpeed;
  
  // 저장된 버튼 매핑 좌표들 (상대 좌표 0.0 ~ 1.0)
  final List<Offset> mappingPoints;

  ApplianceConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.recommendedKit,
    required this.assemblyGuide,
    this.defaultSensitivity = 70,
    this.defaultSpeed = 50,
    this.mappingPoints = const [],
  });

  // JSON 변환 (클라우드 저장용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toString(),
      'recommendedKit': recommendedKit,
      'assemblyGuide': assemblyGuide,
      'defaultSensitivity': defaultSensitivity,
      'defaultSpeed': defaultSpeed,
      'mappingPoints': mappingPoints.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
    };
  }

  // JSON에서 모델 생성 (클라우드 로딩용)
  factory ApplianceConfig.fromJson(Map<String, dynamic> json) {
    return ApplianceConfig(
      id: json['id'],
      name: json['name'],
      type: ApplianceType.values.firstWhere((e) => e.toString() == json['type']),
      recommendedKit: json['recommendedKit'],
      assemblyGuide: json['assemblyGuide'],
      defaultSensitivity: json['defaultSensitivity'],
      defaultSpeed: json['defaultSpeed'],
      mappingPoints: (json['mappingPoints'] as List)
          .map((p) => Offset(p['x'], p['y']))
          .toList(),
    );
  }
}
