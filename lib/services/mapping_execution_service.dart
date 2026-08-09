import 'package:flutter/foundation.dart';

import 'app_logger.dart';
import 'ble_service.dart';
import 'device_mapping_service.dart';
import 'microwave_command_service.dart';

class MappingExecutionResult {
  const MappingExecutionResult({
    required this.ok,
    required this.message,
    this.buttonId,
    this.row,
    this.col,
    this.x,
    this.y,
    this.gcode = const [],
    this.dryRun = false,
  });

  final bool ok;
  final String message;
  final String? buttonId;
  final int? row;
  final int? col;
  final double? x;
  final double? y;
  final List<String> gcode;
  final bool dryRun;

  /// 시각장애인 사용자에게 읽어줄 정직한 문구.
  /// 기술용어(G-code/XYZ/BT-xx)나 내부 좌표를 노출하지 않는다.
  /// (개발자 로그용 상세 문구는 [message]를 그대로 쓴다.)
  String get userMessage {
    if (!ok) {
      final mappingMissing = row == null || col == null;
      if (mappingMissing) {
        return '이 동작의 버튼 위치가 등록되지 않았습니다. 보호자에게 버튼 등록을 요청하세요.';
      }
      return '명령을 보내지 못했습니다. 연결을 확인하고 다시 시도해 주세요.';
    }
    if (dryRun) return '동작을 준비했습니다.';
    // 전송 성공은 "기기 동작 확인"이 아니므로 "완료"라고 단언하지 않는다.
    return '기기에 동작을 전달했습니다.';
  }
}

class MappingExecutionService {
  MappingExecutionService._();
  static final MappingExecutionService instance = MappingExecutionService._();

  Future<MappingExecutionResult> pressButton({
    required String deviceId,
    required DeviceMappingProfile profile,
    required String buttonId,
    Duration afterGridDelay = const Duration(milliseconds: 250),
    bool dryRun = false,
  }) async {
    final resolved = resolveButton(profile: profile, buttonId: buttonId);
    if (resolved == null) {
      AppLogger.warn('mapping.press.no_position', {
        'device_id': deviceId,
        'button_id': buttonId,
      });
      return MappingExecutionResult(
        ok: false,
        message: '$buttonId 버튼의 매핑을 찾지 못했습니다.',
        buttonId: buttonId,
      );
    }

    final x = calculateX(profile: profile, col: resolved.col);
    final y = calculateY(profile: profile, row: resolved.row);
    final gcode = buildPressGcode(profile: profile, x: x, y: y);
    final btnNumber = resolved.row * profile.cols + resolved.col + 1;

    AppLogger.info('mapping.press.prepare', {
      'device_id': deviceId,
      'button_id': buttonId,
      'row': resolved.row,
      'col': resolved.col,
      'cols': profile.cols,
      'btn': btnNumber,
      'x': x,
      'y': y,
      'travel_height_z': profile.travelHeightZ,
      'press_depth_z': profile.pressDepthZ,
      'travel_feed': profile.travelFeed,
      'press_feed': profile.pressFeed,
      'dry_run': dryRun,
      'gcode': gcode,
    });

    if (dryRun) {
      return MappingExecutionResult(
        ok: true,
        message: '$buttonId dry-run G-code 생성 완료',
        buttonId: buttonId,
        row: resolved.row,
        col: resolved.col,
        x: x,
        y: y,
        gcode: gcode,
        dryRun: true,
      );
    }

    await Future<void>.delayed(afterGridDelay);
    AppLogger.info('mapping.press.send', {
      'device_id': deviceId,
      'button_id': buttonId,
      'row': resolved.row,
      'col': resolved.col,
      'cols': profile.cols,
      'btn': btnNumber,
      'x': x,
      'y': y,
      'gcode': gcode,
    });

    final ok = await sendGcodeSequence(gcode);

    return MappingExecutionResult(
      ok: ok,
      message: ok ? '$buttonId XYZ 실행 명령 전송' : '명령 전송 중 오류가 발생했습니다.',
      buttonId: buttonId,
      row: resolved.row,
      col: resolved.col,
      x: x,
      y: y,
      gcode: gcode,
    );
  }

  Future<MappingExecutionResult> pressSequence({
    required String deviceId,
    required DeviceMappingProfile profile,
    required List<String> buttonIds,
    Duration betweenPressDelay = const Duration(milliseconds: 800),
    bool dryRun = false,
  }) async {
    final dryRunGcode = <String>[];
    for (final buttonId in buttonIds) {
      final result = await pressButton(
        deviceId: deviceId,
        profile: profile,
        buttonId: buttonId,
        dryRun: dryRun,
      );
      if (!result.ok) return result;
      dryRunGcode.addAll(result.gcode);
      await Future<void>.delayed(betweenPressDelay);
    }
    return MappingExecutionResult(
      ok: true,
      message: dryRun ? 'dry-run 시퀀스 생성 완료' : '시퀀스 명령 전송 완료',
      gcode: dryRunGcode,
      dryRun: dryRun,
    );
  }

  Future<List<MappingExecutionResult>> testAllButtons({
    required String deviceId,
    required DeviceMappingProfile profile,
    Duration betweenPressDelay = const Duration(milliseconds: 900),
    bool dryRun = false,
  }) async {
    final ids = profile.buttonMap.keys.toList()..sort();
    final results = <MappingExecutionResult>[];
    for (final buttonId in ids) {
      final result = await pressButton(
        deviceId: deviceId,
        profile: profile,
        buttonId: buttonId,
        dryRun: dryRun,
      );
      results.add(result);
      if (!result.ok) break;
      await Future<void>.delayed(betweenPressDelay);
    }
    return results;
  }

  ({int row, int col})? resolveButton({
    required DeviceMappingProfile profile,
    required String buttonId,
  }) {
    final mapped = profile.buttonMap[buttonId];
    if (mapped != null) return mapped;

    final fallback = MicrowaveCommandService.btnToGrid(buttonId);
    if (fallback == null) return null;
    if (fallback.$1 >= profile.rows || fallback.$2 >= profile.cols) {
      debugPrint(
        '[MAPPING_EXEC] fallback out of range: $buttonId '
        'row=${fallback.$1} col=${fallback.$2} '
        'grid=${profile.rows}x${profile.cols}',
      );
      return null;
    }
    return (row: fallback.$1, col: fallback.$2);
  }

  double calculateX({
    required DeviceMappingProfile profile,
    required int col,
  }) => profile.originX + (col * profile.pitchX);

  double calculateY({
    required DeviceMappingProfile profile,
    required int row,
  }) => profile.originY + (row * profile.pitchY);

  List<String> buildPressGcode({
    required DeviceMappingProfile profile,
    required double x,
    required double y,
  }) {
    final safeZ = _fmt(profile.travelHeightZ);
    final pressZ = _fmt(profile.pressDepthZ);
    final xf = _fmt(x);
    final yf = _fmt(y);
    final dwell = _fmt(profile.dwellSeconds);
    return [
      'G90',
      'G21',
      'G0 Z$safeZ F${profile.pressFeed}',
      'G0 X$xf Y$yf F${profile.travelFeed}',
      'G1 Z$pressZ F${profile.pressFeed}',
      'G4 P$dwell',
      'G0 Z$safeZ F${profile.pressFeed}',
    ];
  }

  Future<bool> sendGcodeSequence(List<String> gcode) async {
    for (final line in gcode) {
      final ok = await BleService.instance.sendRaw(line);
      if (!ok) return false;
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return true;
  }

  String _fmt(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
