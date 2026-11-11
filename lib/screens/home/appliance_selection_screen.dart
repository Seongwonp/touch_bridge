import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/appliance_config.dart';
import '../../services/active_device_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/home_device_store.dart';
import '../../services/recommendation_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import '../mapping/manual_mapping_screen.dart';
import '../mapping/mapping_image_source.dart';
import '../mapping/photo_mapping_screen.dart';

IconData _iconForApplianceType(ApplianceType type) {
  switch (type) {
    case ApplianceType.washer:
      return Icons.wash_rounded;
    case ApplianceType.microwave:
      return Icons.microwave_rounded;
    case ApplianceType.dryer:
      return Icons.dry_cleaning_rounded;
    case ApplianceType.airConditioner:
      return Icons.ac_unit_rounded;
    default:
      return Icons.settings_remote_rounded;
  }
}

class ApplianceSelectionScreen extends StatefulWidget {
  final String? bleId;
  final String? bleName;

  const ApplianceSelectionScreen({super.key, this.bleId, this.bleName});

  @override
  State<ApplianceSelectionScreen> createState() =>
      _ApplianceSelectionScreenState();
}

class _ApplianceSelectionScreenState extends State<ApplianceSelectionScreen> {
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _tts.speak('가전 종류를 선택하세요.', source: 'ApplianceSelectionScreen');
  }

  @override
  void dispose() {
    // TtsService는 앱 전역 싱글톤 큐라 여기서 stop()을 부르면 다음 화면이
    // 막 넣은 안내까지 지워버린다.
    super.dispose();
  }

  String _newDeviceId(String prefix) {
    final safe = prefix.replaceAll(RegExp(r'\s+'), '_');
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${safe}_$ts';
  }

  /// 사진 매핑을 건너뛰고 좌표 기반 설정 화면으로 이동한다.
  /// 시각 확인 없이(화살표+테스트 눌러보기만으로) 최초 등록을 끝낼 수 있는 경로.
  ///
  /// 설정 화면이 이 기기를 활성 기기로 쓰므로 먼저 등록하지만, 저장까지 마치지
  /// 않고 돌아오면 등록을 되돌린다. 예전에는 되돌리지 않아 뒤로 가기만 해도
  /// 매핑 없는 "일반 전자레인지"가 홈에 남았다(실기 확인).
  Future<void> _registerAndStartCoordinateSetup(
    BuildContext context,
    ApplianceConfig appliance,
  ) async {
    final deviceId = _newDeviceId(appliance.name.replaceAll(' ', '_'));
    final active = ActiveDeviceService.instance;
    final previous = (
      id: active.getActiveDeviceId(),
      name: active.getActiveDeviceName(),
      bleId: active.getActiveBleId(),
      bleName: await active.getActiveBleName(),
      type: active.getActiveDeviceType(),
    );

    final devices = await HomeDeviceStore.loadDevices();
    devices.add({
      'id': deviceId,
      'name': appliance.name,
      'status': '작동 대기 중',
      'iconCodePoint': _iconForApplianceType(appliance.type).codePoint,
      'deviceType': appliance.type.name,
      'bleId': widget.bleId,
      'bleName': widget.bleName,
    });
    await HomeDeviceStore.saveDevices(devices);
    await ActiveDeviceService.instance.setActiveDevice(
      deviceId: deviceId,
      deviceName: appliance.name,
      bleId: widget.bleId,
      bleName: widget.bleName,
      deviceType: appliance.type.name,
    );
    ActiveDeviceService.instance.notifyDeviceListChanged();

    // 아직 등록이 끝난 것이 아니므로 "등록되었습니다"라고 하지 않는다.
    unawaited(_tts.speak(
      '${appliance.name}의 버튼 위치를 좌표로 설정합니다. 저장하면 등록이 끝납니다.',
      source: 'ApplianceSelectionScreen',
      interrupt: true,
      priority: TtsPriority.result,
    ));

    final completed = context.mounted
        ? await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => ManualMappingScreen(
                deviceId: deviceId,
                deviceName: appliance.name,
                showCompletionCheck: true,
              ),
            ),
          )
        : null;
    if (completed == true) return;

    // 저장하지 않고 돌아왔다 — 등록·매핑·활성 기기를 되돌린다.
    await HomeDeviceStore.removeById(deviceId);
    await DeviceMappingService.instance.delete(deviceId);
    if (active.getActiveDeviceId() == deviceId) {
      final prevId = previous.id;
      if (prevId != null && prevId.isNotEmpty &&
          await HomeDeviceStore.findById(prevId) != null) {
        await active.setActiveDevice(
          deviceId: prevId,
          deviceName: previous.name,
          bleId: previous.bleId,
          bleName: previous.bleName,
          deviceType: previous.type,
        );
      } else {
        await active.clearActiveDevice();
      }
    }
    active.notifyDeviceListChanged();
    _tts.speak(
      '${appliance.name} 등록을 취소했습니다.',
      source: 'ApplianceSelectionScreen',
      priority: TtsPriority.result,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = RecommendationService.getRecommendations();
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: '설치 모드 · 가전 선택', showBack: true),
      body: ListView.builder(
        padding: EdgeInsets.all(20 * rs),
        itemCount: recommendations.length,
        itemBuilder: (context, index) {
          final appliance = recommendations[index];
          return _ApplianceCard(
            appliance: appliance,
            onTap: () {
              HapticFeedback.selectionClick();
              _tts.speak(
                '${appliance.name} 선택.',
                source: 'ApplianceSelectionScreen',
              );
            },
            onStartMapping: (sheetCtx, ap) async {
              if (Navigator.of(sheetCtx).canPop()) {
                Navigator.of(sheetCtx).pop();
              }

              final result = await chooseImageForMapping(context, tts: _tts);
              if (result == null) return; // 취소 — 매핑 화면으로 넘어가지 않는다
              if (!context.mounted) return;

              // 피커 종료 후 OS 리소스 안정화를 위해 잠시 대기한다.
              await Future.delayed(const Duration(milliseconds: 500));

              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoMappingScreen(
                    deviceId: _newDeviceId(ap.name.replaceAll(' ', '_')),
                    imagePath: result.path,
                    applianceName: ap.name,
                    applianceType: ap.type.name,
                    bleId: widget.bleId,
                    bleName: widget.bleName,
                  ),
                ),
              );
            },
            onStartCoordinateSetup: (sheetCtx, ap) async {
              if (Navigator.of(sheetCtx).canPop()) {
                Navigator.of(sheetCtx).pop();
              }
              if (!context.mounted) return;
              await _registerAndStartCoordinateSetup(context, ap);
            },
          );
        },
      ),
    );
  }
}

