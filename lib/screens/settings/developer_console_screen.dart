import 'package:flutter/material.dart';
import '../../services/active_device_service.dart';
import '../../services/ble_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/mapping_execution_service.dart';
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
  String _dryRunButtonId = 'BT-02';

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

  Future<void> _home() => _sendRaw('\$H');

  Future<void> _stop() => _sendRaw('STOP');

  Future<void> _testZPress() async {
    final down = -_stepSize.abs();
    final feed = _feedRate.round();
    _addLog('>> Z TEST down=$down up=${_stepSize.abs()} F$feed');
    final okDown = await BleService.instance.sendRelativeMove(
      axis: 'Z',
      value: down,
      feedRate: feed,
    );
    await Future<void>.delayed(const Duration(milliseconds: 250));
    final okUp = await BleService.instance.sendRelativeMove(
      axis: 'Z',
      value: _stepSize.abs(),
      feedRate: feed,
    );
    _addLog(okDown && okUp ? '<< [SUCCESS] Z 테스트 완료' : '<< [ERROR] Z 테스트 실패');
  }

  Future<void> _dryRunButton() async {
    final deviceId = ActiveDeviceService.instance.getActiveDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      _addLog('[DRY-RUN][ERROR] 활성 기기가 없습니다.');
      return;
    }

    final profile = await DeviceMappingService.instance.load(deviceId);
    final result = await MappingExecutionService.instance.pressButton(
      deviceId: deviceId,
      profile: profile,
      buttonId: _dryRunButtonId,
      dryRun: true,
    );

    _addLog('[DRY-RUN] device=$deviceId button=$_dryRunButtonId');
    if (!result.ok) {
      _addLog('[DRY-RUN][ERROR] ${result.message}');
      return;
    }
    _addLog(
      '[DRY-RUN] row=${result.row} col=${result.col} '
      'x=${result.x?.toStringAsFixed(2)} y=${result.y?.toStringAsFixed(2)}',
    );
    for (final line in result.gcode) {
      _addLog('[GCODE] $line');
    }
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

    final selected = await showEspSelectSheet(
      context: context,
      devices: devices,
    );

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
    final compactHeight = MediaQuery.sizeOf(context).height < 700;
    final inputBottomPadding = compactHeight ? 10.0 * rs : 32.0 * rs;

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
          _buildQuickActions(rs),

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
            padding: EdgeInsets.fromLTRB(
              16 * rs,
              8 * rs,
              16 * rs,
              inputBottomPadding,
            ),
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

  Widget _buildQuickActions(double rs) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 10 * rs),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.borderDefault)),
      ),
      child: Wrap(
        spacing: 8 * rs,
        runSpacing: 8 * rs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _actionChip('홈 복귀 \$H', Icons.home_rounded, _home, rs),
          _actionChip(
            'STOP',
            Icons.stop_circle_rounded,
            _stop,
            rs,
            danger: true,
          ),
          _actionChip(
            'Z 테스트',
            Icons.vertical_align_bottom_rounded,
            _testZPress,
            rs,
          ),
          DropdownButton<String>(
            value: _dryRunButtonId,
            dropdownColor: AppColors.surfaceElevated,
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 13 * rs,
            ),
            underline: const SizedBox.shrink(),
            items: List.generate(9, (i) {
              final id = 'BT-${(i + 1).toString().padLeft(2, '0')}';
              return DropdownMenuItem(value: id, child: Text(id));
            }),
            onChanged: (v) {
              if (v != null) setState(() => _dryRunButtonId = v);
            },
          ),
          _actionChip('dry-run', Icons.receipt_long_rounded, _dryRunButton, rs),
        ],
      ),
    );
  }

  Widget _actionChip(
    String label,
    IconData icon,
    VoidCallback onTap,
    double rs, {
    bool danger = false,
  }) {
    return ActionChip(
      avatar: Icon(
        icon,
        color: danger ? Colors.white : Colors.black,
        size: 18 * rs,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        color: danger ? Colors.white : Colors.black,
        fontWeight: FontWeight.w900,
        fontSize: 12 * rs,
      ),
      backgroundColor: danger ? AppColors.emergency : AppColors.primary,
      onPressed: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8 * rs),
      ),
    );
  }
}
