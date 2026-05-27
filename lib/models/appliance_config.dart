import 'package:flutter/material.dart';

enum ApplianceType { washer, microwave, dryer, airConditioner, other }

class KitPart {
  KitPart({required this.name, required this.count, required this.icon});

  final String name;
  final int count;
  final IconData icon;

  Map<String, dynamic> toJson() => {
    'name': name,
    'count': count,
    'icon': icon.codePoint,
  };

  factory KitPart.fromJson(Map<String, dynamic> json) {
    return KitPart(
      name: json['name'] as String,
      count: json['count'] as int,
      icon: IconData(json['icon'] as int, fontFamily: 'MaterialIcons'),
    );
  }
}

class ApplianceConfig {
  ApplianceConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.recommendedKit,
    required this.parts,
    required this.assemblyGuide,
    this.defaultSensitivity = 70,
    this.defaultSpeed = 50,
    this.mappingPoints = const [],
  });

  final String id;
  final String name;
  final ApplianceType type;
  final String recommendedKit;
  final List<KitPart> parts;
  final String assemblyGuide;
  final int defaultSensitivity;
  final int defaultSpeed;
  final List<Offset> mappingPoints;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'recommendedKit': recommendedKit,
      'parts': parts.map((part) => part.toJson()).toList(),
      'assemblyGuide': assemblyGuide,
      'defaultSensitivity': defaultSensitivity,
      'defaultSpeed': defaultSpeed,
      'mappingPoints': mappingPoints
          .map((point) => {'x': point.dx, 'y': point.dy})
          .toList(),
    };
  }

  factory ApplianceConfig.fromJson(Map<String, dynamic> json) {
    return ApplianceConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      type: ApplianceType.values.firstWhere(
        (value) => value.name == json['type'],
        orElse: () => ApplianceType.other,
      ),
      recommendedKit: json['recommendedKit'] as String,
      parts: (json['parts'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(KitPart.fromJson)
          .toList(),
      assemblyGuide: json['assemblyGuide'] as String,
      defaultSensitivity: json['defaultSensitivity'] as int? ?? 70,
      defaultSpeed: json['defaultSpeed'] as int? ?? 50,
      mappingPoints: (json['mappingPoints'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()
          .map(
            (point) => Offset(
              (point['x'] as num).toDouble(),
              (point['y'] as num).toDouble(),
            ),
          )
          .toList(),
    );
  }
}
