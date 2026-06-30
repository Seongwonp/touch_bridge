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
  });

  final bool ok;
  final String message;
  final String? buttonId;
  final int? row;
  final int? col;
}

class MappingExecutionService {
  MappingExecutionService._();
  static final MappingExecutionService instance = MappingExecutionService._();

  Future<MappingExecutionResult> pressButton({
    required String deviceId,
    required DeviceMappingProfile profile,
    required String buttonId,
    Duration afterGridDelay = const Duration(milliseconds: 250),
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

    final gridOk = await BleService.instance.sendSetGrid(
      rows: profile.rows,
      cols: profile.cols,
      originX: profile.originX,
      originY: profile.originY,
      pitchX: profile.pitchX,
      pitchY: profile.pitchY,
      deviceId: deviceId,
    );
    if (!gridOk) {
      AppLogger.warn('mapping.press.grid_failed', {
        'device_id': deviceId,
        'button_id': buttonId,
      });
      return MappingExecutionResult(
        ok: false,
        message: '기기 매핑 정보를 하드웨어로 전송하지 못했습니다.',
        buttonId: buttonId,
        row: resolved.row,
        col: resolved.col,
      );
    }

    await Future<void>.delayed(afterGridDelay);
    final btnNumber = resolved.row * profile.cols + resolved.col + 1;
    AppLogger.info('mapping.press.send', {
      'device_id': deviceId,
      'button_id': buttonId,
      'row': resolved.row,
      'col': resolved.col,
      'cols': profile.cols,
      'btn': btnNumber,
      'x': profile.originX + (resolved.col * profile.pitchX),
      'y': profile.originY + (resolved.row * profile.pitchY),
    });

    final ok = await BleService.instance.sendPress(
      x: resolved.col,
      y: resolved.row,
      cols: profile.cols,
      deviceId: deviceId,
    );

    return MappingExecutionResult(
      ok: ok,
      message: ok ? '$buttonId 실행 명령 전송' : '명령 전송 중 오류가 발생했습니다.',
      buttonId: buttonId,
      row: resolved.row,
      col: resolved.col,
    );
  }

  Future<MappingExecutionResult> pressSequence({
    required String deviceId,
    required DeviceMappingProfile profile,
    required List<String> buttonIds,
    Duration betweenPressDelay = const Duration(milliseconds: 800),
  }) async {
    for (final buttonId in buttonIds) {
      final result = await pressButton(
        deviceId: deviceId,
        profile: profile,
        buttonId: buttonId,
      );
      if (!result.ok) return result;
      await Future<void>.delayed(betweenPressDelay);
    }
    return const MappingExecutionResult(ok: true, message: '시퀀스 실행 완료');
  }

  Future<List<MappingExecutionResult>> testAllButtons({
    required String deviceId,
    required DeviceMappingProfile profile,
    Duration betweenPressDelay = const Duration(milliseconds: 900),
  }) async {
    final ids = profile.buttonMap.keys.toList()..sort();
    final results = <MappingExecutionResult>[];
    for (final buttonId in ids) {
      final result = await pressButton(
        deviceId: deviceId,
        profile: profile,
        buttonId: buttonId,
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
}
