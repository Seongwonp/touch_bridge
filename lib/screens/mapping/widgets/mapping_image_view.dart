import 'dart:io';
import 'package:flutter/material.dart';

const String kMappingFallbackImageUrl =
    'https://lh3.googleusercontent.com/aida-public/AB6AXuBnqtd9QhBxdz_JPVKIqregy0_eQ3-Kmm7GhJ8UoFacsWE5PEO-nYQkiuURtdw1a2Cs-HJLoqEIedm0jvg30rAPgKdOP31oZW5vxfMBJbKgF91uW3lKKboV4zYLwECV2iUnU_UEVKndaTiSpa38QlC_tjoqt7_M9_T9vRF0bU4s2DcqnJHCe6dAFIbehXzzPXMcudEPtJGpt2aY-AFAF4Mn3vw5n7xiaxpHljgqh7f0myzhl1b-copBdl6DRlJsKMDkY-1Pm1K4y8ZO';

/// 매핑 대상 이미지를 표시한다. 로컬 파일/네트워크 URL/이미지 없음(폴백) 3가지 경로를 처리한다.
class MappingImageView extends StatelessWidget {
  const MappingImageView({super.key, required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path != null && path.isNotEmpty) {
      if (path.startsWith('http')) {
        return Image.network(
          path,
          fit: BoxFit.fill,
          errorBuilder: (c, e, s) {
            debugPrint('Error loading network image: $e');
            return Container(color: Colors.black26);
          },
        );
      }
      final file = File(path);
      if (!file.existsSync()) {
        debugPrint('Image file does not exist at path: $path');
        return Container(
          color: Colors.black45,
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white54),
          ),
        );
      }
      return Image.file(
        file,
        fit: BoxFit.fill,
        errorBuilder: (c, e, s) {
          debugPrint('Error loading file image: $e');
          return Container(color: Colors.black26);
        },
      );
    }
    return Image.network(
      kMappingFallbackImageUrl,
      fit: BoxFit.fill,
      errorBuilder: (c, e, s) => Container(color: Colors.black26),
    );
  }
}
