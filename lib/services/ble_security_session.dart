import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// BLE 명령 전송 전 HMAC challenge-response 인증 세션을 담당한다.
/// `BleService`에서 분리됨 — 연결/스캔 로직과 보안 로직을 섞지 않기 위함.
class BleSecuritySession {
  BleSecuritySession({required this.onLog});

  final void Function(String message) onLog;

  static const Duration sessionDuration = Duration(minutes: 5);

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  String? _pairKey;
  bool _authenticated = false;
  int _authExpiryMs = 0;

  bool get _isAuthenticated =>
      _authenticated && DateTime.now().millisecondsSinceEpoch < _authExpiryMs;

  /// 연결 해제 시 호출 — 다음 연결에서 다시 인증하도록 세션을 초기화한다.
  void reset() {
    _authenticated = false;
  }

  Future<void> _loadPairKey() async {
    if (_pairKey != null) return;
    try {
      _pairKey = await _secureStorage.read(key: 'ble_pair_key');
      if (_pairKey != null) onLog('SEC: pair key loaded');
    } catch (e) {
      onLog('SEC: load key error $e');
    }
  }

  String _bytesToHex(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  String _hmacHex(String key, String data) {
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return _bytesToHex(digest.bytes);
  }

  /// 세션이 유효하면 즉시 true. 아니면 challenge/auth 핸드셰이크를 수행한다.
  /// [sendAndWaitAck]는 BleService의 명령 전송 함수를 그대로 넘겨받아 사용한다
  /// (challenge/auth는 BleService 쪽 비인증 허용 액션 목록에 포함되어 있어야 함).
  Future<bool> ensureAuthenticated({
    required Future<String> Function(Map<String, dynamic> payload, {Duration timeout}) sendAndWaitAck,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_isAuthenticated) return true;

    await _loadPairKey();
    if (_pairKey == null) return false; // not provisioned

    final nonceResp = await sendAndWaitAck({'action': 'challenge'}, timeout: timeout);
    if (!nonceResp.startsWith('NONCE:')) return false;
    final nonce = nonceResp.substring(6);

    final mac = _hmacHex(_pairKey!, nonce);
    final authResp = await sendAndWaitAck({'action': 'auth', 'mac': mac}, timeout: timeout);

    if (authResp.toUpperCase().contains('AUTH_OK')) {
      _authenticated = true;
      _authExpiryMs = DateTime.now().millisecondsSinceEpoch + sessionDuration.inMilliseconds;
      onLog('SEC: session authenticated');
      return true;
    }
    onLog('SEC: authentication failed');
    return false;
  }

  /// 페어링 키를 기기에 등록하고 secure storage에 저장한다.
  Future<bool> provisionPairKey(
    String secret, {
    required Future<String> Function(Map<String, dynamic> payload) sendAndWaitAck,
  }) async {
    final res = await sendAndWaitAck({'action': 'provision', 'secret': secret});
    if (res.toUpperCase().contains('PROVISION_OK')) {
      try {
        await _secureStorage.write(key: 'ble_pair_key', value: secret);
        _pairKey = secret;
        onLog('SEC: pair key stored');
        return true;
      } catch (e) {
        onLog('SEC: store key failed $e');
      }
    }
    return false;
  }
}
