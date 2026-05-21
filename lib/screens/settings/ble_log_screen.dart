import 'package:flutter/material.dart';
import '../../services/ble_service.dart';

class BleLogScreen extends StatefulWidget {
  const BleLogScreen({super.key});

  @override
  State<BleLogScreen> createState() => _BleLogScreenState();
}

class _BleLogScreenState extends State<BleLogScreen> {
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    BleService.instance.logStream.listen((log) {
      if (mounted) {
        setState(() {
          _logs.add(log);
        });
        _scrollToBottom();
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('하드웨어 통신 로그', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _logs.clear()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isSend = log.contains('SEND:');
                final isRecv = log.contains('RECV:');
                final isError = log.contains('오류') || log.contains('실패') || log.contains('TIMEOUT');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    log,
                    style: TextStyle(
                      color: isError 
                          ? Colors.redAccent 
                          : (isSend ? Colors.lightBlueAccent : (isRecv ? Colors.greenAccent : Colors.white70)),
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => BleService.instance.sendGetServo(),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF333333)),
                      child: const Text('기기 설정 조회 (GET_SERVO)'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
