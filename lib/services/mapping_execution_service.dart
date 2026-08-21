import 'package:flutter/foundation.dart';

import '../models/command_result.dart';
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
    this.explicitUserMessage,
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

  /// row/col 기반 자동 판정 대신 쓸 사용자 문구(선택). [pressPhysical]처럼
  /// row/col을 쓰지 않는 경로가 아래 자동 판정 로직을 오판하지 않도록 한다.
  final String? explicitUserMessage;

  /// 시각장애인 사용자에게 읽어줄 정직한 문구.
  /// 기술용어(G-code/XYZ/BT-xx)나 내부 좌표를 노출하지 않는다.
  /// (개발자 로그용 상세 문구는 [message]를 그대로 쓴다.)
  String get userMessage {
    if (explicitUserMessage != null) return explicitUserMessage!;
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

  /// [CommandFeedbackService]가 소비하는 신뢰 단계.
  /// dry-run은 아무것도 전송하지 않았으므로 received, 실패는 failed,
  /// 그 외(BLE write 성공)는 sent — 이 서비스에는 GRBL 확인 채널이 없으므로
  /// "확인됨(confirmed)"으로 단정하지 않는다.
  CommandPhase get phase {
    if (!ok) return CommandPhase.failed;
    if (dryRun) return CommandPhase.received;
    return CommandPhase.sent;
  }

  CommandResult toCommandResult() => CommandResult(
    phase: phase,
    userMessage: userMessage,
    developerMessage: message,
  );
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

    final send = await sendGcodeSequenceWithIndex(gcode);

    if (!send.ok) {
      // Z 하강 라인(G1 Z<pressZ>)이 이미 전송된 뒤 실패했다면 누름 핀이
      // 버튼을 누른 채 멈춰 있을 수 있다 — best-effort로 안전 높이 복구를
      // 시도하고, 복구 실패 시에는 사용자에게 물리 상태 확인을 명시 안내한다.
      // >=: 하강 라인 자체에서 실패한 경우도 포함한다. write 실패 후에도 실제
      // 하드웨어에 전달됐을 가능성을 배제할 수 없고, 절대 좌표 복구(G0 Z안전높이)는
      // 핀이 올라가 있는 상태에서는 무해한 no-op이므로 보수적으로 시도한다.
      final zDownIndex = gcode.indexWhere((line) => line.startsWith('G1 Z'));
      final zMayBeDown = zDownIndex >= 0 && send.failedIndex >= zDownIndex;
      var recovered = true;
      if (zMayBeDown) {
        recovered = await _tryRecoverZAbsolute(
          safeZ: profile.travelHeightZ,
          feed: profile.pressFeed,
        );
        AppLogger.warn('mapping.press.z_recovery', {
          'device_id': deviceId,
          'button_id': buttonId,
          'failed_index': send.failedIndex,
          'recovered': recovered,
        });
      }
      return MappingExecutionResult(
        ok: false,
        message:
            '명령 전송 중 오류가 발생했습니다. '
            '(실패 라인: ${send.failedIndex}, Z복구: ${zMayBeDown ? (recovered ? '성공' : '실패') : '불필요'})',
        buttonId: buttonId,
        row: resolved.row,
        col: resolved.col,
        x: x,
        y: y,
        gcode: gcode,
        explicitUserMessage: zMayBeDown && !recovered
            ? '명령 전송이 중간에 끊겼습니다. 누름 장치가 버튼을 누른 채 멈춰 있을 수 '
                  '있으니 기기 상태를 확인하고, 필요하면 비상 정지를 사용해 주세요.'
            : null,
      );
    }

    return MappingExecutionResult(
      ok: true,
      message: '$buttonId XYZ 실행 명령 전송',
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

  /// 저장된 매핑 프로필이 없을 때 쓰는 데모/목데이터 물리 좌표 기반 누름.
  /// [MicrowaveCommandService.btnToPhysical]에 정의된 검증된 좌표로 직접
  /// G-code를 조립해 전송한다. 저장 매핑이 있으면 [pressButton]을 쓴다.
  /// (이전에는 이 로직이 voice_listening_screen.dart에 인라인으로 중복돼 있었다.)
  Future<MappingExecutionResult> pressPhysical(String buttonId) async {
    final phys = MicrowaveCommandService.btnToPhysical(buttonId);
    if (phys == null) {
      return MappingExecutionResult(
        ok: false,
        message: '$buttonId 데모 좌표를 찾지 못했습니다.',
        buttonId: buttonId,
        explicitUserMessage: '등록되지 않은 동작입니다. 자주 쓰는 동작에서 골라 주세요.',
      );
    }
    final targetX = phys.$1;
    final targetY = phys.$2;

    // 각 전송 결과를 즉시 확인하고 실패 시 즉시 반환한다. Dart의 &=는 단락평가를
    // 하지 않으므로 ok &= await ... 패턴은 첫 실패 후에도 이후 명령을 계속 전송한다.
    // Z축이 내려간 채로 원점 복귀 명령이 전송되지 않으면 물리적으로 위험한 상태가 된다.
    //
    // zDown: Z 하강 명령 전송 이후 ~ 상승 명령 성공 전까지 true. 이 구간에서
    // 실패하면 누름 핀이 버튼을 누른 채일 수 있으므로 best-effort 복구를 시도한다.
    var zDown = false;
    Future<MappingExecutionResult> fail() async {
      var recovered = true;
      if (zDown) {
        recovered = await _tryRecoverZRelative();
        AppLogger.warn('mapping.press_physical.z_recovery', {
          'button_id': buttonId,
          'recovered': recovered,
        });
      }
      return MappingExecutionResult(
        ok: false,
        message: '$buttonId 물리 좌표 전송 실패'
            '${zDown ? ' (Z복구: ${recovered ? '성공' : '실패'})' : ''}',
        buttonId: buttonId,
        x: targetX,
        y: targetY,
        explicitUserMessage: zDown && !recovered
            ? '명령 전송이 중간에 끊겼습니다. 누름 장치가 버튼을 누른 채 멈춰 있을 수 '
                  '있으니 기기 상태를 확인하고, 필요하면 비상 정지를 사용해 주세요.'
            : '명령을 보내지 못했습니다. 연결을 확인하고 다시 시도해 주세요.',
      );
    }

    final ble = BleService.instance;
    if (!await ble.sendRaw('G92.1')) return fail(); // 모든 오프셋 취소
    if (!await ble.sendRaw('G92 X0 Y0')) return fail(); // 현재 위치를 (0,0)으로 설정
    if (!await ble.sendRaw('G90')) return fail(); // 절대 좌표 모드 명시
    if (!await ble.sendRaw('G1 X$targetX Y$targetY F1000')) return fail();
    await Future<void>.delayed(const Duration(milliseconds: 1500)); // 이동 시간 확보

    // Z 터치 로직: 상대 좌표(G91)
    if (!await ble.sendRaw('G91')) return fail();
    zDown = true; // 하강 명령을 보내는 시점부터 "눌린 채 멈춤" 가능 구간
    if (!await ble.sendRaw('G1 Z-1.0 F150')) return fail(); // 1.0mm 내려가기
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!await ble.sendRaw('G4 P0.4')) return fail(); // 터치 유지
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!await ble.sendRaw('G1 Z1.0 F150')) return fail(); // 1.0mm 올라오기
    zDown = false; // 상승 명령 전송 성공 — 이후 실패는 눌림 위험 없음
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!await ble.sendRaw('G90')) return fail(); // 다시 절대 좌표 모드로 설정
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!await ble.sendRaw('G1 X0 Y0 F1000')) return fail(); // 원점 복귀
    await Future<void>.delayed(const Duration(milliseconds: 800));

    return MappingExecutionResult(
      ok: true,
      message: '$buttonId 물리 좌표 실행 명령 전송',
      buttonId: buttonId,
      x: targetX,
      y: targetY,
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

  Future<bool> sendGcodeSequence(List<String> gcode) async =>
      (await sendGcodeSequenceWithIndex(gcode)).ok;

  /// G-code를 순서대로 전송하고, 실패 시 실패한 라인 인덱스를 함께 반환한다.
  /// 호출부는 인덱스로 "Z 하강 이후 실패"(핀이 눌린 채 멈춤 위험)를 판별해
  /// 복구 시퀀스를 결정한다.
  Future<({bool ok, int failedIndex})> sendGcodeSequenceWithIndex(
    List<String> gcode,
  ) async {
    for (var i = 0; i < gcode.length; i++) {
      final ok = await BleService.instance.sendRaw(gcode[i]);
      if (!ok) return (ok: false, failedIndex: i);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    return (ok: true, failedIndex: -1);
  }

  /// Z축이 내려간 채 시퀀스가 끊겼을 때의 best-effort 복구 (절대 좌표 경로).
  /// G90 후 안전 높이로 올린다. 연결 자체가 죽었으면 실패할 수 있으며,
  /// 그 경우 호출부가 사용자에게 물리 상태 확인을 안내해야 한다.
  Future<bool> _tryRecoverZAbsolute({
    required double safeZ,
    required int feed,
  }) async {
    final ble = BleService.instance;
    try {
      final abs = await ble.sendRaw('G90');
      final up = await ble.sendRaw('G0 Z${_fmt(safeZ)} F$feed');
      return abs && up;
    } catch (_) {
      return false;
    }
  }

  /// Z축 복구 (상대 좌표 경로 — [pressPhysical] 전용).
  /// G91 상태에서 실패했을 수 있으므로 상대 상승 후 절대 모드로 되돌린다.
  /// 핀이 실제로는 안 내려간 상태에서 실행돼도 패널 반대 방향 1mm 이동이라 무해하다.
  Future<bool> _tryRecoverZRelative() async {
    final ble = BleService.instance;
    try {
      final up = await ble.sendRaw('G1 Z1.0 F150');
      final abs = await ble.sendRaw('G90');
      return up && abs;
    } catch (_) {
      return false;
    }
  }

  String _fmt(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
