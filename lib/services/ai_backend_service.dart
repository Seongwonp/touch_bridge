import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'app_logger.dart';

class AiBackendService {
  AiBackendService._();
  static final AiBackendService instance = AiBackendService._();

  String get _baseUrl {
    try {
      return dotenv.get('AI_BACKEND_URL', fallback: '').trim();
    } catch (_) {
      return '';
    }
  }

  bool get isConfigured => _baseUrl.isNotEmpty;

  Uri _uri(String path) => Uri.parse('$_baseUrl$path');

  Future<Map<String, dynamic>> parseVoiceCommand(String text) async {
    if (!isConfigured) {
      throw StateError('AI_BACKEND_URL이 설정되지 않았습니다.');
    }
    AppLogger.info('ai.parse.request', {'text_len': text.length});
    final res = await http.post(
      _uri('/parse-command'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
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
      debugPrint('[AI_BACKEND] vision mime=$mimeType bytes=${imageBytes.length}');
    }
    AppLogger.info('ai.vision.request', {'mime': mimeType, 'bytes': imageBytes.length});
    if (!isConfigured) {
      throw StateError('AI_BACKEND_URL이 설정되지 않았습니다.');
    }

    Future<http.Response> doRequest() async {
      final req = http.MultipartRequest('POST', _uri('/vision-mapping'))
        ..files.add(
          http.MultipartFile.fromBytes(
            'image',
            imageBytes,
            filename: 'device_image',
          ),
        );
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      return http.Response.fromStream(streamed).timeout(const Duration(seconds: 65));
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
      throw StateError('비전 매핑 API 오류: ${res.statusCode} ${utf8.decode(res.bodyBytes)}');
    }
    AppLogger.info('ai.vision.response_ok', {'status': res.statusCode});
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> fetchDeviceProfile(String deviceId) async {
    if (!isConfigured) {
      throw StateError('AI_BACKEND_URL이 설정되지 않았습니다.');
    }
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
