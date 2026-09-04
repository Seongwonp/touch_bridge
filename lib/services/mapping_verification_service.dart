import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

enum MappingVerificationMode { moveOnly, press }

class MappingVerificationRecord {
  const MappingVerificationRecord({
    required this.id,
    required this.buttonId,
    required this.label,
    required this.mode,
    required this.targetXmm,
    required this.targetYmm,
    required this.executionOk,
    required this.userPassed,
    required this.createdAt,
    this.controllerErrorMm,
    this.measuredErrorXmm,
    this.measuredErrorYmm,
    this.failure,
    this.note,
  });

  final String id;
  final String buttonId;
  final String label;
  final MappingVerificationMode mode;
  final double targetXmm;
  final double targetYmm;
  final bool executionOk;
  final bool userPassed;
  final DateTime createdAt;
  final double? controllerErrorMm;
  final double? measuredErrorXmm;
  final double? measuredErrorYmm;
  final String? failure;
  final String? note;

  double? get measuredRadialErrorMm {
    final x = measuredErrorXmm;
    final y = measuredErrorYmm;
    if (x == null || y == null) return null;
    return math.sqrt((x * x) + (y * y));
  }

  bool passesTolerance(double toleranceMm) {
    if (!executionOk || !userPassed) return false;
    final controller = controllerErrorMm;
    if (controller != null && controller > toleranceMm) return false;
    final measured = measuredRadialErrorMm;
    return measured == null || measured <= toleranceMm;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'buttonId': buttonId,
    'label': label,
    'mode': mode.name,
    'targetXmm': targetXmm,
    'targetYmm': targetYmm,
    'executionOk': executionOk,
    'userPassed': userPassed,
    'createdAt': createdAt.toIso8601String(),
    if (controllerErrorMm != null) 'controllerErrorMm': controllerErrorMm,
    if (measuredErrorXmm != null) 'measuredErrorXmm': measuredErrorXmm,
    if (measuredErrorYmm != null) 'measuredErrorYmm': measuredErrorYmm,
    if (failure != null) 'failure': failure,
    if (note != null && note!.isNotEmpty) 'note': note,
  };

  static MappingVerificationRecord? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    double? number(Object? input) => input is num ? input.toDouble() : null;
    final id = value['id'];
    final buttonId = value['buttonId'];
    final label = value['label'];
    final modeName = value['mode'];
    final targetX = number(value['targetXmm']);
    final targetY = number(value['targetYmm']);
    final createdAt = DateTime.tryParse(value['createdAt']?.toString() ?? '');
    final mode = MappingVerificationMode.values
        .where((item) => item.name == modeName)
        .firstOrNull;
    if (id is! String ||
        buttonId is! String ||
        label is! String ||
        mode == null ||
        targetX == null ||
        targetY == null ||
        createdAt == null ||
        value['executionOk'] is! bool ||
        value['userPassed'] is! bool) {
      return null;
    }
    return MappingVerificationRecord(
      id: id,
      buttonId: buttonId,
      label: label,
      mode: mode,
      targetXmm: targetX,
      targetYmm: targetY,
      executionOk: value['executionOk'] as bool,
      userPassed: value['userPassed'] as bool,
      createdAt: createdAt,
      controllerErrorMm: number(value['controllerErrorMm']),
      measuredErrorXmm: number(value['measuredErrorXmm']),
      measuredErrorYmm: number(value['measuredErrorYmm']),
      failure: value['failure'] is String ? value['failure'] as String : null,
      note: value['note'] is String ? value['note'] as String : null,
    );
  }
}

class MappingVerificationService {
  MappingVerificationService._();
  static final MappingVerificationService instance =
      MappingVerificationService._();

  static const int maxRecordsPerDevice = 100;

  String _key(String deviceId) => 'mapping_verification_$deviceId';

  Future<List<MappingVerificationRecord>> load(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(deviceId));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((item) => MappingVerificationRecord.fromJson(item))
          .whereType<MappingVerificationRecord>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(String deviceId, MappingVerificationRecord record) async {
    final records = [...await load(deviceId), record];
    final trimmed = records.length <= maxRecordsPerDevice
        ? records
        : records.sublist(records.length - maxRecordsPerDevice);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(deviceId),
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> clear(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(deviceId));
  }
}
