import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';

class BleLogScreen extends StatefulWidget {
  const BleLogScreen({super.key});

  @override
  State<BleLogScreen> createState() => _BleLogScreenState();
}

class _BleLogScreenState extends State<BleLogScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<String>? _logSub;

  ({String source, Color color, String text}) _parseLog(String log) {
    final isSend = log.contains('SEND:');
    final isRecv = log.contains('RECV:');
    final isError = log.contains('오류') || log.contains('실패') || log.contains('TIMEOUT');

    if (isSend) {
      return (source: 'APP', color: Colors.lightBlueAccent, text: log);
    }

    if (isRecv) {
      final body = log.substring(log.indexOf('RECV:') + 5).trim();
      if (body.startsWith('AVR:')) {
        return (source: 'AVR', color: Colors.greenAccent, text: body);
      }
      if (body.startsWith('ESP:')) {
        return (source: 'ESP', color: Colors.cyanAccent, text: body);
      }
      if (body.startsWith('UART:') || body.startsWith('UART_RX:')) {
        return (source: 'UART', color: Colors.tealAccent, text: body);
      }
      if (body.startsWith('ERROR:')) {
        return (source: 'HW-ERR', color: Colors.redAccent, text: body);
      }
      return (source: 'HW', color: Colors.white70, text: body);
    }

    return (
      source: isError ? 'ERR' : 'LOG',
      color: isError ? Colors.redAccent : Colors.white70,
      text: log,
    );
  }

  @override
  void initState() {
    super.initState();
    // 구독을 저장했다가 dispose에서 취소한다 — 화면을 여닫을 때마다 리스너가
    // 누적되던 누수(과거 결함) 방지.
    _logSub = BleService.instance.logStream.listen((log) {
      if (mounted) {
        setState(() => _logs.add(log));
        _scrollToBottom();
      }
    });
  }

  @override
  void dispose() {
    _logSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: TopAppBar(
        title: '하드웨어 로그', showBack: true,
        actions: [IconButton(tooltip: '로그 전체 삭제', onPressed: () => setState(() => _logs.clear()), icon: Icon(Icons.delete_outline, size: 22 * rs))],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, padding: EdgeInsets.all(16 * rs), itemCount: _logs.length,
              itemBuilder: (context, index) {
                final entry = _parseLog(_logs[index]);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '[${entry.source}] ${entry.text}',
                    style: TextStyle(
                      color: entry.color,
                      fontFamily: 'monospace',
                      fontSize: 12 * rs,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(child: Padding(
            padding: EdgeInsets.all(16 * rs),
            child: SizedBox(
              width: double.infinity, height: 56 * rs,
              child: ElevatedButton(
                onPressed: () => BleService.instance.sendGetServo(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A), 
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12 * rs), 
                    side: const BorderSide(color: Color(0xFF333333)),
                  ),
                ),
                child: Text('설정 조회 (GET_SERVO)', style: TextStyle(fontSize: 15 * rs, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          )),
        ],
      ),
    );
  }
}
