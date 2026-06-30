import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import 'widgets/esp_connection_panel.dart';
import 'widgets/esp_select_sheet.dart';
import 'widgets/jog_control_panel.dart';

class DeveloperConsoleScreen extends StatefulWidget {
  const DeveloperConsoleScreen({super.key});

  @override
  State<DeveloperConsoleScreen> createState() => _DeveloperConsoleScreenState();
}

class _DeveloperConsoleScreenState extends State<DeveloperConsoleScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _messages = [];
  final ScrollController _scrollController = ScrollController();

  double _stepSize = 1.0; // 이동 거리 (mm)
  double _feedRate = 800; // 이동 속도 (F)
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _messages.add('[SYSTEM] 개발자 콘솔 및 조깅 컨트롤 활성화');
    _messages.add('[SYSTEM] 화살표 버튼으로 하드웨어를 직접 제어하세요.');
    final connectedId = BleService.instance.connectedDeviceId;
    if (connectedId.isNotEmpty) {
      _messages.add('[BLE] 연결됨: ${BleService.instance.connectedDeviceName}');
      _messages.add('[BLE] ID: $connectedId');
    } else {
      _messages.add('[BLE] 연결된 ESP가 없습니다. 상단의 ESP 선택을 사용하세요.');
    }
  }

  void _addLog(String msg) {
    setState(() {
      _messages.add(msg);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendRaw(String cmd) async {
    _addLog('>> $cmd');
    final ok = await BleService.instance.sendRaw(cmd);
    if (ok) {
      _addLog('<< [SUCCESS] 전송 완료');
    } else {
      _addLog('<< [ERROR] 전송 실패 (블루투스 연결 확인)');
    }
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _sendRaw(text);
    _controller.clear();
  }

  Future<void> _jog(String axis, double val) async {
    final feedRate = _feedRate.round();
    _addLog('>> MOVE $axis$val F$feedRate');
    final ok = await BleService.instance.sendRelativeMove(
      axis: axis,
      value: val,
      feedRate: feedRate,
    );
    _addLog(ok ? '<< [SUCCESS] 이동 완료' : '<< [ERROR] 이동 실패');
  }

  Future<void> _scanAndSelectEsp() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);
    _addLog('[BLE] ESP 검색 시작');

    final devices = await BleService.instance.scan(
      timeout: const Duration(seconds: 5),
    );
    if (!mounted) return;
    setState(() => _isScanning = false);

    if (devices.isEmpty) {
      _addLog('[BLE] 검색된 ESP가 없습니다.');
      return;
    }

    final selected = await showEspSelectSheet(context: context, devices: devices);

    if (selected == null) {
      _addLog('[BLE] ESP 선택 취소');
      return;
    }

    _addLog('[BLE] 연결 시도: ${selected.name} (${selected.id})');
    final ok = await BleService.instance.connect(selected.id);
    if (!mounted) return;
    _addLog(ok ? '[BLE] 연결 성공: ${selected.name}' : '[BLE] 연결 실패');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: '개발자 모드 (조깅)', showBack: true),
      body: Column(
        children: [
          EspConnectionPanel(
            connected: BleService.instance.connectedDeviceId.isNotEmpty,
            connectedName: BleService.instance.connectedDeviceName,
            connectedId: BleService.instance.connectedDeviceId,
            isScanning: _isScanning,
            scale: rs,
            onScanTap: _scanAndSelectEsp,
          ),
          JogControlPanel(
            stepSize: _stepSize,
            feedRate: _feedRate,
            scale: rs,
            onStepSizeChanged: (v) => setState(() => _stepSize = v),
            onFeedRateChanged: (v) => setState(() => _feedRate = v),
            onJog: _jog,
          ),

          // 2. 메시지 로그
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: EdgeInsets.all(16 * rs),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg.startsWith('>>');
                final isError = msg.contains('[ERROR]');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    msg,
                    style: TextStyle(
                      color: isError
                          ? Colors.redAccent
                          : (isUser ? AppColors.primary : Colors.greenAccent),
                      fontFamily: 'monospace',
                      fontSize: 12 * rs,
                    ),
                  ),
                );
              },
            ),
          ),

          // 3. 직접 입력창
          Container(
            padding: EdgeInsets.fromLTRB(16 * rs, 8 * rs, 16 * rs, 32 * rs),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              border: Border(top: BorderSide(color: AppColors.borderDefault)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      hintText: '직접 명령 입력 (예: PRESS 1 1)',
                      hintStyle: const TextStyle(
                        color: Colors.white24,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16 * rs,
                        vertical: 12 * rs,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8 * rs),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                SizedBox(width: 12 * rs),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

}
