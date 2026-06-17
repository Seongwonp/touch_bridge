import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/active_device_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';

class ManualMappingScreen extends StatefulWidget {
  const ManualMappingScreen({super.key});

  @override
  State<ManualMappingScreen> createState() => _ManualMappingScreenState();
}

class _ManualMappingScreenState extends State<ManualMappingScreen> {
  final TtsService _tts = TtsService();
  final _rowsCtrl = TextEditingController(text: '3');
  final _colsCtrl = TextEditingController(text: '3');
  final _oxCtrl = TextEditingController(text: '0.0');
  final _oyCtrl = TextEditingController(text: '0.0');
  final _pxCtrl = TextEditingController(text: '20.0');
  final _pyCtrl = TextEditingController(text: '20.0');
  final _hrCtrl = TextEditingController(text: '0');
  final _hcCtrl = TextEditingController(text: '0');

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final deviceId = ActiveDeviceService.instance.getActiveDeviceId();
    if (deviceId == null) return;
    final profile = await DeviceMappingService.instance.load(deviceId);
    setState(() {
      _rowsCtrl.text = profile.rows.toString();
      _colsCtrl.text = profile.cols.toString();
      _oxCtrl.text = profile.originX.toStringAsFixed(1);
      _oyCtrl.text = profile.originY.toStringAsFixed(1);
      _pxCtrl.text = profile.pitchX.toStringAsFixed(1);
      _pyCtrl.text = profile.pitchY.toStringAsFixed(1);
      _hrCtrl.text = profile.homeRow.toString();
      _hcCtrl.text = profile.homeCol.toString();
    });
  }

  Future<void> _saveAndUpload() async {
    final deviceId = ActiveDeviceService.instance.getActiveDeviceId();
    if (deviceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('연결된 기기가 없습니다.')),
        );
      }
      return;
    }

    setState(() => _isUploading = true);

    try {
      final rows = int.tryParse(_rowsCtrl.text) ?? 3;
      final cols = int.tryParse(_colsCtrl.text) ?? 3;
      final ox = double.tryParse(_oxCtrl.text) ?? 0.0;
      final oy = double.tryParse(_oyCtrl.text) ?? 0.0;
      final px = double.tryParse(_pxCtrl.text) ?? 20.0;
      final py = double.tryParse(_pyCtrl.text) ?? 20.0;
      final hr = int.tryParse(_hrCtrl.text) ?? 0;
      final hc = int.tryParse(_hcCtrl.text) ?? 0;

      final newProfile = DeviceMappingProfile(
        rows: rows,
        cols: cols,
        originX: ox,
        originY: oy,
        pitchX: px,
        pitchY: py,
        homeRow: hr,
        homeCol: hc,
        buttonMap: const {}, // 수동 매핑에서는 그리드 기반 기본 매핑 사용
      );

      await DeviceMappingService.instance.save(deviceId, newProfile);

      final ok = await BleService.instance.sendSetGrid(
        rows: rows,
        cols: cols,
        originX: ox,
        originY: oy,
        pitchX: px,
        pitchY: py,
        deviceId: deviceId,
      );

      if (!mounted) return;

      if (ok) {
        _tts.speak('그리드 설정이 하드웨어로 전송되었습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BLE 전송 성공')),
        );
      } else {
        _tts.speak('BLE 전송에 실패했습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BLE 전송 실패')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _testPress(int x, int y) async {
    final deviceId = ActiveDeviceService.instance.getActiveDeviceId();
    if (deviceId == null) return;
    final cols = int.tryParse(_colsCtrl.text) ?? 3;
    await BleService.instance.sendPress(x: x, y: y, cols: cols, deviceId: deviceId);
  }

  Future<void> _jog(String axis, double value) async {
    // GRBL 조깅 명령: $J=G91 G21 X10 F500
    final cmd = '\$J=G91 G21 $axis$value F800';
    await BleService.instance.sendRaw(cmd);
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const TopAppBar(title: '수동 매핑 및 좌표 설정'),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20 * rs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('그리드 구성', style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: _buildTextField('행 (Rows)', _rowsCtrl, rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: _buildTextField('열 (Cols)', _colsCtrl, rs)),
              ],
            ),
            SizedBox(height: 20 * rs),
            Text('모터 테스트 (10mm 이동)', style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
            SizedBox(height: 12 * rs),
            Wrap(
              spacing: 8 * rs,
              runSpacing: 8 * rs,
              children: [
                _buildTestButton('X+10', () => _jog('X', 10), rs),
                _buildTestButton('X-10', () => _jog('X', -10), rs),
                _buildTestButton('Y+10', () => _jog('Y', 10), rs),
                _buildTestButton('Y-10', () => _jog('Y', -10), rs),
                _buildTestButton('Z+10', () => _jog('Z', 10), rs),
                _buildTestButton('Z-10', () => _jog('Z', -10), rs),
              ],
            ),
            SizedBox(height: 20 * rs),
            Text('원점 및 간격 (mm)', style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: _buildTextField('시작 X (OriginX)', _oxCtrl, rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: _buildTextField('시작 Y (OriginY)', _oyCtrl, rs)),
              ],
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: _buildTextField('가로 간격 (PitchX)', _pxCtrl, rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: _buildTextField('세로 간격 (PitchY)', _pyCtrl, rs)),
              ],
            ),
            SizedBox(height: 20 * rs),
            Text('홈(대기) 위치 (그리드 인덱스)', style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: _buildTextField('홈 행 (Home Row)', _hrCtrl, rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: _buildTextField('홈 열 (Home Col)', _hcCtrl, rs)),
              ],
            ),
            SizedBox(height: 32 * rs),
            Text('위치 조정 (Jogging)', style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
            SizedBox(height: 12 * rs),
            Center(
              child: Column(
                children: [
                  _jogButton(Icons.arrow_upward, () => _jog('Y', 1.0), rs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _jogButton(Icons.arrow_back, () => _jog('X', -1.0), rs),
                      SizedBox(width: 40 * rs),
                      _jogButton(Icons.arrow_forward, () => _jog('X', 1.0), rs),
                    ],
                  ),
                  _jogButton(Icons.arrow_downward, () => _jog('Y', -1.0), rs),
                ],
              ),
            ),
            SizedBox(height: 32 * rs),
            SizedBox(
              width: double.infinity,
              height: 56 * rs,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _saveAndUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12 * rs)),
                ),
                child: _isUploading 
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text('설정 저장 및 하드웨어 전송', style: TextStyle(fontSize: 16 * rs, fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 24 * rs),
            Text('테스트 실행', style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
            SizedBox(height: 12 * rs),
            Wrap(
              spacing: 8 * rs,
              runSpacing: 8 * rs,
              children: [
                _testButton('원점 (0,0)', () => _testPress(0, 0), rs),
                _testButton('우측 끝', () => _testPress((int.tryParse(_colsCtrl.text) ?? 1) - 1, 0), rs),
                _testButton('좌측 하단', () => _testPress(0, (int.tryParse(_rowsCtrl.text) ?? 1) - 1), rs),
                _testButton('우측 하단', () => _testPress((int.tryParse(_colsCtrl.text) ?? 1) - 1, (int.tryParse(_rowsCtrl.text) ?? 1) - 1), rs),
              ],
            ),
            SizedBox(height: 40 * rs),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, double rs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: const Color(0xFF888888), fontSize: 12 * rs)),
        SizedBox(height: 6 * rs),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1A1A1A),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8 * rs), borderSide: BorderSide.none),
            contentPadding: EdgeInsets.symmetric(horizontal: 12 * rs, vertical: 8 * rs),
          ),
        ),
      ],
    );
  }

  Widget _jogButton(IconData icon, VoidCallback onTap, double rs) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: AppColors.primary, size: 32 * rs),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A1A),
        padding: EdgeInsets.all(12 * rs),
      ),
    );
  }

  Widget _testButton(String label, VoidCallback onTap, double rs) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A2A2A),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 8 * rs),
      ),
      child: Text(label),
    );
  }

  Widget _buildTestButton(String text, VoidCallback onPressed, double rs) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF333333),
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16 * rs, vertical: 12 * rs),
      ),
      child: Text(text, style: TextStyle(fontSize: 14 * rs)),
    );
  }
}
