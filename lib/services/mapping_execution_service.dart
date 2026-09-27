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
    this.stoppedByEmergency = false,
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

  /// 비상 정지(또는 연결 끊김)로 남은 명령을 보내지 않고 중단한 결과.
  ///
  /// 전송 오류와 구분한다: 이 경우 Z 복구 같은 추가 이동 명령을 보내지 않는다
  /// (정지 직후에 이동 명령을 내는 것 자체가 정지 계약 위반이며, 사용자 안내는
  /// 비상 정지 경로가 ACK 기준으로 따로 한다).
  final bool stoppedByEmergency;

  /// 시각장애인 사용자에게 읽어줄 정직한 문구.
  /// 기술용어(G-code/XYZ/BT-xx)나 내부 좌표를 노출하지 않는다.
  /// (개발자 로그용 상세 문구는 [message]를 그대로 쓴다.)
  String get userMessage {
    if (explicitUserMessage != null) return explicitUserMessage!;
    if (stoppedByEmergency) return '비상 정지로 남은 동작을 취소했습니다.';
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

  /// [epoch]: 상위 시퀀스가 시작 시점에 잡은 실행 토큰([BleService.motionEpoch]).
  /// 넘기지 않으면 이 호출이 시작될 때 잡는다. 모든 대기(`await`) 뒤에 같은 토큰을
  /// 다시 비교해, 대기 중 들어온 비상 정지 이후로는 어떤 줄도 보내지 않는다.
  /// (첫 구현은 하위 전송 함수가 토큰을 새로 잡아, 전송 전 대기 중의 정지가
  /// 무시되는 빈틈이 있었다 — 2026-09-27 재리뷰 P1.)
  Future<MappingExecutionResult> pressButton({
    required String deviceId,
    required DeviceMappingProfile profile,
    required String buttonId,
    Duration afterGridDelay = const Duration(milliseconds: 250),
    bool dryRun = false,
    int? epoch,
  }) async {
    final token = epoch ?? BleService.instance.motionEpoch;
    if (profile.calibrationInvalidated) {
      AppLogger.warn('mapping.press.calibration_invalidated', {
        'device_id': deviceId,
      });
      return const MappingExecutionResult(
        ok: false,
        message: 'Calibration invalidated; execution blocked.',
        explicitUserMessage: '버튼 위치 보정이 필요합니다. 보호자에게 재보정을 요청하세요.',
      );
    }
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

    final machinePosition = resolveMachinePosition(
      profile: profile,
      buttonId: buttonId,
      row: resolved.row,
      col: resolved.col,
    );
    final x = machinePosition.x;
    final y = machinePosition.y;
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
    if (BleService.instance.motionEpoch != token) {
      // 전송 전 대기 중에 비상 정지가 들어왔다. 한 줄도 보내지 않는다.
      AppLogger.warn('mapping.press.cancelled_by_stop', {
        'device_id': deviceId,
        'button_id': buttonId,
        'sent_lines': 0,
      });
      return MappingExecutionResult(
        ok: false,
        message: '비상 정지로 전송을 시작하지 않았습니다. (전송된 라인: 0/${gcode.length})',
        buttonId: buttonId,
        row: resolved.row,
        col: resolved.col,
        x: x,
        y: y,
        gcode: gcode,
        stoppedByEmergency: true,
      );
    }
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

    final send = await sendGcodeSequenceWithIndex(gcode, epoch: token);

    if (send.stopped) {
      // 비상 정지/끊김으로 끊긴 경우: Z 복구 이동 명령을 보내지 않는다.
      // 정지 이후의 물리 상태 안내는 비상 정지 경로(ACK 기준)가 담당한다.
      AppLogger.warn('mapping.press.cancelled_by_stop', {
        'device_id': deviceId,
        'button_id': buttonId,
        'sent_lines': send.failedIndex,
      });
      return MappingExecutionResult(
        ok: false,
        message: '비상 정지로 남은 명령 전송을 취소했습니다. '
            '(전송된 라인: ${send.failedIndex}/${gcode.length})',
        buttonId: buttonId,
        row: resolved.row,
        col: resolved.col,
        x: x,
        y: y,
        gcode: gcode,
        stoppedByEmergency: true,
      );
    }

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
      var stoppedDuringRecovery = false;
      if (zMayBeDown) {
        final recovery = await _tryRecoverZAbsolute(
          safeZ: profile.travelHeightZ,
          feed: profile.pressFeed,
          epoch: token,
        );
        recovered = recovery.recovered;
        stoppedDuringRecovery = recovery.stopped;
        AppLogger.warn('mapping.press.z_recovery', {
          'device_id': deviceId,
          'button_id': buttonId,
          'failed_index': send.failedIndex,
          'recovered': recovered,
          'stopped': stoppedDuringRecovery,
        });
      }
      if (stoppedDuringRecovery) {
        // 복구 도중 정지: 남은 복구 줄을 보내지 않았다. 핀 상태는 미확인이다.
        return MappingExecutionResult(
          ok: false,
          message: '복구 중 비상 정지로 남은 복구 명령을 취소했습니다. '
              '(실패 라인: ${send.failedIndex}, Z 하강 이후)',
          buttonId: buttonId,
          row: resolved.row,
          col: resolved.col,
          x: x,
          y: y,
          gcode: gcode,
          stoppedByEmergency: true,
          explicitUserMessage: '비상 정지로 남은 동작을 취소했습니다. 누름 장치가 버튼을 '
              '누른 채 멈춰 있을 수 있으니 기기 상태를 확인해 주세요.',
        );
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
    // 시퀀스 시작 시점의 안전 카운터. 버튼 사이 대기 중에 비상 정지가 오면
    // 다음 버튼을 누르지 않는다. (한 버튼 안의 줄 단위 검사는
    // [sendGcodeSequenceWithIndex]가 한다.)
    final epoch = BleService.instance.motionEpoch;
    for (final buttonId in buttonIds) {
      if (!dryRun && BleService.instance.motionEpoch != epoch) {
        AppLogger.warn('mapping.sequence.cancelled_by_stop', {
          'device_id': deviceId,
          'next_button_id': buttonId,
        });
        return MappingExecutionResult(
          ok: false,
          message: '비상 정지로 남은 버튼($buttonId 이후)을 누르지 않았습니다.',
          buttonId: buttonId,
          gcode: dryRunGcode,
          stoppedByEmergency: true,
        );
      }
      final result = await pressButton(
        deviceId: deviceId,
        profile: profile,
        buttonId: buttonId,
        dryRun: dryRun,
        epoch: epoch,
      );
      if (!result.ok) return result;
      dryRunGcode.addAll(result.gcode);
      await Future<void>.delayed(betweenPressDelay);
    }
    if (!dryRun && BleService.instance.motionEpoch != epoch) {
      // 마지막 버튼 뒤 대기 중 정지: 보낸 줄은 다 나갔지만 "정상 완료"로
      // 보고하지 않는다. 결과 안내는 비상 정지 경로가 맡는다.
      return MappingExecutionResult(
        ok: false,
        message: '시퀀스 전송 후 대기 중 비상 정지가 들어왔습니다.',
        gcode: dryRunGcode,
        stoppedByEmergency: true,
      );
    }
    return MappingExecutionResult(
      ok: true,
      message: dryRun ? 'dry-run 시퀀스 생성 완료' : '시퀀스 명령 전송 완료',
      gcode: dryRunGcode,
      dryRun: dryRun,
    );
  }

  /// 저장 매핑이 없을 때 여러 버튼을 목데이터 좌표로 연달아 누른다.
  /// 버튼 사이 대기 중의 비상 정지도 같은 실행 토큰으로 막는다 — 호출부가
  /// [pressPhysical]을 직접 반복하면 대기 구간이 보호되지 않는다(재리뷰 P1).
  Future<MappingExecutionResult> pressPhysicalSequence(
    List<String> buttonIds, {
    Duration betweenPressDelay = const Duration(milliseconds: 800),
  }) async {
    final ble = BleService.instance;
    final epoch = ble.motionEpoch;
    for (final buttonId in buttonIds) {
      if (ble.motionEpoch != epoch) {
        AppLogger.warn('mapping.physical_sequence.cancelled_by_stop', {
          'next_button_id': buttonId,
        });
        return MappingExecutionResult(
          ok: false,
          message: '비상 정지로 남은 버튼($buttonId 이후)을 누르지 않았습니다.',
          buttonId: buttonId,
          stoppedByEmergency: true,
        );
      }
      final result = await pressPhysical(buttonId, epoch: epoch);
      if (!result.ok) return result;
      await Future<void>.delayed(betweenPressDelay);
    }
    if (ble.motionEpoch != epoch) {
      return MappingExecutionResult(
        ok: false,
        message: '시퀀스 전송 후 대기 중 비상 정지가 들어왔습니다.',
        stoppedByEmergency: true,
      );
    }
    return const MappingExecutionResult(ok: true, message: '물리 좌표 시퀀스 전송 완료');
  }

  /// 저장된 매핑 프로필이 없을 때 쓰는 데모/목데이터 물리 좌표 기반 누름.
  /// [MicrowaveCommandService.btnToPhysical]에 정의된 검증된 좌표로 직접
  /// G-code를 조립해 전송한다. 저장 매핑이 있으면 [pressButton]을 쓴다.
  /// (이전에는 이 로직이 voice_listening_screen.dart에 인라인으로 중복돼 있었다.)
  Future<MappingExecutionResult> pressPhysical(
    String buttonId, {
    int? epoch,
  }) async {
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
    final ble = BleService.instance;
    // 실행 토큰. 상위 시퀀스가 넘긴 값을 쓰고, 없으면 지금 잡는다. 각 명령 전과
    // 모든 대기 뒤에 비교해, 비상 정지 이후에는 남은 이동·누름 명령을 보내지 않는다.
    final token = epoch ?? ble.motionEpoch;
    var stopped = false;
    Future<bool> raw(String command) async {
      if (ble.motionEpoch != token) {
        stopped = true;
        return false;
      }
      final ok = await ble.sendRaw(command);
      if (!ok && ble.motionEpoch != token) stopped = true;
      return ok;
    }

    MappingExecutionResult stoppedResult({String? detail}) {
      AppLogger.warn('mapping.press_physical.cancelled_by_stop', {
        'button_id': buttonId,
        'z_down': zDown,
      });
      return MappingExecutionResult(
        ok: false,
        message: '$buttonId 비상 정지로 남은 명령 전송 취소'
            '${zDown ? ' (Z 하강 이후)' : ''}${detail == null ? '' : ' — $detail'}',
        buttonId: buttonId,
        x: targetX,
        y: targetY,
        stoppedByEmergency: true,
        explicitUserMessage: zDown
            ? '비상 정지로 남은 동작을 취소했습니다. 누름 장치가 버튼을 누른 채 멈춰 '
                '있을 수 있으니 기기 상태를 확인해 주세요.'
            : null,
      );
    }

    Future<MappingExecutionResult> fail() async {
      // 정지로 끊긴 경우 Z 복구 이동을 보내지 않는다 — 정지 계약 우선.
      if (stopped) return stoppedResult();
      var recovered = true;
      if (zDown) {
        final recovery = await _tryRecoverZRelative(epoch: token);
        recovered = recovery.recovered;
        AppLogger.warn('mapping.press_physical.z_recovery', {
          'button_id': buttonId,
          'recovered': recovered,
          'stopped': recovery.stopped,
        });
        // 복구 도중 정지: 남은 복구 줄을 보내지 않았다.
        if (recovery.stopped) return stoppedResult(detail: '복구 중 정지');
      }
      return MappingExecutionResult(
        ok: false,
        message:
            '$buttonId 물리 좌표 전송 실패'
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

    if (!await raw('G92.1')) return fail(); // 모든 오프셋 취소
    if (!await raw('G92 X0 Y0')) return fail(); // 현재 위치를 (0,0)으로 설정
    if (!await raw('G90')) return fail(); // 절대 좌표 모드 명시
    if (!await raw('G1 X$targetX Y$targetY F1000')) return fail();
    await Future<void>.delayed(const Duration(milliseconds: 1500)); // 이동 시간 확보

    // Z 터치 로직: 상대 좌표(G91)
    if (!await raw('G91')) return fail();
    zDown = true; // 하강 명령을 보내는 시점부터 "눌린 채 멈춤" 가능 구간
    if (!await raw('G1 Z-1.0 F150')) return fail(); // 1.0mm 내려가기
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (!await raw('G4 P0.4')) return fail(); // 터치 유지
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (!await raw('G1 Z1.0 F150')) return fail(); // 1.0mm 올라오기
    zDown = false; // 상승 명령 전송 성공 — 이후 실패는 눌림 위험 없음
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!await raw('G90')) return fail(); // 다시 절대 좌표 모드로 설정
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!await raw('G1 X0 Y0 F1000')) return fail(); // 원점 복귀
    await Future<void>.delayed(const Duration(milliseconds: 800));
    // 마지막 대기 중 정지: 줄은 다 나갔지만 정상 완료로 보고하지 않는다.
    if (ble.motionEpoch != token) {
      stopped = true;
      return stoppedResult(detail: '전송 후 대기 중 정지');
    }

    return MappingExecutionResult(
      ok: true,
      message: '$buttonId 물리 좌표 실행 명령 전송',
      buttonId: buttonId,
      x: targetX,
      y: targetY,
    );
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

  /// 버튼의 실제 장치 좌표(mm)를 결정한다.
  ///
  /// 사진 캘리브레이션으로 확정된 좌표가 있으면 이를 최우선 사용한다. 구버전
  /// 프로필처럼 실제 좌표가 없을 때만 rows/cols 그리드 계산으로 폴백한다.
  ({double x, double y}) resolveMachinePosition({
    required DeviceMappingProfile profile,
    required String buttonId,
    required int row,
    required int col,
  }) {
    final exact = profile.buttonMachinePositions[buttonId];
    if (profile.calibrationInvalidated) {
      throw StateError('Invalidated calibration cannot resolve a target.');
    }
    if (exact != null) return (x: exact.xMm, y: exact.yMm);
    return (
      x: calculateX(profile: profile, col: col),
      y: calculateY(profile: profile, row: row),
    );
  }

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
  ///
  /// [stopped]가 true면 전송 오류가 아니라 비상 정지/끊김([BleService.motionEpoch]
  /// 변화)으로 [failedIndex]번째 줄부터 보내지 않은 것이다. 이 경우 호출부는
  /// 복구 이동 명령을 추가로 보내면 안 된다.
  ///
  /// [epoch]: 상위가 잡은 실행 토큰. 넘기지 않으면 여기서 잡는다(단독 호출용).
  /// 마지막 줄 뒤 대기 중 정지가 오면 줄은 다 나갔어도 `stopped: true`,
  /// `failedIndex: gcode.length`로 보고한다.
  Future<({bool ok, int failedIndex, bool stopped})> sendGcodeSequenceWithIndex(
    List<String> gcode, {
    int? epoch,
  }) async {
    final ble = BleService.instance;
    final token = epoch ?? ble.motionEpoch;
    for (var i = 0; i < gcode.length; i++) {
      if (ble.motionEpoch != token) {
        return (ok: false, failedIndex: i, stopped: true);
      }
      final ok = await ble.sendRaw(gcode[i]);
      if (!ok) {
        // write 대기 중 정지가 들어와 sendRaw가 큐 안에서 취소된 경우도 포함한다.
        final stopped = ble.motionEpoch != token;
        return (ok: false, failedIndex: i, stopped: stopped);
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
    if (ble.motionEpoch != token) {
      return (ok: false, failedIndex: gcode.length, stopped: true);
    }
    return (ok: true, failedIndex: -1, stopped: false);
  }

  /// Z축이 내려간 채 시퀀스가 끊겼을 때의 best-effort 복구 (절대 좌표 경로).
  /// G90 후 안전 높이로 올린다. 연결 자체가 죽었으면 실패할 수 있으며,
  /// 그 경우 호출부가 사용자에게 물리 상태 확인을 안내해야 한다.
  /// 복구 중 비상 정지가 오면 남은 줄을 보내지 않고 `stopped: true`.
  Future<({bool recovered, bool stopped})> _tryRecoverZAbsolute({
    required double safeZ,
    required int feed,
    required int epoch,
  }) async {
    final ble = BleService.instance;
    try {
      if (ble.motionEpoch != epoch) return (recovered: false, stopped: true);
      final abs = await ble.sendRaw('G90');
      if (ble.motionEpoch != epoch) return (recovered: false, stopped: true);
      final up = await ble.sendRaw('G0 Z${_fmt(safeZ)} F$feed');
      return (recovered: abs && up, stopped: ble.motionEpoch != epoch);
    } catch (_) {
      return (recovered: false, stopped: ble.motionEpoch != epoch);
    }
  }

  /// Z축 복구 (상대 좌표 경로 — [pressPhysical] 전용).
  /// G91 상태에서 실패했을 수 있으므로 상대 상승 후 절대 모드로 되돌린다.
  /// 핀이 실제로는 안 내려간 상태에서 실행돼도 패널 반대 방향 1mm 이동이라 무해하다.
  Future<({bool recovered, bool stopped})> _tryRecoverZRelative({
    required int epoch,
  }) async {
    final ble = BleService.instance;
    try {
      if (ble.motionEpoch != epoch) return (recovered: false, stopped: true);
      final up = await ble.sendRaw('G1 Z1.0 F150');
      if (ble.motionEpoch != epoch) return (recovered: false, stopped: true);
      final abs = await ble.sendRaw('G90');
      return (recovered: up && abs, stopped: ble.motionEpoch != epoch);
    } catch (_) {
      return (recovered: false, stopped: ble.motionEpoch != epoch);
    }
  }

  String _fmt(double value) {
    final fixed = value.toStringAsFixed(3);
    return fixed
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
}