class _ApplianceCard extends StatelessWidget {
  final ApplianceConfig appliance;
  final VoidCallback onTap;
  final Future<void> Function(BuildContext, ApplianceConfig) onStartMapping;
  final Future<void> Function(BuildContext, ApplianceConfig)
  onStartCoordinateSetup;

  const _ApplianceCard({
    required this.appliance,
    required this.onTap,
    required this.onStartMapping,
    required this.onStartCoordinateSetup,
  });

  IconData _getIcon() => _iconForApplianceType(appliance.type);

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Container(
      margin: EdgeInsets.only(bottom: 16 * rs),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16 * rs),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Semantics(
        button: true,
        label: '${appliance.name} 선택',
        child: InkWell(
        onTap: () {
          onTap();
          _showGuide(context, rs);
        },
        borderRadius: BorderRadius.circular(16 * rs),
        child: Padding(
          padding: EdgeInsets.all(20 * rs),
          child: Row(
            children: [
              Container(
                width: 60 * rs,
                height: 60 * rs,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12 * rs),
                ),
                child: Icon(
                  _getIcon(),
                  color: AppColors.primary,
                  size: 32 * rs,
                ),
              ),
              SizedBox(width: 18 * rs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appliance.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18 * rs,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: const Color(0xFF444444),
                size: 16 * rs,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  void _showGuide(BuildContext context, double rs) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24 * rs)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24 * rs, 24 * rs, 24 * rs, 40 * rs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_getIcon(), color: AppColors.primary, size: 24 * rs),
                SizedBox(width: 8 * rs),
                Text(
                  appliance.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20 * rs,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            // 예전 "필요한 부품·부착 가이드"는 랙&피니언·키캡 같은 옛 하드웨어 기준이라 뺐다.
            // 지금 하드웨어(CoreXY 프레임 + SwitchBot Bot)는 가전 종류와 무관하게 같다.
            Text(
              '설치 순서',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16 * rs,
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 8)),
            Text(
              '1. 터치브릿지 프레임을 조작부 위에 붙입니다.\n'
              '2. 누름 장치가 버튼에 닿도록 놓습니다.\n'
              '3. 아래에서 버튼 위치를 설정하고 저장하면 등록이 끝납니다.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.5,
                fontSize: 14 * rs,
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 32)),
            SizedBox(
              width: double.infinity,
              height: 60 * rs,
              child: ElevatedButton(
                onPressed: () async {
                  // Delegate to parent to handle id generation, image choice and navigation.
                  await onStartMapping(context, appliance);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14 * rs),
                  ),
                ),
                child: Text(
                  '사진으로 매핑 시작',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17 * rs,
                  ),
                ),
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 12)),
            SizedBox(
              width: double.infinity,
              height: 60 * rs,
              child: Semantics(
                label: '사진 없이 좌표로 설정. 화면을 보지 않고 화살표와 테스트 눌러보기만으로 버튼 위치를 맞춥니다.',
                button: true,
                child: OutlinedButton(
                  onPressed: () async {
                    await onStartCoordinateSetup(context, appliance);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary, width: 1.5 * rs),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14 * rs),
                    ),
                  ),
                  child: Text(
                    '사진 없이 좌표로 설정',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17 * rs,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
