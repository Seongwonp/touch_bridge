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

  @override
  void initState() {
    super.initState();
    BleService.instance.logStream.listen((log) {
      if (mounted) {
        setState(() => _logs.add(log));
        _scrollToBottom();
      }
    });
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
        actions: [IconButton(onPressed: () => setState(() => _logs.clear()), icon: Icon(Icons.delete_outline, size: 22 * rs))],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController, padding: EdgeInsets.all(16 * rs), itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                final isSend = log.contains('SEND:'); final isRecv = log.contains('RECV:');
                final isError = log.contains('오류') || log.contains('실패') || log.contains('TIMEOUT');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(log, style: TextStyle(color: isError ? Colors.redAccent : (isSend ? Colors.lightBlueAccent : (isRecv ? Colors.greenAccent : Colors.white70)), fontFamily: 'monospace', fontSize: 12 * rs)),
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
