import 'dart:convert';
import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String event, [Map<String, Object?> data = const {}]) {
    _log('INFO', event, data);
  }

  static void warn(String event, [Map<String, Object?> data = const {}]) {
    _log('WARN', event, data);
  }

  static void error(String event, [Map<String, Object?> data = const {}]) {
    _log('ERROR', event, data);
  }

  static void _log(String level, String event, Map<String, Object?> data) {
    final payload = <String, Object?>{
      'level': level,
      'event': event,
      'ts': DateTime.now().toIso8601String(),
      ...data,
    };
    debugPrint('[APP_LOG] ${jsonEncode(payload)}');
  }
}
