import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
    final res = await http.post(
      _uri('/parse-command'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text}),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('명령 파싱 API 오류: ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> analyzeMappingImage({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    if (kDebugMode) {
      debugPrint('[AI_BACKEND] vision mime=$mimeType bytes=${imageBytes.length}');
    }
    if (!isConfigured) {
      throw StateError('AI_BACKEND_URL이 설정되지 않았습니다.');
    }

    final req = http.MultipartRequest('POST', _uri('/vision-mapping'))
      ..files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'device_image',
        ),
      );

    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw StateError('비전 매핑 API 오류: ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

}
