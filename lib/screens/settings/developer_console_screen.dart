import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';

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
  final int _feedRate = 800;   // 이동 속도 (F)

  @override
  void initState() {
    super.initState();
    _messages.add('[SYSTEM] 개발자 콘솔 및 조깅 컨트롤 활성화');
    _messages.add('[SYSTEM] 화살표 버튼으로 하드웨어를 직접 제어하세요.');
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

  /// GRBL 조깅 명령 생성 및 전송
  /// $J=G91 G21 X{val} F{feed}
  Future<void> _jog(String axis, double val) async {
    final cmd = '\$J=G91 G21 $axis$val F$_feedRate';
    await _sendRaw(cmd);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: '개발자 모드 (조깅)', showBack: true),
      body: Column(
        children: [
          // 1. 조깅 컨트롤 패널
          Container(
            padding: EdgeInsets.all(16 * rs),
            decoration: const BoxDecoration(
              color: Color(0xFF111111),
              border: Border(bottom: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStepSizeSelector(rs),
                    _buildFeedRateDisplay(rs),
                  ],
                ),
                SizedBox(height: 20 * rs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // XY 방향키
                    Column(
                      children: [
                        _jogButton(Icons.arrow_upward, () => _jog('Y', _stepSize), rs),
                        Row(
                          children: [
                            _jogButton(Icons.arrow_back, () => _jog('X', -_stepSize), rs),
                            SizedBox(width: 40 * rs),
                            _jogButton(Icons.arrow_forward, () => _jog('X', _stepSize), rs),
                          ],
                        ),
                        _jogButton(Icons.arrow_downward, () => _jog('Y', -_stepSize), rs),
                      ],
                    ),
                    SizedBox(width: 60 * rs),
                    // Z축 키
                    Column(
                      children: [
                        _jogButton(Icons.keyboard_double_arrow_up, () => _jog('Z', _stepSize), rs, label: 'Z UP', color: Colors.blueAccent),
                        SizedBox(height: 20 * rs),
                        _jogButton(Icons.keyboard_double_arrow_down, () => _jog('Z', -_stepSize), rs, label: 'Z DOWN', color: Colors.blueAccent),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
              color: Color(0xFF111111),
              border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
                    decoration: InputDecoration(
                      hintText: '직접 명령 입력 (예: PRESS 1 1)',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 12 * rs),
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
                  icon: const Icon(Icons.send_rounded, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSizeSelector(double rs) {
    return Row(
      children: [
        Text('이동 단위:', style: TextStyle(color: Colors.white70, fontSize: 13 * rs)),
        SizedBox(width: 8 * rs),
        DropdownButton<double>(
          value: _stepSize,
          dropdownColor: const Color(0xFF1A1A1A),
          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          underline: Container(),
          items: [0.1, 0.5, 1.0, 5.0, 10.0].map((val) {
            return DropdownMenuItem(value: val, child: Text('${val}mm'));
          }).toList(),
          onChanged: (v) => setState(() => _stepSize = v!),
        ),
      ],
    );
  }

  Widget _buildFeedRateDisplay(double rs) {
    return Text('속도: F$_feedRate', style: TextStyle(color: Colors.white70, fontSize: 13 * rs));
  }

  Widget _jogButton(IconData icon, VoidCallback onTap, double rs, {String? label, Color color = const Color(0xFFFFEB00)}) {
    return Column(
      children: [
        IconButton(
          onPressed: onTap,
          icon: Icon(icon, color: color, size: 36 * rs),
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFF222222),
            padding: EdgeInsets.all(12 * rs),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * rs)),
          ),
        ),
        if (label != null) ...[
          SizedBox(height: 4 * rs),
          Text(label, style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10 * rs, fontWeight: FontWeight.bold)),
        ],
      ],
    );
  }
}
