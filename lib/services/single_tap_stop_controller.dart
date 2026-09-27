import 'package:flutter/foundation.dart';

import 'emergency_intent.dart';

/// 실행 중 화면의 **단일 탭** 비상 정지 상태 머신.
///
/// 배경(2026-09-27 외부 리뷰 #3): 버튼을 누르는 실행 구간(≈8초)에는 마이크가
/// 닫히고 화면이 진행 뷰로 바뀌어, 전맹 사용자가 정지하려면 앱바의 전역 비상
/// 버튼을 찾아 **두 번** 탭해야 했다. 실행 중에는 사용자가 이미 "지금 기기가
/// 움직인다"는 것을 알고 있으므로 확인 단계(arm)를 생략하는 것이 정당하다.
///
/// 계약:
/// - [requestStop]은 확인창·두 번째 탭·길게 누르기 없이 즉시 [stop]을 부른다.
///   [stop]은 [EmergencyStopService.stopActiveDevice]처럼 실행 토큰을 무효화하고
///   일반 명령 큐를 우회하는 우선 정지 경로여야 한다(이 클래스는 순서를 만들지 않는다).
/// - 요청이 진행 중일 때 다시 탭하면 새 요청을 만들지 않고 `null`을 돌려준다
///   (중복 정지 명령 방지). 결과가 나온 뒤에는 실패했든 미확인이든 다시 탭할 수 있다.
/// - 결과는 [EmergencyStopOutcome] 그대로다: `acknowledged`(ACK 확인) /
///   `sent && !acknowledged`(전송만 됨, 미확인) / `!sent`(전송 실패).
///   ACK 없이 "정지 완료"라고 말하는 문구는 여기서 만들지 않는다.
class SingleTapStopController extends ChangeNotifier {
  SingleTapStopController({required this.stop});

  /// 실제 정지 경로. 테스트에서는 가짜를 넣는다.
  final Future<EmergencyStopOutcome> Function() stop;

  bool _inFlight = false;
  EmergencyStopOutcome? _lastOutcome;
  int _requestCount = 0;
  bool _disposed = false;

  /// 화면이 dispose된 뒤 늦게 돌아온 정지 응답이 리스너를 깨우지 않게 한다
  /// (ChangeNotifier는 dispose 후 notifyListeners를 assertion으로 막는다).
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// 정지 요청이 진행 중인가 (버튼은 이 동안 비활성).
  bool get inFlight => _inFlight;

  /// 가장 최근 요청의 결과. 아직 요청이 없으면 null.
  EmergencyStopOutcome? get lastOutcome => _lastOutcome;

  /// 실제로 [stop]을 호출한 횟수 (중복 탭 검증용).
  int get requestCount => _requestCount;

  /// 결과가 있고 확인되지 않았으면(미확인·실패) 재시도 가능.
  bool get canRetry =>
      !_inFlight && _lastOutcome != null && !_lastOutcome!.acknowledged;

  /// 단일 탭 정지. 진행 중이면 `null`(무시), 아니면 결과를 돌려준다.
  Future<EmergencyStopOutcome?> requestStop() async {
    if (_inFlight) return null;
    _inFlight = true;
    _requestCount++;
    _notify();
    try {
      final outcome = await stop();
      _lastOutcome = outcome;
      return outcome;
    } catch (e, st) {
      // 정지 경로가 예외로 끝나면 "전송 실패"로 취급한다 — 조용히 삼키면 사용자는
      // 정지가 된 줄 안다.
      debugPrint('single-tap stop threw: $e\n$st');
      _lastOutcome = const EmergencyStopOutcome(
        acknowledged: false,
        sent: false,
        message: '중단하지 못했습니다. 다시 시도해 주세요.',
      );
      return _lastOutcome;
    } finally {
      _inFlight = false;
      _notify();
    }
  }

  /// 새 실행이 시작될 때 이전 결과를 지운다.
  void reset() {
    if (_inFlight) return;
    _lastOutcome = null;
    _notify();
  }
}
