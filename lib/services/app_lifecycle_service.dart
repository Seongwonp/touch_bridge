import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:wakelock_plus/wakelock_plus.dart';

import 'active_device_service.dart';
import 'app_logger.dart';
import 'ble_service.dart';
import 'emergency_stop_service.dart';

/// 앱이 앞에 있는 동안 지켜야 할 것들(재연결·화면 켜짐·백엔드 깨우기)의 단일 창구.
///
/// 부스처럼 사람이 붙어 있지 않은 채 몇 시간 켜 두는 환경을 위한 것이다.
/// - 실행·복귀 때 활성 기기가 끊겨 있으면 한 번 조용히 다시 연결한다. 이전에는
///   개발자 콘솔을 열어야만 다시 붙었다. 실패를 말로 알리지 않는 것은 상단
///   BleStatusBanner가 이미 상태를 보여 주고, 화면 안내와 겹치지 않게 하려는 것.
/// - 거치대에 세워 둔 폰이 잠기지 않게 앞에 있는 동안만 화면을 켜 둔다.
/// - Render 무료 백엔드는 쉬면 잠들어 첫 음성 명령이 30초 넘게 걸린다. 앞에 있는
///   동안 /healthz를 주기적으로 불러 깨워 둔다.
///
/// 화면마다 흩어 두지 않고 여기 모아 main.dart에서 한 번만 붙인다.
class AppLifecycleService with WidgetsBindingObserver {
  AppLifecycleService({
    String? Function()? activeBleId,
    bool Function()? isConnected,
    bool Function()? isBusy,
    Future<bool> Function(String bleId)? connect,
    Future<void> Function(bool enable)? setWakelock,
    String Function()? backendUrl,
    Future<int> Function(Uri uri)? httpGet,
    this.keepWarmInterval = const Duration(minutes: 10),
  }) : _activeBleId =
           activeBleId ?? ActiveDeviceService.instance.getActiveBleId,
       _isConnected = isConnected ?? (() => BleService.instance.isConnected),
       _isBusy = isBusy ?? _defaultIsBusy,
       _connect = connect ?? BleService.instance.ensureConnected,
       _setWakelock = setWakelock ?? _defaultSetWakelock,
       _backendUrl = backendUrl ?? _defaultBackendUrl,
       _httpGet = httpGet ?? _defaultHttpGet;

  static final AppLifecycleService instance = AppLifecycleService();

  final String? Function() _activeBleId;
  final bool Function() _isConnected;
  final bool Function() _isBusy;
  final Future<bool> Function(String bleId) _connect;
  final Future<void> Function(bool enable) _setWakelock;
  final String Function() _backendUrl;
  final Future<int> Function(Uri uri) _httpGet;
  final Duration keepWarmInterval;

  bool _started = false;
  // 백그라운드에 갔다가 돌아온 경우만 "복귀"로 본다. 알림창을 내리는 정도의
  // inactive → resumed에서는 재연결·핑을 반복하지 않는다.
  bool _inBackground = false;
  bool _reconnecting = false;
  Timer? _keepWarmTimer;

  /// 앱 실행 직후(ActiveDeviceService.init 이후) 한 번 부른다.
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _onForeground();
  }

  @visibleForTesting
  void stop() {
    if (!_started) return;
    _started = false;
    WidgetsBinding.instance.removeObserver(this);
    _keepWarmTimer?.cancel();
    _keepWarmTimer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_inBackground) {
          _inBackground = false;
          _onForeground();
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        if (!_inBackground) {
          _inBackground = true;
          _onBackground();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _onForeground() {
    unawaited(_applyWakelock(true));
    unawaited(reconnectIfNeeded());
    unawaited(pingBackend());
    _keepWarmTimer?.cancel();
    _keepWarmTimer = Timer.periodic(keepWarmInterval, (_) {
      unawaited(pingBackend());
    });
  }

  void _onBackground() {
    // 화면 켜짐은 앞에 있을 때만 — 주머니 속에서 배터리를 쓰지 않게 바로 푼다.
    unawaited(_applyWakelock(false));
    _keepWarmTimer?.cancel();
    _keepWarmTimer = null;
  }

  Future<void> _applyWakelock(bool enable) async {
    try {
      await _setWakelock(enable);
    } catch (e) {
      AppLogger.warn('lifecycle.wakelock_failed', {
        'enable': enable,
        'error': e.toString(),
      });
    }
  }

  /// 활성 기기가 끊겨 있으면 한 번 다시 연결한다. 실패해도 말하지 않는다.
  ///
  /// 이미 연결돼 있거나, BleService가 지수 백오프로 재연결 중이거나, 비상 정지가
  /// 직접 연결하는 중이면 끼어들지 않는다(연결 시도가 겹치면 정지 전송이 엉킨다).
  /// 누름 시퀀스는 연결이 있어야만 돌므로, 끊긴 상태에서는 진행 중일 수 없다.
  @visibleForTesting
  Future<void> reconnectIfNeeded() async {
    final bleId = _activeBleId();
    if (bleId == null || bleId.isEmpty) return;
    if (_reconnecting || _isConnected() || _isBusy()) return;
    _reconnecting = true;
    try {
      final ok = await _connect(bleId);
      AppLogger.info('lifecycle.auto_reconnect', {
        'ble_id': bleId,
        'connected': ok,
      });
    } catch (e) {
      AppLogger.warn('lifecycle.auto_reconnect_failed', {
        'ble_id': bleId,
        'error': e.toString(),
      });
    } finally {
      _reconnecting = false;
    }
  }

  /// 백엔드 /healthz를 가볍게 불러 잠든 서버를 깨운다. 결과는 로그로만 남긴다.
  @visibleForTesting
  Future<void> pingBackend() async {
    final uri = healthUri(_backendUrl());
    if (uri == null) return;
    try {
      final status = await _httpGet(uri);
      AppLogger.info('lifecycle.backend_keep_warm', {'status': status});
    } catch (e) {
      AppLogger.warn('lifecycle.backend_keep_warm_failed', {
        'error': e.toString(),
      });
    }
  }

  /// 깨울 주소. 설정이 없거나 로컬 서버면 null — 로컬은 잠들지 않고,
  /// 실기기에서는 닿지도 않는 주소라 헛요청만 쌓인다.
  @visibleForTesting
  static Uri? healthUri(String base) {
    final trimmed = base.trim();
    if (trimmed.isEmpty) return null;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme != 'https' && uri.scheme != 'http') return null;
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') return null;
    // backend/main.py의 GET /healthz — 인증·DB 없이 {"status":"ok"}만 돌려준다.
    return Uri(
      scheme: uri.scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: [
        ...uri.pathSegments.where((s) => s.isNotEmpty),
        'healthz',
      ],
    );
  }

  static bool _defaultIsBusy() =>
      BleService.instance.isReconnecting ||
      EmergencyStopService.instance.isStopping;

  static Future<void> _defaultSetWakelock(bool enable) =>
      WakelockPlus.toggle(enable: enable);

  static String _defaultBackendUrl() {
    try {
      return dotenv.get('AI_BACKEND_URL', fallback: '');
    } catch (_) {
      return '';
    }
  }

  static Future<int> _defaultHttpGet(Uri uri) async {
    // 잠든 Render 서버는 깨는 데 30~60초 걸린다. 요청이 닿기만 하면 깨어나므로
    // 응답을 오래 기다리지 않고, 매번 새 클라이언트를 써서 음성 명령 연결과 섞지 않는다.
    final client = http.Client();
    try {
      final res = await client.get(uri).timeout(const Duration(seconds: 60));
      return res.statusCode;
    } finally {
      client.close();
    }
  }
}
