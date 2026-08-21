import 'package:flutter_test/flutter_test.dart';
import 'package:touch_bridge/screens/mapping/photo_mapping_view_model.dart';
import 'package:touch_bridge/services/mapping_coordinate_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PhotoMappingViewModel newViewModel() =>
      PhotoMappingViewModel(deviceId: 'test-device');

  group('MappingCoordinateService.detectCellCollisions (셀 충돌 검출)', () {
    test('서로 다른 셀의 버튼들은 충돌이 아니다', () {
      final collisions = MappingCoordinateService.detectCellCollisions(
        points: [
          (label: '시작', x: 0.1, y: 0.1),
          (label: '취소', x: 0.9, y: 0.9),
        ],
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

  group('PhotoMappingViewModel.save 셀 충돌 차단', () {
    test('같은 셀에 두 버튼이 겹치면 저장하지 않고 조정을 안내한다', () async {
      final vm = newViewModel();
      vm.addPoint(const Offset(0.05, 0.05)); // 첫 탭 = 기준점
      vm.addPoint(const Offset(0.10, 0.10)); // BT-01 → (0,0) 셀
      vm.addPoint(const Offset(0.20, 0.20)); // BT-02 → (0,0) 셀 — 충돌

      final message = await vm.save();

      expect(message, contains('겹칩'));
      expect(message, contains('조정'));
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

    test('전부 깨진 응답이면 기존 수동 포인트를 보존한다', () {
      // 과거 버그: 파싱 전에 _points.clear()를 해서, AI 응답이 깨지면
      // 보호자가 찍어둔 수동 포인트까지 사라졌다.
      final vm = newViewModel();
      vm.addPoint(const Offset(0.1, 0.1)); // 기준점
      vm.addPoint(const Offset(0.3, 0.3)); // 수동 포인트 1개

      vm.applyAiMappingResultForTest({
        'buttons': [
          {'x': 'abc', 'y': 'def'},
        ],
      });

      expect(vm.points.length, 1, reason: '기존 수동 포인트가 보존돼야 한다');
    });

    test('빈 응답이면 기존 포인트를 보존한다', () {
      final vm = newViewModel();
      vm.addPoint(const Offset(0.1, 0.1));
      vm.addPoint(const Offset(0.3, 0.3));

      vm.applyAiMappingResultForTest({'buttons': <dynamic>[]});

      expect(vm.points.length, 1);
    });

    test('버튼 수는 9개로 제한된다(초과분 조용한 유실 방지)', () {
      final vm = newViewModel();
      vm.applyAiMappingResultForTest({
        'buttons': [
          for (var i = 0; i < 15; i++)
            {'label': '버튼$i', 'x': (i % 5) * 0.2 + 0.1, 'y': (i ~/ 5) * 0.3 + 0.1},
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
        expect(RegExp(r'^BT-\d{2}$').hasMatch(id), isTrue,
            reason: 'DateTime 문자열 같은 임시 id가 남으면 안 된다: $id');
      }
    });
  });
}
