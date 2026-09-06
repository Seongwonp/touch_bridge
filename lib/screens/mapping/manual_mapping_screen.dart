import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/accessibility_settings.dart';
import '../../services/ble_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/active_device_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import 'guardian_handoff_screen.dart';
import 'widgets/mapping_form_controls.dart';

/// 사진 없이 좌표(행/열/원점/간격)와 조이스틱, 테스트 눌러보기만으로 버튼
/// 위치를 설정하는 화면.
///
/// 기존에는 이미 등록된 기기를 재조정하는 용도로만(control_mode_sheet 경유)
/// 쓰였는데, [deviceId]/[deviceName]을 넘기고 [showCompletionCheck]를 켜면
/// 최초 기기 등록 흐름(사진 매핑의 대안)으로도 쓸 수 있다 — 시각 확인 없이
/// 소리·진동만으로 버튼 위치를 맞출 수 있는 유일한 경로이기 때문이다.
class ManualMappingScreen extends StatefulWidget {
  const ManualMappingScreen({
    super.key,
    this.deviceId,
    this.deviceName,
    this.showCompletionCheck = false,
  });

  /// 지정하지 않으면 [ActiveDeviceService]의 현재 활성 기기를 사용한다
  /// (기존 재조정 진입 경로와의 호환을 위함).
  final String? deviceId;
  final String? deviceName;

  /// true면 저장 성공 시 스낵바 대신 [GuardianHandoffScreen]으로 이동해
  /// 등록이 실제로 끝났는지 점검한다(최초 설정 흐름 전용).
  final bool showCompletionCheck;

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
  bool _isJogging = false;
  double _jogStepMm = 5.0;
  double _currentXmm = 0;
  double _currentYmm = 0;
  DeviceMappingProfile? _currentProfile;
  final Map<String, ({double xMm, double yMm})> _buttonPositions = {};
  final Map<String, String> _buttonLabels = {};
  String? _selectedButtonId;

  // dead-man 확인 상태 — 물리적 동작(홈, 테스트 터치, 원점 지정)을
  // 잘못 눌러 하드웨어가 움직이는 사고를 방지한다.
  String? _armedAction;
  Timer? _armTimer;

