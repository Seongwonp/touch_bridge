import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/mapping/photo_mapping_view_model.dart';
import 'package:touch_bridge/services/mapping_coordinate_service.dart';
import 'package:touch_bridge/services/device_mapping_service.dart';
import 'package:touch_bridge/services/esp32_motion_protocol.dart';
import 'package:touch_bridge/services/mapping_verification_service.dart';
import 'package:touch_bridge/services/motion_controller.dart';

void main() {
  test('홈 대기 중 화면을 닫으면 종료된 모델에 알리지 않는다', () async {
    final sent = Completer<void>();
    final transport = _FakeMotionTransport()
      ..onSend = (_, _) => sent.complete();
    final vm = PhotoMappingViewModel(
      deviceId: 'disposed',
      motionTransport: transport,
    );
    final pending = vm.homeMotion();
    await sent.future;
    vm.dispose();
    expect(await pending, contains('취소'));
  });
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  PhotoMappingViewModel newViewModel({MotionTransport? motionTransport}) =>
      PhotoMappingViewModel(
        deviceId: 'test-device',
        motionTransport: motionTransport,
      );

  Future<void> calibrate(PhotoMappingViewModel vm) async {
    vm.addPoint(const Offset(0.05, 0.05));
    vm.addPoint(const Offset(0.95, 0.05));
    vm.addPoint(const Offset(0.95, 0.95));
    vm.addPoint(const Offset(0.05, 0.95));
    final message = await vm.completeRectangularCalibration(
      originXmm: 0,
      originYmm: 0,
      widthMm: 90,
      heightMm: 60,
    );
    expect(message, '패널 보정 완료');
  }

  group('MappingCoordinateService.detectCellCollisions (셀 충돌 검출)', () {
    test('서로 다른 셀의 버튼들은 충돌이 아니다', () {
      final collisions = MappingCoordinateService.detectCellCollisions(
        points: [(label: '시작', x: 0.1, y: 0.1), (label: '취소', x: 0.9, y: 0.9)],
        rows: 3,
        cols: 3,
      );
      expect(collisions, isEmpty);
    });

    test('같은 셀로 양자화되는 버튼들을 그룹으로 보고한다', () {
      // 3x3에서 (0.1,0.1)과 (0.2,0.2)는 모두 (0,0) 셀 — "시작" 자리에서
      // "취소"가 눌릴 수 있는 상태이므로 반드시 검출돼야 한다.
      final collisions = MappingCoordinateService.detectCellCollisions(
        points: [
          (label: '시작', x: 0.1, y: 0.1),
          (label: '취소', x: 0.2, y: 0.2),
          (label: '해동', x: 0.9, y: 0.9),
        ],
        rows: 3,
        cols: 3,
      );
      expect(collisions, [
        ['시작', '취소'],
      ]);
    });

    test('그리드가 촘촘해지면 같은 좌표도 충돌이 해소된다', () {
      final collisions = MappingCoordinateService.detectCellCollisions(
        points: [
          (label: '시작', x: 0.1, y: 0.1),
          (label: '취소', x: 0.25, y: 0.25),
        ],
        rows: 9,
        cols: 9,
      );
      expect(collisions, isEmpty);
    });

    test('0 이하 그리드는 충돌 없음으로 처리한다(예외 금지)', () {
      final collisions = MappingCoordinateService.detectCellCollisions(
        points: [(label: 'A', x: 0.5, y: 0.5)],
        rows: 0,
        cols: 0,
      );
      expect(collisions, isEmpty);
    });
  });

  group('PhotoMappingViewModel.save 실제 좌표 충돌 차단', () {
    test('실제 위치가 2mm보다 가까운 두 버튼은 저장하지 않는다', () async {
      final vm = newViewModel();
      await calibrate(vm);
      vm.addPoint(const Offset(0.50, 0.50));
      vm.addPoint(const Offset(0.51, 0.50)); // X 차이 0.9mm

      final message = await vm.save();

      expect(message, contains('2.0mm보다 가깝습니다'));
    });
  });

  group('PhotoMappingViewModel 버튼식 위치 미세 조정', () {
    test('보정 모서리를 0~1 범위 안에서 0.5% 이동한다', () async {
      final vm = newViewModel();
      vm.addPoint(const Offset(0.05, 0.05));

      await vm.nudgeCalibrationCorner(0, const Offset(-0.5, 0.005));

      expect(vm.calibrationCorners.single, const Offset(0, 0.055));
    });

    test('버튼 위치를 화살표 대안으로 이동한다', () async {
      final vm = newViewModel();
      await calibrate(vm);
      vm.addPoint(const Offset(0.5, 0.5));

      await vm.nudgePoint(0, const Offset(0.005, -0.005));

      expect(vm.points.single.position, const Offset(0.505, 0.495));
    });
  });

  group('PhotoMappingViewModel 4점 보정 저장', () {
    test('보정 완료 전의 이미지 탭은 네 모서리로만 수집한다', () {
      final vm = newViewModel();

      expect(vm.addPoint(const Offset(0.1, 0.1)), isFalse);
      expect(vm.addPoint(const Offset(0.9, 0.1)), isFalse);
      expect(vm.addPoint(const Offset(0.9, 0.9)), isFalse);
      expect(vm.addPoint(const Offset(0.1, 0.9)), isTrue);

      expect(vm.calibrationCornerCount, 4);
      expect(vm.points, isEmpty);
      expect(vm.needsCalibrationDimensions, isTrue);
    });

    test('사진 버튼 중심을 실제 mm 좌표로 변환해 프로필에 저장한다', () async {
      final vm = newViewModel();
      await calibrate(vm);
      vm.addPoint(const Offset(0.5, 0.5));

      final message = await vm.save();
      final profile = await DeviceMappingService.instance.load('test-device');

      expect(message, contains('매핑 저장 완료'));
      expect(profile.panelCalibration, isNotNull);
      expect(profile.buttonMachinePositions['BT-01']?.xMm, closeTo(45, 0.001));
      expect(profile.buttonMachinePositions['BT-01']?.yMm, closeTo(30, 0.001));
    });

    test('사진 지문이 바뀌면 저장된 실제 mm 좌표와 보정을 폐기한다', () async {
      const oldCalibration = PanelCalibration(
        imageFingerprint: 'old-photo',
        corners: [
          PanelCalibrationPoint(
            imageX: 0.1,
            imageY: 0.1,
            machineXmm: 0,
            machineYmm: 0,
          ),
          PanelCalibrationPoint(
            imageX: 0.9,
            imageY: 0.1,
            machineXmm: 90,
            machineYmm: 0,
          ),
          PanelCalibrationPoint(
            imageX: 0.9,
            imageY: 0.9,
            machineXmm: 90,
            machineYmm: 60,
          ),
          PanelCalibrationPoint(
            imageX: 0.1,
            imageY: 0.9,
            machineXmm: 0,
            machineYmm: 60,
          ),
        ],
      );
      await DeviceMappingService.instance.save(
        'fingerprint-device',
        const DeviceMappingProfile(
          rows: 3,
          cols: 3,
          originX: 0,
          originY: 0,
          pitchX: 1,
          pitchY: 1,
          buttonMap: {'BT-01': (row: 1, col: 1)},
          buttonPositions: {'BT-01': (x: 0.5, y: 0.5)},
          buttonMachinePositions: {'BT-01': (xMm: 45, yMm: 30)},
          panelCalibration: oldCalibration,
        ),
      );
      final vm = PhotoMappingViewModel(
        deviceId: 'fingerprint-device',
        imagePath: 'new-photo.jpg',
      );

      await vm.initialize();
      final profile = await DeviceMappingService.instance.load(
        'fingerprint-device',
      );

      expect(vm.hasPanelCalibration, isFalse);
      expect(profile.panelCalibration, isNull);
      expect(profile.buttonMachinePositions, isEmpty);
    });
  });

  group('PhotoMappingViewModel AI 결과 방어 (_applyAiMappingResult)', () {
    test('정상 응답: row/col 항목을 정규화 좌표로 적용한다', () {
      final vm = newViewModel();
      vm.applyAiMappingResultForTest({
        'grid': {'rows': 3, 'cols': 3},
        'buttons': [
          {'button_id': 'BT-01', 'label': '10초', 'row': 0, 'col': 0},
          {'button_id': 'BT-05', 'label': '시작', 'row': 1, 'col': 1},
        ],
      });

      expect(vm.points.length, 2);
      expect(vm.points[0].id, 'BT-01');
      expect(vm.points[1].position.dx, closeTo(0.5, 0.0001));
      expect(vm.points[1].position.dy, closeTo(0.5, 0.0001));
    });

    test('문자열 좌표("0.5")도 안전하게 파싱한다', () {
      final vm = newViewModel();
      vm.applyAiMappingResultForTest({
        'buttons': [
          {'button_id': 'BT-01', 'label': '10초', 'x': '0.25', 'y': '0.75'},
        ],
      });

      expect(vm.points.length, 1);
      expect(vm.points[0].position.dx, closeTo(0.25, 0.0001));
      expect(vm.points[0].position.dy, closeTo(0.75, 0.0001));
    });

    test('깨진 항목은 건너뛰고 나머지는 적용한다(전체 실패 금지)', () {
      final vm = newViewModel();
      vm.applyAiMappingResultForTest({
        'buttons': [
          {'button_id': 'BT-01', 'label': 'A', 'x': 'abc', 'y': 0.1}, // 깨짐
          'garbage', // 깨짐
          {'button_id': 'BT-02', 'label': 'B', 'x': 0.5, 'y': 0.5}, // 정상
        ],
      });

      expect(vm.points.length, 1);
      expect(vm.points[0].id, 'BT-02');
    });

    test('전부 깨진 응답이면 기존 수동 포인트를 보존한다', () async {
      // 과거 버그: 파싱 전에 _points.clear()를 해서, AI 응답이 깨지면
      // 보호자가 찍어둔 수동 포인트까지 사라졌다.
      final vm = newViewModel();
      await calibrate(vm);
      vm.addPoint(const Offset(0.3, 0.3)); // 수동 포인트 1개

      vm.applyAiMappingResultForTest({
        'buttons': [
          {'x': 'abc', 'y': 'def'},
        ],
      });

      expect(vm.points.length, 1, reason: '기존 수동 포인트가 보존돼야 한다');
    });

    test('빈 응답이면 기존 포인트를 보존한다', () async {
      final vm = newViewModel();
      await calibrate(vm);
      vm.addPoint(const Offset(0.3, 0.3));

      vm.applyAiMappingResultForTest({'buttons': <dynamic>[]});

      expect(vm.points.length, 1);
    });

    test('버튼 수는 9개로 제한된다(초과분 조용한 유실 방지)', () {
      final vm = newViewModel();
      vm.applyAiMappingResultForTest({
        'buttons': [
          for (var i = 0; i < 15; i++)
            {
              'label': '버튼$i',
              'x': (i % 5) * 0.2 + 0.1,
              'y': (i ~/ 5) * 0.3 + 0.1,
            },
        ],
      });

      expect(vm.points.length, PhotoMappingViewModel.maxAiButtons);
    });

    test('그리드 폭주 값(rows:1000)은 상한으로 잘린다', () {
      final vm = newViewModel();
      vm.applyAiMappingResultForTest({
        'grid': {'rows': 1000, 'cols': -5},
        'buttons': [
          {'button_id': 'BT-01', 'label': 'A', 'x': 0.5, 'y': 0.5},
        ],
      });

      // 상한/하한 클램프 후에도 항목은 정상 적용돼야 한다.
      expect(vm.points.length, 1);
    });

    test('빈 id는 BT-xx 순번으로 보정되고 중복 id는 재배정된다', () {
      final vm = newViewModel();
      vm.applyAiMappingResultForTest({
        'buttons': [
          {'label': 'A', 'x': 0.1, 'y': 0.1}, // id 없음
          {'button_id': 'BT-01', 'label': 'B', 'x': 0.5, 'y': 0.5},
          {'button_id': 'BT-01', 'label': 'C', 'x': 0.9, 'y': 0.9}, // 중복
        ],
      });

      final ids = vm.points.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'id가 중복되면 안 된다');
      for (final id in ids) {
        expect(
          RegExp(r'^BT-\d{2}$').hasMatch(id),
          isTrue,
          reason: 'DateTime 문자열 같은 임시 id가 남으면 안 된다: $id',
        );
      }
    });
  });

  group('PhotoMappingViewModel M4 안전 검증', () {
    test('원점 설정 전 위치 확인은 전송하지 않고 실패 기록을 남긴다', () async {
      final transport = _FakeMotionTransport();
      final vm = newViewModel(motionTransport: transport);
      await calibrate(vm);
      vm.addPoint(const Offset(0.5, 0.5));

      final result = await vm.movePointOnly(0);

      expect(result.ok, isFalse);
      expect(result.failure, MotionFailure.notHomed.name);
      expect(transport.sent, isEmpty);
      expect(vm.verificationRecords, hasLength(1));
      expect(vm.verificationRecords.single.executionOk, isFalse);
    });

    test('홈 확인 후 move_only 도착 오차와 보호자 실측 오차를 기록한다', () async {
      final transport = _FakeMotionTransport()
        ..onSend = (command, emit) {
          emit(_status(command, Esp32MotionState.received));
          if (command.action == Esp32MotionAction.home) {
            emit(_status(command, Esp32MotionState.homing));
            emit(_status(command, Esp32MotionState.homed, homed: true));
            emit(_status(command, Esp32MotionState.completed, homed: true));
          } else {
            emit(_status(command, Esp32MotionState.moving));
            emit(
              _status(
                command,
                Esp32MotionState.positioned,
                errorMm: 0.2,
                positionToken: 'position-token',
              ),
            );
            emit(_status(command, Esp32MotionState.completed));
          }
        };
      final vm = newViewModel(motionTransport: transport);
      await calibrate(vm);
      vm.addPoint(const Offset(0.5, 0.5));

      expect(await vm.homeMotion(), '원점 설정이 확인되었습니다.');
      final execution = await vm.movePointOnly(0);
      final record = await vm.recordVerification(
        execution: execution,
        passed: true,
        measuredErrorXmm: 0.3,
        measuredErrorYmm: 0.4,
      );

      expect(execution.ok, isTrue);
      expect(execution.controllerErrorMm, 0.2);
      expect(record?.measuredRadialErrorMm, closeTo(0.5, 0.0001));
      expect(record?.passesTolerance(0.7), isTrue);
      expect(transport.sent.last.action, Esp32MotionAction.moveOnly);
      expect(transport.sent.last.xMm, closeTo(45, 0.001));
      expect(transport.sent.last.yMm, closeTo(30, 0.001));
    });

    test('실측 X/Y 중 하나만 입력하면 저장을 거부한다', () async {
      final vm = newViewModel();
      const execution = PointVerificationExecution(
        ok: true,
        message: 'ok',
        buttonId: 'BT-01',
        label: '10초',
        mode: MappingVerificationMode.moveOnly,
        targetXmm: 10,
        targetYmm: 20,
      );

      await expectLater(
        vm.recordVerification(
          execution: execution,
          passed: true,
          measuredErrorXmm: 0.1,
        ),
        throwsArgumentError,
      );
    });
  });
}

typedef _OnSend =
    void Function(
      Esp32MotionCommand command,
      void Function(Esp32MotionStatus status) emit,
    );

class _FakeMotionTransport implements MotionTransport {
  @override
  Stream<String> get stopRequests => const Stream<String>.empty();
  final _statuses = StreamController<Esp32MotionStatus>.broadcast(sync: true);
  final _connections = StreamController<bool>.broadcast(sync: true);
  final sent = <Esp32MotionCommand>[];
  _OnSend? onSend;

  @override
  bool get isConnected => true;

  @override
  Stream<bool> get connectionStates => _connections.stream;

  @override
  Stream<Esp32MotionStatus> get statuses => _statuses.stream;

  @override
  Future<bool> send(Esp32MotionCommand command) async {
    sent.add(command);
    onSend?.call(command, _statuses.add);
    return true;
  }

  @override
  Future<String> sendPriorityStop(String deviceId) async => 'STOPPED';
}

Esp32MotionStatus _status(
  Esp32MotionCommand command,
  Esp32MotionState state, {
  double? errorMm,
  String? positionToken,
  bool? homed,
}) => Esp32MotionStatus(
  commandId: command.commandId,
  state: state,
  errorMm: errorMm,
  positionToken: positionToken,
  homed: homed,
);
