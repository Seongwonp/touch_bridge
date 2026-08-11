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

  String _validatedBaseUrl() {
    final base = _baseUrl;
    if (base.isEmpty) {
      throw StateError('AI_BACKEND_URL이 설정되지 않았습니다.');
    }

    final uri = Uri.tryParse(base);
    if (uri == null || uri.host.isEmpty) {
      throw StateError('AI_BACKEND_URL 형식이 올바르지 않습니다: $base');
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
    _validatedBaseUrl();
    AppLogger.info('ai.cloud.fetch_profile', {'device_id': deviceId});
    final res = await http.get(_uri('/device-profile/$deviceId'));

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
