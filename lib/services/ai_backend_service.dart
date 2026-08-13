import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http_parser/http_parser.dart';
import 'app_logger.dart';

class AiBackendService {
  AiBackendService._();
  static final AiBackendService instance = AiBackendService._();
  late final http.Client _client = _buildClient();

  http.Client _buildClient() {
    if (kIsWeb) return http.Client();
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 1)
      ..maxConnectionsPerHost = 1;
    io.findProxy = (_) => 'DIRECT';
    return IOClient(io);
  }

  String get _baseUrl {
    try {
      return dotenv.get('AI_BACKEND_URL', fallback: '').trim();
    } catch (_) {
      return '';
    }
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  Uri _uri(String path) {
    final base = _validatedBaseUrl();
    return Uri.parse('$base$path');
  }

  // 유효한 기기 ID 패턴: 영문·숫자·하이픈·언더스코어, 1~64자
  static final _deviceIdPattern = RegExp(r'^[A-Za-z0-9_\-]{1,64}$');

  String _validatedBaseUrl() {
    final base = _baseUrl;
    if (base.isEmpty) {
      throw StateError('AI_BACKEND_URL이 설정되지 않았습니다.');
    }

    final uri = Uri.tryParse(base);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('AI_BACKEND_URL 형식이 올바르지 않습니다: $base');
    }

    // scheme 검증: 릴리스에서는 HTTPS만 허용.
    // 디버그에서는 로컬 개발 편의를 위해 HTTP도 허용하되 경고를 남긴다.
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw StateError(
        'AI_BACKEND_URL scheme은 https 또는 http만 허용됩니다: ${uri.scheme}',
      );
    }
    if (!kDebugMode && uri.scheme != 'https') {
      throw StateError(
        'AI_BACKEND_URL은 릴리스 빌드에서 HTTPS만 허용됩니다. '
        '현재 scheme: ${uri.scheme}',
      );
    }
    if (kDebugMode && uri.scheme == 'http') {
      debugPrint('[AI_BACKEND] ⚠️ HTTP 사용 중 — 릴리스 전에 HTTPS로 교체하세요.');
    }

    final isLoopback = uri.host == '127.0.0.1' || uri.host == 'localhost';
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);
    if (isMobile && isLoopback) {
      throw StateError(
        '실기기에서는 AI_BACKEND_URL에 127.0.0.1/localhost를 사용할 수 없습니다. '
        'Mac의 같은 Wi-Fi IP(예: http://192.168.x.x:8000)로 설정하세요.',
      );
    }
    return base;
  }

  Future<Map<String, dynamic>> parseVoiceCommand(String text) async {
    _validatedBaseUrl();
    AppLogger.info('ai.parse.request', {'text_len': text.length});
    http.Response res;
    try {
      res = await _client
          .post(
            _uri('/parse-command'),
            headers: const {
              'Content-Type': 'application/json',
              'Connection': 'close',
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 15));
    } on SocketException catch (e) {
      AppLogger.warn('ai.parse.socket_retry', {'error': e.toString()});
      await Future<void>.delayed(const Duration(milliseconds: 250));
      res = await _client
          .post(
            _uri('/parse-command'),
            headers: const {
              'Content-Type': 'application/json',
              'Connection': 'close',
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 15));
    } on http.ClientException catch (e) {
      AppLogger.warn('ai.parse.client_retry', {'error': e.toString()});
      await Future<void>.delayed(const Duration(milliseconds: 250));
      res = await _client
          .post(
            _uri('/parse-command'),
            headers: const {
              'Content-Type': 'application/json',
              'Connection': 'close',
            },
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 15));
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.warn('ai.parse.response_error', {'status': res.statusCode});
      throw StateError('명령 파싱 API 오류: ${res.statusCode}');
    }
    AppLogger.info('ai.parse.response_ok', {'status': res.statusCode});
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> analyzeMappingImage({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[AI_BACKEND] vision mime=$mimeType bytes=${imageBytes.length}',
      );
    }
    AppLogger.info('ai.vision.request', {
      'mime': mimeType,
      'bytes': imageBytes.length,
    });
    _validatedBaseUrl();

    Future<http.Response> doRequest() async {
      final req = http.MultipartRequest('POST', _uri('/vision-mapping'))
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'device_image',
            contentType: MediaType.parse(mimeType),
          ),
        );
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      return http.Response.fromStream(
        streamed,
      ).timeout(const Duration(seconds: 65));
    }

    http.Response res;
    try {
      res = await doRequest();
    } on Exception {
      // 네트워크 일시 장애 또는 첫 연결 타임아웃 시 1회 재시도
      AppLogger.warn('ai.vision.retry_once');
      res = await doRequest();
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      AppLogger.warn('ai.vision.response_error', {'status': res.statusCode});
      throw StateError(
        '비전 매핑 API 오류: ${res.statusCode} ${utf8.decode(res.bodyBytes)}',
      );
    }
    AppLogger.info('ai.vision.response_ok', {'status': res.statusCode});
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchDeviceProfile(String deviceId) async {
    if (!_deviceIdPattern.hasMatch(deviceId)) {
      throw ArgumentError(
        '유효하지 않은 기기 ID입니다. 영문·숫자·하이픈·언더스코어(1~64자)만 허용됩니다: $deviceId',
      );
    }
    final baseUri = Uri.parse(_validatedBaseUrl());
    AppLogger.info('ai.cloud.fetch_profile', {'device_id': deviceId});
    final uri = baseUri.replace(
      pathSegments: [
        ...baseUri.pathSegments.where((s) => s.isNotEmpty),
        'device-profile',
        deviceId,
      ],
    );
    final res = await http.get(uri);

    if (res.statusCode == 404) {
      throw StateError('등록되지 않은 기기입니다. (ID: $deviceId)');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('프로필 조회 API 오류: ${res.statusCode}');
    }

    AppLogger.info('ai.cloud.fetch_ok', {'device_id': deviceId});
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }
}
