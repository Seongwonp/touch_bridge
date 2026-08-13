import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/appliance_config.dart';
import '../../services/active_device_service.dart';
import '../../services/home_device_store.dart';
import '../../services/recommendation_service.dart';
import '../../services/tts_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../../theme/app_colors.dart';
import '../mapping/manual_mapping_screen.dart';
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
    // 막 넣은 안내까지 지워버린다(화면 전환 시 안내가 잘리는 문제).
    super.dispose();
  }

  Future<String?> _chooseImageForMapping(BuildContext context) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('사진 촬영', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(0),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                '갤러리에서 선택',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(ctx).pop(1),
            ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.white),
              title: const Text(
                '샘플 이미지 사용',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.of(ctx).pop(2),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice == null) return null;
    if (choice == 2) return null; // use built-in sample image

    try {
      // [CRITICAL] iOS 리소스 격리: 모든 고부하 작업 중지
      await _tts.stop();
      // 블루투스 스캔 중이면 중지 (필요 시)

      // iOS XPC 세션 안정화를 위해 충분한 대기
      await Future.delayed(const Duration(milliseconds: 1500));

      final ImagePicker isolatedPicker = ImagePicker();
      final xfile = await isolatedPicker.pickImage(
        source: choice == 0 ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024, // 해상도 하향 조정으로 메모리 부담 완화
        imageQuality: 80,
      );

      // 피커 종료 후 다시 대기
      await Future.delayed(const Duration(milliseconds: 800));

      return xfile?.path;
    } catch (e) {
      debugPrint('Error picking image (Critical Isolation): $e');
      _tts.speak('사진을 가져오는 중 오류가 발생했습니다.');
      return null;
    }
  }

  String _newDeviceId(String prefix) {
    final safe = prefix.replaceAll(RegExp(r'\s+'), '_');
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${safe}_$ts';
  }

  /// 사진 매핑을 건너뛰고 바로 기기를 등록한 뒤 좌표 기반 설정 화면으로 이동한다.
  /// 시각 확인 없이(화살표+테스트 눌러보기만으로) 최초 등록을 끝낼 수 있는 경로.
  Future<void> _registerAndStartCoordinateSetup(
    BuildContext context,
    ApplianceConfig appliance,
  ) async {
    final deviceId = _newDeviceId(appliance.name.replaceAll(' ', '_'));

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

    await _tts.speak(
      '${appliance.name} 기기가 등록되었습니다. 이제 좌표로 버튼 위치를 설정합니다.',
      source: 'ApplianceSelectionScreen',
      interrupt: true,
    );

    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManualMappingScreen(
          deviceId: deviceId,
          deviceName: appliance.name,
          showCompletionCheck: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recommendations = RecommendationService.getRecommendations();
    final rs = ResponsiveScale.factor(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: const TopAppBar(title: '가전 종류 선택', showBack: true),
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

              final result = await _chooseImageForMapping(context);
              if (!context.mounted) return;

              // [CRITICAL] 피커 종료 후 OS 리소스 안정화를 위해 추가 대기
              await Future.delayed(const Duration(milliseconds: 500));

              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoMappingScreen(
                    deviceId: _newDeviceId(ap.name.replaceAll(' ', '_')),
                    imagePath: result,
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
                    Text(
                      '추천 킷: ${appliance.recommendedKit}',
                      style: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13 * rs,
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
            Text(
              '필요한 부품 구성',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16 * rs,
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 12)),
            SizedBox(
              height: 100 * rs,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: appliance.parts.length,
                itemBuilder: (context, index) {
                  final part = appliance.parts[index];
                  return Container(
                    width: 90 * rs,
                    margin: EdgeInsets.only(right: 12 * rs),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12 * rs),
                      border: Border.all(color: AppColors.borderDefault),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(part.icon, color: Colors.white70, size: 28 * rs),
                        Text(
                          part.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11 * rs,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          '${part.count}개',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11 * rs,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            Text(
              '부착 가이드',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16 * rs,
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 8)),
            Text(
              appliance.assemblyGuide,
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
