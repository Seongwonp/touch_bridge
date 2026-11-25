import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/tts_service.dart';
import '../../theme/app_colors.dart';
import '../home/widgets/camera_alignment_guide.dart';

/// 사진 매핑에 쓸 이미지를 고른다. 새 가전 등록과 보호자 설정의 "사진으로 다시 찾기"가
/// 같은 흐름을 쓴다.
///
/// 반환 계약: null = 사용자가 취소(시트 dismiss 또는 피커 취소). 이때 호출부는
/// 매핑 화면으로 진입하면 안 된다. 샘플 이미지 선택은
/// `(path: null, useSample: true)`로 구분한다. [allowSample]이 false면 샘플 항목을 숨긴다.
Future<({String? path, bool useSample})?> chooseImageForMapping(
  BuildContext context, {
  TtsService? tts,
  bool allowSample = true,
}) async {
  final speaker = tts ?? TtsService();
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
          if (allowSample)
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

  if (choice == null) return null; // 시트 dismiss = 취소
  if (choice == 2) return (path: null, useSample: true); // 샘플 이미지로 진행

  if (choice == 0) {
    if (!context.mounted) return null;
    final ready = await showCameraAlignmentGuide(context);
    if (!ready) return null;
  }

  try {
    // iOS 리소스 격리: 피커를 열기 전에 고부하 작업을 멈춘다.
    await speaker.stop();

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

    if (xfile == null) {
      // 피커에서 취소 — 매핑 진입 없이 원래 화면 유지.
      speaker.speak('사진 선택을 취소했습니다.', priority: TtsPriority.result);
      return null;
    }
    return (path: xfile.path, useSample: false);
  } catch (e) {
    debugPrint('Error picking image (Critical Isolation): $e');
    speaker.speak('사진을 가져오는 중 오류가 발생했습니다.', priority: TtsPriority.result);
    return null;
  }
}
