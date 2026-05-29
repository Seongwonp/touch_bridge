import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/appliance_config.dart';
import '../../services/recommendation_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';
import '../mapping/photo_mapping_screen.dart';

class ApplianceSelectionScreen extends StatefulWidget {
  const ApplianceSelectionScreen({super.key});

  @override
  State<ApplianceSelectionScreen> createState() => _ApplianceSelectionScreenState();
}

class _ApplianceSelectionScreenState extends State<ApplianceSelectionScreen> {
  final FlutterTts _tts = FlutterTts();

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tts.speak('가전 종류를 선택하세요.');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<String?> _chooseImageForMapping(BuildContext context) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.camera_alt, color: Colors.white), title: const Text('사진 촬영', style: TextStyle(color: Colors.white)), onTap: () => Navigator.of(ctx).pop(0)),
          ListTile(leading: const Icon(Icons.photo_library, color: Colors.white), title: const Text('갤러리에서 선택', style: TextStyle(color: Colors.white)), onTap: () => Navigator.of(ctx).pop(1)),
          ListTile(leading: const Icon(Icons.image, color: Colors.white), title: const Text('샘플 이미지 사용', style: TextStyle(color: Colors.white)), onTap: () => Navigator.of(ctx).pop(2)),
          SizedBox(height: 12),
        ]),
      ),
    );

    if (choice == null) return null;
    if (choice == 2) return null; // use built-in sample image

    try {
      final xfile = await _picker.pickImage(source: choice == 0 ? ImageSource.camera : ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
      return xfile?.path;
    } catch (e) {
      return null;
    }
  }

  String _newDeviceId(String prefix) {
    final safe = prefix.replaceAll(RegExp(r'\s+'), '_');
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${safe}_$ts';
  }

  int _iconCodePointForType(String type) {
    return switch (type.toLowerCase()) {
      'microwave' => Icons.microwave_rounded.codePoint,
      'washer' || 'laundry' => Icons.local_laundry_service_rounded.codePoint,
      'air' || 'air_purifier' => Icons.air_rounded.codePoint,
      'ac' || 'aircon' || 'air_cond' => Icons.ac_unit_rounded.codePoint,
      'light' || 'lamp' => Icons.light_mode_rounded.codePoint,
      'tv' => Icons.tv_rounded.codePoint,
      'fridge' || 'refrigerator' => Icons.kitchen_rounded.codePoint,
      _ => Icons.devices_rounded.codePoint,
    };
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
              _tts.speak('${appliance.name} 선택.');
            },
            onStartMapping: (sheetCtx, ap) async {
              Navigator.pop(sheetCtx);
              final imagePath = await _chooseImageForMapping(context);
              if (!mounted) return;
              
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => PhotoMappingScreen(
                    deviceId: _newDeviceId(ap.name.replaceAll(' ', '_')), 
                    imagePath: imagePath,
                    applianceName: ap.name,
                    applianceType: ap.type.name,
                  )
                )
              );
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
  
  const _ApplianceCard({required this.appliance, required this.onTap, required this.onStartMapping});

  IconData _getIcon() {
    switch (appliance.type) {
      case ApplianceType.washer: return Icons.wash_rounded;
      case ApplianceType.microwave: return Icons.microwave_rounded;
      case ApplianceType.dryer: return Icons.dry_cleaning_rounded;
      case ApplianceType.airConditioner: return Icons.ac_unit_rounded;
      default: return Icons.settings_remote_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Container(
      margin: EdgeInsets.only(bottom: 16 * rs),
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16 * rs), border: Border.all(color: const Color(0xFF2A2A2A))),
      child: InkWell(
        onTap: () { onTap(); _showGuide(context, rs); },
        borderRadius: BorderRadius.circular(16 * rs),
        child: Padding(
          padding: EdgeInsets.all(20 * rs),
          child: Row(
            children: [
              Container(
                width: 60 * rs, height: 60 * rs,
                decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12 * rs)),
                child: Icon(_getIcon(), color: const Color(0xFFFFEB00), size: 32 * rs),
              ),
              SizedBox(width: 18 * rs),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(appliance.name, style: TextStyle(color: Colors.white, fontSize: 18 * rs, fontWeight: FontWeight.bold)),
                Text('추천 킷: ${appliance.recommendedKit}', style: TextStyle(color: const Color(0xFF888888), fontSize: 13 * rs)),
              ])),
              Icon(Icons.arrow_forward_ios_rounded, color: const Color(0xFF444444), size: 16 * rs),
            ],
          ),
        ),
      ),
    );
  }

  void _showGuide(BuildContext context, double rs) {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF111111), isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24 * rs))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24 * rs, 24 * rs, 24 * rs, 40 * rs),
        child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(_getIcon(), color: const Color(0xFFFFEB00), size: 24 * rs),
              SizedBox(width: 8 * rs),
              Text(appliance.name, style: TextStyle(color: Colors.white, fontSize: 20 * rs, fontWeight: FontWeight.bold)),
            ]),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            Text('필요한 부품 구성', style: TextStyle(color: const Color(0xFFFFEB00), fontWeight: FontWeight.bold, fontSize: 16 * rs)),
            SizedBox(height: ResponsiveScale.v(context, 12)),
            SizedBox(
              height: 100 * rs,
              child: ListView.builder(
                scrollDirection: Axis.horizontal, itemCount: appliance.parts.length,
                itemBuilder: (context, index) {
                  final part = appliance.parts[index];
                  return Container(
                    width: 90 * rs, margin: EdgeInsets.only(right: 12 * rs),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12 * rs), border: Border.all(color: const Color(0xFF2A2A2A))),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(part.icon, color: Colors.white70, size: 28 * rs),
                      Text(part.name, style: TextStyle(color: Colors.white, fontSize: 11 * rs), textAlign: TextAlign.center),
                      Text('${part.count}개', style: TextStyle(color: const Color(0xFFFFEB00), fontSize: 11 * rs, fontWeight: FontWeight.bold)),
                    ]),
                  );
                },
              ),
            ),
            SizedBox(height: ResponsiveScale.v(context, 24)),
            Text('부착 가이드', style: TextStyle(color: const Color(0xFFFFEB00), fontWeight: FontWeight.bold, fontSize: 16 * rs)),
            SizedBox(height: ResponsiveScale.v(context, 8)),
            Text(appliance.assemblyGuide, style: TextStyle(color: Colors.white70, height: 1.5, fontSize: 14 * rs)),
            SizedBox(height: ResponsiveScale.v(context, 32)),
            SizedBox(
              width: double.infinity, height: 60 * rs,
              child: ElevatedButton(
                onPressed: () async {
                  // Delegate to parent to handle id generation, image choice and navigation.
                  await onStartMapping(context, appliance);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFEB00), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14 * rs))),
                child: Text('매핑 시작', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17 * rs)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
