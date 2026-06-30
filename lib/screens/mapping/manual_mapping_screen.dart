import 'package:flutter/material.dart';
import '../../services/ble_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/active_device_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import 'widgets/mapping_form_controls.dart';

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('연결된 기기가 없습니다.')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('BLE 전송 성공')));
      } else {
        _tts.speak('BLE 전송에 실패했습니다.');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('BLE 전송 실패')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _testPress(int x, int y) async {
    final deviceId = ActiveDeviceService.instance.getActiveDeviceId();
    if (deviceId == null) return;
    final cols = int.tryParse(_colsCtrl.text) ?? 3;
    await BleService.instance.sendPress(
      x: x,
      y: y,
      cols: cols,
      deviceId: deviceId,
    );
  }

  Future<void> _homeDevice() async {
    final deviceId = ActiveDeviceService.instance.getActiveDeviceId();
    if (deviceId == null) {
      _tts.speak('활성 기기가 없습니다.');
      return;
    }
    await BleService.instance.sendHoming(deviceId);
    _tts.speak('하드웨어를 홈 위치로 이동합니다.');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('홈 이동 명령 전송')));
  }

  Future<void> _setCurrentAsOrigin() async {
    final okOffset = await BleService.instance.sendRaw('G92.1');
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final okOrigin = await BleService.instance.sendRaw('G92 X0 Y0');
    if (okOffset && okOrigin) {
      _oxCtrl.text = '0.0';
      _oyCtrl.text = '0.0';
      _tts.speak('현재 위치를 원점으로 지정했습니다.');
    } else {
      _tts.speak('원점 지정 명령 전송에 실패했습니다.');
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(okOffset && okOrigin ? '현재 위치를 원점으로 지정' : '원점 지정 실패'),
      ),
    );
  }

  Future<void> _jog(String axis, double value) async {
    await BleService.instance.sendRelativeMove(
      axis: axis,
      value: value,
      feedRate: 800,
    );
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
            Text(
              '그리드 구성',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18 * rs,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: LabeledNumberField(label: '행 (Rows)', controller: _rowsCtrl, scale: rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: LabeledNumberField(label: '열 (Cols)', controller: _colsCtrl, scale: rs)),
              ],
            ),
            SizedBox(height: 20 * rs),
            Text(
              '모터 테스트 (10mm 이동)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18 * rs,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * rs),
            Wrap(
              spacing: 8 * rs,
              runSpacing: 8 * rs,
              children: [
                MappingActionChip(label: 'X+10', onTap: () => _jog('X', 10), scale: rs),
                MappingActionChip(label: 'X-10', onTap: () => _jog('X', -10), scale: rs),
                MappingActionChip(label: 'Y+10', onTap: () => _jog('Y', 10), scale: rs),
                MappingActionChip(label: 'Y-10', onTap: () => _jog('Y', -10), scale: rs),
                MappingActionChip(label: 'Z+10', onTap: () => _jog('Z', 10), scale: rs),
                MappingActionChip(label: 'Z-10', onTap: () => _jog('Z', -10), scale: rs),
              ],
            ),
            SizedBox(height: 20 * rs),
            Text(
              '원점 및 간격 (mm)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18 * rs,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * rs),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(14 * rs),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(12 * rs),
                border: Border.all(color: AppColors.borderDefault),
              ),
              child: Text(
                '사진 매핑의 빨간 기준점은 실제 하드웨어 원점과 맞아야 합니다. 조이스틱으로 터치봉을 기준점에 맞춘 뒤 현재 위치를 원점으로 지정하세요.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13 * rs,
                  height: 1.45,
                ),
              ),
            ),
            SizedBox(height: 12 * rs),
            Wrap(
              spacing: 8 * rs,
              runSpacing: 8 * rs,
              children: [
                MappingActionChip(label: '홈으로 이동', onTap: _homeDevice, scale: rs),
                MappingActionChip(label: '현재 위치를 원점으로 지정', onTap: _setCurrentAsOrigin, scale: rs),
                MappingActionChip(label: '원점 테스트 터치', onTap: () => _testPress(0, 0), scale: rs),
              ],
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: LabeledNumberField(label: '시작 X (OriginX)', controller: _oxCtrl, scale: rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: LabeledNumberField(label: '시작 Y (OriginY)', controller: _oyCtrl, scale: rs)),
              ],
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: LabeledNumberField(label: '가로 간격 (PitchX)', controller: _pxCtrl, scale: rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: LabeledNumberField(label: '세로 간격 (PitchY)', controller: _pyCtrl, scale: rs)),
              ],
            ),
            SizedBox(height: 20 * rs),
            Text(
              '홈(대기) 위치 (그리드 인덱스)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18 * rs,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(child: LabeledNumberField(label: '홈 행 (Home Row)', controller: _hrCtrl, scale: rs)),
                SizedBox(width: 12 * rs),
                Expanded(child: LabeledNumberField(label: '홈 열 (Home Col)', controller: _hcCtrl, scale: rs)),
              ],
            ),
            SizedBox(height: 32 * rs),
            Text(
              '위치 조정 (Jogging)',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18 * rs,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * rs),
            Center(
              child: Column(
                children: [
                  JogArrowButton(icon: Icons.arrow_upward, onTap: () => _jog('Y', 1.0), scale: rs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      JogArrowButton(icon: Icons.arrow_back, onTap: () => _jog('X', -1.0), scale: rs),
                      SizedBox(width: 40 * rs),
                      JogArrowButton(icon: Icons.arrow_forward, onTap: () => _jog('X', 1.0), scale: rs),
                    ],
                  ),
                  JogArrowButton(icon: Icons.arrow_downward, onTap: () => _jog('Y', -1.0), scale: rs),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12 * rs),
                  ),
                ),
                child: _isUploading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : Text(
                        '설정 저장 및 하드웨어 전송',
                        style: TextStyle(
                          fontSize: 16 * rs,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 24 * rs),
            Text(
              '테스트 실행',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18 * rs,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12 * rs),
            Wrap(
              spacing: 8 * rs,
              runSpacing: 8 * rs,
              children: [
                MappingActionChip(label: '원점 (0,0)', onTap: () => _testPress(0, 0), scale: rs),
                MappingActionChip(
                  label: '우측 끝',
                  onTap: () => _testPress((int.tryParse(_colsCtrl.text) ?? 1) - 1, 0),
                  scale: rs,
                ),
                MappingActionChip(
                  label: '좌측 하단',
                  onTap: () => _testPress(0, (int.tryParse(_rowsCtrl.text) ?? 1) - 1),
                  scale: rs,
                ),
                MappingActionChip(
                  label: '우측 하단',
                  onTap: () => _testPress(
                    (int.tryParse(_colsCtrl.text) ?? 1) - 1,
                    (int.tryParse(_rowsCtrl.text) ?? 1) - 1,
                  ),
                  scale: rs,
                ),
              ],
            ),
            SizedBox(height: 40 * rs),
          ],
        ),
      ),
    );
  }

}