  String? get _deviceId =>
      widget.deviceId ?? ActiveDeviceService.instance.getActiveDeviceId();

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
    _tts.speak(
      widget.showCompletionCheck
          ? '터치봉 위치를 맞춥니다. 패널 그림의 노란 표시를 확인하며 화살표로 조정하고, '
                '스위치봇 눌러보기 후 저장하세요.'
          : '위치 맞추기 화면입니다. 패널 그림의 현재 위치를 확인하고 화살표로 조정하세요.',
      source: 'ManualMappingScreen',
      interrupt: true,
    );
  }

  @override
  void dispose() {
    _armTimer?.cancel();
    _rowsCtrl.dispose();
    _colsCtrl.dispose();
    _oxCtrl.dispose();
    _oyCtrl.dispose();
    _pxCtrl.dispose();
    _pyCtrl.dispose();
    _hrCtrl.dispose();
    _hcCtrl.dispose();
    super.dispose();
  }

  // 물리 동작 전 dead-man 확인 패턴.
  // 첫 탭: TTS 안내 + arm. 두 번째 탭: 실행. 20초 초과: 자동 취소 (WCAG 2.2.1 통일).
  Future<void> _armAndRun({
    required String id,
    required String guide,
    required VoidCallback onConfirmed,
  }) async {
    if (_armedAction != id) {
      _armTimer?.cancel();
      setState(() => _armedAction = id);
      _armTimer = Timer(kDoubleTapArmTimeout, () {
        if (!mounted) return;
        setState(() => _armedAction = null);
      });
      await _tts.speak(guide, source: 'ManualMappingScreen', interrupt: true);
      return;
    }
    _armTimer?.cancel();
    setState(() => _armedAction = null);
    onConfirmed();
  }

  Future<void> _loadCurrentProfile() async {
    final deviceId = _deviceId;
    if (deviceId == null) return;
    final profile = await DeviceMappingService.instance.load(deviceId);
    if (!mounted) return;
    setState(() {
      _currentProfile = profile;
      _buttonPositions
        ..clear()
        ..addAll(profile.buttonMachinePositions);
      if (_buttonPositions.isEmpty) {
        for (final entry in profile.buttonMap.entries) {
          _buttonPositions[entry.key] = (
            xMm: profile.originX + entry.value.col * profile.pitchX,
            yMm: profile.originY + entry.value.row * profile.pitchY,
          );
        }
      }
      _buttonLabels
        ..clear()
        ..addAll(profile.customLabels);
      _selectedButtonId = null;
      _rowsCtrl.text = profile.rows.toString();
      _colsCtrl.text = profile.cols.toString();
      _oxCtrl.text = profile.originX.toStringAsFixed(1);
      _oyCtrl.text = profile.originY.toStringAsFixed(1);
      _pxCtrl.text = profile.pitchX.toStringAsFixed(1);
      _pyCtrl.text = profile.pitchY.toStringAsFixed(1);
      _hrCtrl.text = profile.homeRow.toString();
      _hcCtrl.text = profile.homeCol.toString();
      _currentXmm = profile.originX;
      _currentYmm = profile.originY;
    });
  }

  Future<void> _saveAndUpload() async {
    final deviceId = _deviceId;
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

      // 기존 프로필에 그리드 값만 병합한다. 새 프로필로 덮어쓰면 사진 매핑이
      // 만들어 둔 buttonMap/buttonPositions/라벨/모션 파라미터/이미지가 재보정
      // 한 번에 전부 소실된다(과거 데이터 손실 버그).
      final loaded = await DeviceMappingService.instance.load(deviceId);
      final existing = _withFreeButtonPositions(loaded);
      final merge = DeviceMappingService.mergeGridUpdate(
        existing: existing,
        rows: rows,
        cols: cols,
        originX: ox,
        originY: oy,
        pitchX: px,
        pitchY: py,
        homeRow: hr,
        homeCol: hc,
      );

      await DeviceMappingService.instance.save(deviceId, merge.profile);
      if (mounted) {
        setState(() => _currentProfile = merge.profile);
      }

      if (merge.droppedButtonIds.isNotEmpty && mounted) {
        // 그리드 축소로 제거된 버튼은 반드시 고지한다 — 침묵 삭제 금지.
        final droppedCount = merge.droppedButtonIds.length;
        _tts.speak(
          '그리드가 줄어 기존 버튼 $droppedCount개가 범위를 벗어나 제거되었습니다. '
          '해당 버튼은 사진 매핑에서 다시 등록해 주세요.',
          source: 'ManualMappingScreen',
          priority: TtsPriority.result,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('그리드 축소로 버튼 $droppedCount개 제거됨')),
        );
      }

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
        _tts.speak('그리드 설정이 하드웨어로 전송되었습니다.', priority: TtsPriority.result);
        if (widget.showCompletionCheck) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => GuardianHandoffScreen(
                deviceId: deviceId,
                deviceName: widget.deviceName ?? '기기',
              ),
            ),
          );
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('BLE 전송 성공')));
      } else {
        _tts.speak('BLE 전송에 실패했습니다.', priority: TtsPriority.result);
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

  Future<bool> _testPress(int x, int y) async {
    final deviceId = _deviceId;
    if (deviceId == null) return false;
    final cols = int.tryParse(_colsCtrl.text) ?? 3;
    return BleService.instance.sendPress(
      x: x,
      y: y,
      cols: cols,
      deviceId: deviceId,
    );
  }

  Future<void> _homeDevice() async {
    final deviceId = _deviceId;
    if (deviceId == null) {
      _tts.speak('활성 기기가 없습니다.');
      return;
    }
    await BleService.instance.sendHoming(deviceId);
    if (mounted) {
      setState(() {
        _currentXmm = 0;
        _currentYmm = 0;
      });
    }
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
      if (mounted) {
        setState(() {
          _currentXmm = 0;
          _currentYmm = 0;
        });
      }
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
    if (_isJogging) return;
    setState(() => _isJogging = true);
    final ok = await BleService.instance.sendRelativeMove(
      axis: axis,
      value: value,
      feedRate: 800,
    );
    if (!mounted) return;
    setState(() {
      _isJogging = false;
      if (ok) {
        if (axis.toUpperCase() == 'X') _currentXmm += value;
        if (axis.toUpperCase() == 'Y') _currentYmm += value;
      }
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('허브 연결이 필요합니다. 위치는 변경되지 않았습니다.')),
      );
    }
  }

  Future<void> _testSwitchBotAtCurrentPosition() async {
    final id = _selectedButtonId;
    final grid = id == null ? null : _currentProfile?.buttonMap[id];
    if (id == null || grid == null) {
      await _tts.speak('먼저 테스트할 버튼을 선택해 주세요.');
      return;
    }
    final ok = await _testPress(grid.col, grid.row);
    if (!mounted) return;
    await _tts.speak(
      ok ? '스위치봇 누르기 명령을 전송했습니다.' : '스위치봇 테스트에 실패했습니다. 허브 연결을 확인하세요.',
      source: 'ManualMappingScreen',
      priority: TtsPriority.result,
    );
  }

  DeviceMappingProfile _withFreeButtonPositions(DeviceMappingProfile profile) {
    final keptIds = _buttonPositions.keys.toSet();
    final buttonMap = <String, ({int row, int col})>{
      for (final entry in profile.buttonMap.entries)
        if (keptIds.contains(entry.key)) entry.key: entry.value,
    };
    for (final id in keptIds) {
      if (buttonMap.containsKey(id)) continue;
      final index = int.tryParse(id.replaceFirst('BT-', '')) ?? 1;
      buttonMap[id] = (row: (index - 1) ~/ 3, col: (index - 1) % 3);
    }

    final neededRows = buttonMap.values.isEmpty
        ? profile.rows
        : buttonMap.values
                  .map((value) => value.row)
                  .reduce((a, b) => a > b ? a : b) +
              1;
    final neededCols = buttonMap.values.isEmpty
        ? profile.cols
        : buttonMap.values
                  .map((value) => value.col)
                  .reduce((a, b) => a > b ? a : b) +
              1;

    return DeviceMappingProfile(
      rows: profile.rows < neededRows ? neededRows : profile.rows,
      cols: profile.cols < neededCols ? neededCols : profile.cols,
      originX: profile.originX,
      originY: profile.originY,
      pitchX: profile.pitchX,
      pitchY: profile.pitchY,
      buttonMap: buttonMap,
      buttonPositions: {
        for (final entry in profile.buttonPositions.entries)
          if (keptIds.contains(entry.key)) entry.key: entry.value,
      },
      buttonMachinePositions: Map.of(_buttonPositions),
      panelCalibration: profile.panelCalibration,
      calibrationInvalidated: profile.calibrationInvalidated,
      customLabels: {for (final id in keptIds) id: _buttonLabels[id] ?? id},
      homeRow: profile.homeRow,
      homeCol: profile.homeCol,
      travelHeightZ: profile.travelHeightZ,
      pressDepthZ: profile.pressDepthZ,
      travelFeed: profile.travelFeed,
      pressFeed: profile.pressFeed,
      dwellSeconds: profile.dwellSeconds,
      imagePath: profile.imagePath,
    );
  }

  void _registerSelectedButtonHere() {
    final id = _selectedButtonId;
    if (id == null) {
      _tts.speak('먼저 버튼을 추가해 주세요.');
      return;
    }
    setState(() {
      _buttonPositions[id] = (xMm: _currentXmm, yMm: _currentYmm);
      final profile = _currentProfile;
      if (profile != null) _currentProfile = _withFreeButtonPositions(profile);
    });
    final label = _buttonLabels[id] ?? id;
    _tts.speak('$label 버튼을 현재 위치에 등록했습니다.');
  }

  Future<void> _addButton() async {
    if (_buttonPositions.length >= 9) {
      await _tts.speak('현재 버전에서는 버튼을 최대 9개까지 등록할 수 있습니다.');
      return;
    }
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: const Text('버튼 추가', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: '버튼 이름',
            hintText: '예: 시작, 1분, 취소',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    // showDialog의 Future는 닫힘 애니메이션이 완전히 끝나기 전에 완료될 수 있다.
    // 이때 TextField가 아직 controller를 참조하는데 즉시 dispose하면
    // InheritedElement의 dependents assertion으로 빨간 오류 화면이 나타난다.
    await Future<void>.delayed(const Duration(milliseconds: 400));
    controller.dispose();
    if (!mounted || label == null || label.isEmpty) return;
    final used = _buttonPositions.keys.toSet();
    final id = [
      for (var index = 1; index <= 9; index++)
        'BT-${index.toString().padLeft(2, '0')}',
    ].firstWhere((candidate) => !used.contains(candidate));
    setState(() {
      _selectedButtonId = id;
      _buttonLabels[id] = label;
      _buttonPositions[id] = (xMm: _currentXmm, yMm: _currentYmm);
      final profile = _currentProfile;
      if (profile != null) _currentProfile = _withFreeButtonPositions(profile);
    });
    _tts.speak('$label 버튼을 추가했습니다. 조이스틱으로 위치를 맞춰 주세요.');
  }

  void _removeSelectedButton() {
    final id = _selectedButtonId;
    if (id == null) return;
    final label = _buttonLabels[id] ?? id;
    setState(() {
      _buttonPositions.remove(id);
      _buttonLabels.remove(id);
      _selectedButtonId = _buttonPositions.keys.firstOrNull;
      final profile = _currentProfile;
      if (profile != null) _currentProfile = _withFreeButtonPositions(profile);
    });
    _tts.speak('$label 버튼을 삭제했습니다.');
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: TopAppBar(
        title: widget.showCompletionCheck
            ? '설치 모드 · 위치 맞추기'
            : '보호자 설정 · 위치 맞추기',
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20 * rs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressGuide(rs),
            SizedBox(height: 20 * rs),
            Text(
              widget.deviceName ??
                  ActiveDeviceService.instance.getActiveDeviceName() ??
                  '선택한 기기',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 24 * rs,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6 * rs),
            Text(
              '노란 점이 터치봉의 현재 위치입니다. 먼저 위치를 저장할 버튼을 선택하세요.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15 * rs,
              ),
            ),
            SizedBox(height: 14 * rs),
            _PositionPreview(
              profile: _currentProfile,
              currentXmm: _currentXmm,
              currentYmm: _currentYmm,
              selectedButtonId: _selectedButtonId,
              scale: rs,
            ),
            SizedBox(height: 12 * rs),
            _buildButtonSelector(rs),
            SizedBox(height: 12 * rs),
            _buildCurrentPositionCard(rs),
            SizedBox(height: 24 * rs),
            _buildSectionTitle('이동 간격', rs),
            SizedBox(height: 10 * rs),
            _buildStepSelector(rs),
            SizedBox(height: 22 * rs),
            _buildSectionTitle('조이스틱으로 미세 조정', rs),
            SizedBox(height: 12 * rs),
            Center(
              child: _JogPad(
                scale: rs,
                busy: _isJogging,
                stepMm: _jogStepMm,
                onUp: () => _jog('Y', -_jogStepMm),
                onDown: () => _jog('Y', _jogStepMm),
                onLeft: () => _jog('X', -_jogStepMm),
                onRight: () => _jog('X', _jogStepMm),
              ),
            ),
            SizedBox(height: 22 * rs),
            _buildRegisterButton(rs),
            SizedBox(height: 12 * rs),
            _buildSafetyAction(
              rs: rs,
              id: 'switchbot_test',
              icon: Icons.touch_app_rounded,
              label: '스위치봇 눌러보기',
              guide: '스위치봇 테스트입니다. 한 번 더 누르면 실제로 버튼을 누릅니다.',
              onConfirmed: _testSwitchBotAtCurrentPosition,
              secondary: true,
            ),
            SizedBox(height: 12 * rs),
            _buildSafetyAction(
              rs: rs,
              id: 'origin',
              icon: Icons.add_location_alt_rounded,
              label: '이 위치를 패널 원점으로 지정',
              guide: '현재 위치를 패널 원점으로 지정합니다. 한 번 더 누르면 적용됩니다.',
              onConfirmed: _setCurrentAsOrigin,
              secondary: true,
            ),
            SizedBox(height: 12 * rs),
            _buildSafetyAction(
              rs: rs,
              id: 'home',
              icon: Icons.home_rounded,
              label: '홈 위치로 돌아가기',
              guide: '홈 위치로 이동합니다. 한 번 더 누르면 하드웨어가 움직입니다.',
              onConfirmed: _homeDevice,
              secondary: true,
            ),
            SizedBox(height: 22 * rs),
            _buildAdvancedSettings(rs),
            SizedBox(height: 22 * rs),
            SizedBox(
              width: double.infinity,
              height: 62 * rs,
              child: ElevatedButton.icon(
                onPressed: _isUploading ? null : _saveAndUpload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16 * rs),
                  ),
                ),
                icon: _isUploading
                    ? SizedBox(
                        width: 22 * rs,
                        height: 22 * rs,
                        child: const CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(Icons.check_circle_rounded, size: 26 * rs),
                label: Text(
                  _isUploading ? '저장 중' : '위치 설정 저장',
                  style: TextStyle(
                    fontSize: 18 * rs,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(height: 40 * rs),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressGuide(double rs) {
    return Semantics(
      label: '1단계 위치 맞추기, 2단계 눌러보기, 3단계 저장',
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 14 * rs, vertical: 12 * rs),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(14 * rs),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Row(
            children: [
              _ProgressItem(
                number: '1',
                label: '위치 맞추기',
                active: true,
                scale: rs,
              ),
              _ProgressLine(scale: rs),
              _ProgressItem(number: '2', label: '눌러보기', scale: rs),
              _ProgressLine(scale: rs),
              _ProgressItem(number: '3', label: '저장', scale: rs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButtonSelector(double rs) {
    final ids = _buttonPositions.keys.toList()..sort();
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14 * rs),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16 * rs),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '버튼 선택 · ${ids.length}개 등록됨',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16 * rs,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _addButton,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('버튼 추가'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ],
          ),
          SizedBox(height: 8 * rs),
          if (ids.isEmpty)
            Text(
              '격자를 고정하지 않습니다. 버튼을 추가한 뒤 하나씩 위치를 맞춰 주세요.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13 * rs,
                height: 1.4,
              ),
            )
          else
            Wrap(
              spacing: 8 * rs,
              runSpacing: 8 * rs,
              children: [
                for (final id in ids)
                  ChoiceChip(
                    selected: _selectedButtonId == id,
                    onSelected: (_) => setState(() => _selectedButtonId = id),
                    label: Text(_buttonLabels[id] ?? id),
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    side: BorderSide(
                      color: _selectedButtonId == id
                          ? AppColors.primary
                          : AppColors.borderDefault,
                    ),
                    labelStyle: TextStyle(
                      color: _selectedButtonId == id
                          ? Colors.black
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          if (_selectedButtonId != null) ...[
            SizedBox(height: 10 * rs),
            Text(
              '현재 선택: ${_buttonLabels[_selectedButtonId] ?? _selectedButtonId}',
              style: TextStyle(
                color: AppColors.secondary,
                fontSize: 14 * rs,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          if (_selectedButtonId != null) ...[
            SizedBox(height: 8 * rs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _removeSelectedButton,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('선택 버튼 삭제'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRegisterButton(double rs) {
    final selected = _selectedButtonId;
    final label = selected == null ? '위치를 저장할 버튼을 선택하세요' : '선택한 버튼 위치 저장';
    return SizedBox(
      width: double.infinity,
      height: 60 * rs,
      child: ElevatedButton.icon(
        onPressed: selected == null ? null : _registerSelectedButtonHere,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF123341),
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.secondary, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * rs),
          ),
        ),
        icon: Icon(Icons.add_location_alt_rounded, size: 25 * rs),
        label: Text(
          label,
          style: TextStyle(fontSize: 16 * rs, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildCurrentPositionCard(double rs) {
    return Semantics(
      liveRegion: true,
      label:
          '현재 위치, 가로 ${_currentXmm.toStringAsFixed(1)} 밀리미터, 세로 ${_currentYmm.toStringAsFixed(1)} 밀리미터. 앱이 전송 성공한 이동 명령 기준입니다.',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(16 * rs),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16 * rs),
          border: Border.all(color: AppColors.secondary, width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10 * rs),
              decoration: const BoxDecoration(
                color: Color(0x2422D3EE),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.my_location_rounded,
                color: AppColors.secondary,
                size: 24 * rs,
              ),
            ),
            SizedBox(width: 14 * rs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '현재 위치 · 앱 기준',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13 * rs,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3 * rs),
                  Text(
                    'X ${_currentXmm.toStringAsFixed(1)} mm   ·   Y ${_currentYmm.toStringAsFixed(1)} mm',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20 * rs,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text, double rs) => Text(
    text,
    style: TextStyle(
      color: AppColors.textPrimary,
      fontSize: 18 * rs,
      fontWeight: FontWeight.w900,
    ),
  );

  Widget _buildStepSelector(double rs) {
    return Row(
      children: [
        for (final step in const [1.0, 5.0, 10.0]) ...[
          Expanded(
            child: Semantics(
              selected: _jogStepMm == step,
              button: true,
              label: '이동 간격 ${step.toInt()} 밀리미터',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4 * rs),
                child: ElevatedButton(
                  onPressed: () => setState(() => _jogStepMm = step),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _jogStepMm == step
                        ? AppColors.primary
                        : AppColors.surfaceElevated,
                    foregroundColor: _jogStepMm == step
                        ? Colors.black
                        : AppColors.textPrimary,
                    side: BorderSide(
                      color: _jogStepMm == step
                          ? AppColors.primary
                          : AppColors.borderDefault,
                      width: 1.5,
                    ),
                    minimumSize: Size(0, 52 * rs),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14 * rs),
                    ),
                  ),
                  child: Text(
                    '${step.toInt()} mm',
                    style: TextStyle(
                      fontSize: 16 * rs,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSafetyAction({
    required double rs,
    required String id,
    required IconData icon,
    required String label,
    required String guide,
    required VoidCallback onConfirmed,
    bool secondary = false,
  }) {
    final armed = _armedAction == id;
    return SizedBox(
      width: double.infinity,
      height: 58 * rs,
      child: ElevatedButton.icon(
        onPressed: () =>
            _armAndRun(id: id, guide: guide, onConfirmed: onConfirmed),
        style: ElevatedButton.styleFrom(
          backgroundColor: armed
              ? AppColors.primary
              : secondary
              ? AppColors.surfaceElevated
              : const Color(0xFF123341),
          foregroundColor: armed ? Colors.black : AppColors.textPrimary,
          side: BorderSide(
            color: armed ? AppColors.textPrimary : AppColors.secondary,
            width: armed ? 3 : 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16 * rs),
          ),
        ),
        icon: Icon(icon, size: 24 * rs),
        label: Text(
          armed ? '$label · 다시 눌러 실행' : label,
          style: TextStyle(fontSize: 16 * rs, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }

  Widget _buildAdvancedSettings(double rs) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16 * rs),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          collapsedIconColor: AppColors.textSecondary,
          title: Text(
            '고급 그리드 설정',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16 * rs,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            '필요한 경우에만 열어 행·열·간격을 바꿉니다.',
            style: TextStyle(color: AppColors.textTertiary, fontSize: 12 * rs),
          ),
          childrenPadding: EdgeInsets.fromLTRB(16 * rs, 0, 16 * rs, 18 * rs),
          children: [
            Row(
              children: [
                Expanded(
                  child: LabeledNumberField(
                    label: '버튼 행 수',
                    controller: _rowsCtrl,
                    scale: rs,
                  ),
                ),
                SizedBox(width: 12 * rs),
                Expanded(
                  child: LabeledNumberField(
                    label: '버튼 열 수',
                    controller: _colsCtrl,
                    scale: rs,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(
                  child: LabeledNumberField(
                    label: '시작 X (mm)',
                    controller: _oxCtrl,
                    scale: rs,
                  ),
                ),
                SizedBox(width: 12 * rs),
                Expanded(
                  child: LabeledNumberField(
                    label: '시작 Y (mm)',
                    controller: _oyCtrl,
                    scale: rs,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(
                  child: LabeledNumberField(
                    label: '가로 간격 (mm)',
                    controller: _pxCtrl,
                    scale: rs,
                  ),
                ),
                SizedBox(width: 12 * rs),
                Expanded(
                  child: LabeledNumberField(
                    label: '세로 간격 (mm)',
                    controller: _pyCtrl,
                    scale: rs,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12 * rs),
            Row(
              children: [
                Expanded(
                  child: LabeledNumberField(
                    label: '홈 행',
                    controller: _hrCtrl,
                    scale: rs,
                  ),
                ),
                SizedBox(width: 12 * rs),
                Expanded(
                  child: LabeledNumberField(
                    label: '홈 열',
                    controller: _hcCtrl,
                    scale: rs,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressItem extends StatelessWidget {
  const _ProgressItem({
    required this.number,
    required this.label,
    required this.scale,
    this.active = false,
  });

  final String number;
  final String label;
  final double scale;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 28 * scale,
            height: 28 * scale,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.primary : AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? AppColors.primary : AppColors.textTertiary,
              ),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: active ? Colors.black : AppColors.textSecondary,
                fontSize: 13 * scale,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(height: 5 * scale),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? AppColors.primary : AppColors.textTertiary,
              fontSize: 11 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.scale});
  final double scale;

  @override
  Widget build(BuildContext context) => Container(
    width: 22 * scale,
    height: 2,
    margin: EdgeInsets.only(bottom: 20 * scale),
    color: AppColors.borderDefault,
  );
}

class _JogPad extends StatelessWidget {
  const _JogPad({
    required this.scale,
    required this.busy,
    required this.stepMm,
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  final double scale;
  final bool busy;
  final double stepMm;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    Widget direction({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
    }) {
      return Semantics(
        button: true,
        label: '$label ${stepMm.toInt()} 밀리미터 이동',
        child: SizedBox(
          width: 74 * scale,
          height: 64 * scale,
          child: ElevatedButton(
            onPressed: busy ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceElevated,
              foregroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18 * scale),
              ),
            ),
            child: Icon(icon, size: 34 * scale),
          ),
        ),
      );
    }

    return Container(
      width: 252 * scale,
      padding: EdgeInsets.all(14 * scale),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(32 * scale),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        children: [
          direction(
            icon: Icons.keyboard_arrow_up_rounded,
            label: '위로',
            onPressed: onUp,
          ),
          SizedBox(height: 8 * scale),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              direction(
                icon: Icons.keyboard_arrow_left_rounded,
                label: '왼쪽으로',
                onPressed: onLeft,
              ),
              Container(
                width: 58 * scale,
                height: 58 * scale,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x2422D3EE),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.secondary),
                ),
                child: busy
                    ? SizedBox(
                        width: 24 * scale,
                        height: 24 * scale,
                        child: const CircularProgressIndicator(
                          color: AppColors.secondary,
                          strokeWidth: 3,
                        ),
                      )
                    : Icon(
                        Icons.control_camera_rounded,
                        color: AppColors.secondary,
                        size: 27 * scale,
                      ),
              ),
              direction(
                icon: Icons.keyboard_arrow_right_rounded,
                label: '오른쪽으로',
                onPressed: onRight,
              ),
            ],
          ),
          SizedBox(height: 8 * scale),
          direction(
            icon: Icons.keyboard_arrow_down_rounded,
            label: '아래로',
            onPressed: onDown,
          ),
        ],
      ),
    );
  }
}

class _PositionPreview extends StatelessWidget {
  const _PositionPreview({
    required this.profile,
    required this.currentXmm,
    required this.currentYmm,
    required this.selectedButtonId,
    required this.scale,
  });

  final DeviceMappingProfile? profile;
  final double currentXmm;
  final double currentYmm;
  final String? selectedButtonId;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final buttonCount = profile?.buttonMachinePositions.length ?? 0;
    return Semantics(
      label:
          '패널 위치 그림. 등록된 버튼 $buttonCount개. 현재 위치 가로 ${currentXmm.toStringAsFixed(1)}, 세로 ${currentYmm.toStringAsFixed(1)} 밀리미터.',
      image: true,
      child: ExcludeSemantics(
        child: Container(
          width: double.infinity,
          height: 250 * scale,
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(22 * scale),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22 * scale),
            child: CustomPaint(
              painter: _PanelPositionPainter(
                profile: profile,
                currentXmm: currentXmm,
                currentYmm: currentYmm,
                selectedButtonId: selectedButtonId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelPositionPainter extends CustomPainter {
  const _PanelPositionPainter({
    required this.profile,
    required this.currentXmm,
    required this.currentYmm,
    required this.selectedButtonId,
  });

  final DeviceMappingProfile? profile;
  final double currentXmm;
  final double currentYmm;
  final String? selectedButtonId;

  @override
  void paint(Canvas canvas, Size size) {
    final originX = profile?.originX ?? 0;
    final originY = profile?.originY ?? 0;
    final pitchX = (profile?.pitchX ?? 20).abs();
    final pitchY = (profile?.pitchY ?? 20).abs();
    final visualPoints = <String, ({double xMm, double yMm})>{
      ...?profile?.buttonMachinePositions,
    };
    if (visualPoints.isEmpty && profile != null) {
      for (final entry in profile!.buttonMap.entries) {
        visualPoints[entry.key] = (
          xMm: originX + entry.value.col * pitchX,
          yMm: originY + entry.value.row * pitchY,
        );
      }
    }
    final panel = RRect.fromRectAndRadius(
      Rect.fromLTWH(24, 22, size.width - 48, size.height - 44),
      const Radius.circular(18),
    );
    canvas.drawRRect(panel, Paint()..color = const Color(0xFF111827));
    canvas.drawRRect(
      panel,
      Paint()
        ..color = AppColors.textTertiary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final content = Rect.fromLTWH(
      panel.left + 30,
      panel.top + 28,
      panel.width - 60,
      panel.height - 56,
    );
    var minX = currentXmm;
    var maxX = currentXmm;
    var minY = currentYmm;
    var maxY = currentYmm;
    for (final point in visualPoints.values) {
      if (point.xMm < minX) minX = point.xMm;
      if (point.xMm > maxX) maxX = point.xMm;
      if (point.yMm < minY) minY = point.yMm;
      if (point.yMm > maxY) maxY = point.yMm;
    }
    if ((maxX - minX).abs() < 1) {
      minX -= 10;
      maxX += 10;
    }
    if ((maxY - minY).abs() < 1) {
      minY -= 10;
      maxY += 10;
    }
    final padX = (maxX - minX) * 0.12;
    final padY = (maxY - minY) * 0.12;
    minX -= padX;
    maxX += padX;
    minY -= padY;
    maxY += padY;

    Offset pointFor(double x, double y) {
      final nx = ((x - minX) / (maxX - minX)).clamp(0.0, 1.0);
      final ny = ((y - minY) / (maxY - minY)).clamp(0.0, 1.0);
      return Offset(
        content.left + nx * content.width,
        content.top + ny * content.height,
      );
    }

    for (final entry in visualPoints.entries) {
      final id = entry.key;
      final pos = pointFor(entry.value.xMm, entry.value.yMm);
      final selected = id == selectedButtonId;
      canvas.drawCircle(
        pos,
        selected ? 20 : 17,
        Paint()
          ..color = selected
              ? const Color(0xFF4A3F00)
              : const Color(0xFF334155),
      );
      canvas.drawCircle(
        pos,
        selected ? 20 : 17,
        Paint()
          ..color = selected ? AppColors.primary : AppColors.secondary
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.5,
      );
      final label = profile?.customLabels[id] ?? id.replaceFirst('BT-', '');
      final textPainter = TextPainter(
        text: TextSpan(
          text: label.length > 4 ? label.substring(0, 4) : label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: 30);
      textPainter.paint(
        canvas,
        pos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    final current = pointFor(currentXmm, currentYmm);
    canvas.drawLine(
      Offset(current.dx, content.top - 12),
      Offset(current.dx, content.bottom + 12),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(content.left - 12, current.dy),
      Offset(content.right + 12, current.dy),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      current,
      13,
      Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(current, 10, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      current,
      14,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _PanelPositionPainter oldDelegate) =>
      oldDelegate.profile != profile ||
      oldDelegate.currentXmm != currentXmm ||
      oldDelegate.currentYmm != currentYmm ||
      oldDelegate.selectedButtonId != selectedButtonId;
}
