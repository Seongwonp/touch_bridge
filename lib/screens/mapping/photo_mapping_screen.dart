import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/tts_service.dart';

class PhotoMappingScreen extends StatefulWidget {
  const PhotoMappingScreen({super.key});

  @override
  State<PhotoMappingScreen> createState() => _PhotoMappingScreenState();
}

class _PhotoMappingScreenState extends State<PhotoMappingScreen> {
  final TtsService _tts = TtsService();
  final ImagePicker _picker = ImagePicker();

  // 3x3 그리드: null = 빈 셀, String = 버튼 라벨
  List<List<String?>> _grid = List.generate(3, (_) => List.filled(3, null));
  Uint8List? _imageBytes;
  String _deviceType = '';
  bool _isAnalyzing = false;
  String _statusMessage = '카메라 버튼을 눌러 기기를 촬영하세요.';

  @override
  void initState() {
    super.initState();
    _tts.speak('버튼 매핑 화면입니다. 카메라 버튼을 눌러 가전기기를 촬영하면 AI가 버튼을 자동으로 인식합니다.');
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  String _mimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }

  Future<void> _takePhoto() async {
    final apiKey = dotenv.get('GOOGLE_AI_PRO_API_KEY', fallback: '');
    if (apiKey.isEmpty) {
      _tts.speak('API 키가 설정되지 않아 AI 분석을 사용할 수 없습니다.');
      return;
    }

    try {
      // macOS는 카메라 미지원 → 갤러리 사용
      final source = defaultTargetPlatform == TargetPlatform.macOS
          ? ImageSource.gallery
          : ImageSource.camera;

      final XFile? photo = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final mime = _mimeType(photo.path);

      setState(() {
        _imageBytes = bytes;
        _isAnalyzing = true;
        _statusMessage = 'AI가 버튼을 분석 중입니다...';
        _grid = List.generate(3, (_) => List.filled(3, null));
        _deviceType = '';
      });
      _tts.speak('사진을 받았습니다. AI가 버튼을 분석하고 있습니다. 잠시 기다려 주세요.');

      await _analyzeWithGemini(bytes, mime, apiKey);
    } catch (e) {
      if (kDebugMode) debugPrint('Photo pick error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = '사진 촬영에 실패했습니다. 다시 시도해 주세요.';
        });
        _tts.speak(_statusMessage);
      }
    }
  }

  Future<void> _analyzeWithGemini(
    Uint8List imageBytes,
    String mimeType,
    String apiKey,
  ) async {
    try {
      final modelName = dotenv.get('GEMINI_MODEL', fallback: 'gemini-2.5-flash');
      final model = GenerativeModel(model: modelName, apiKey: apiKey);

      const prompt = '''
이 이미지는 가전기기의 터치패드 사진입니다.
사진에 보이는 버튼들을 분석하여 3×3 그리드(row 0~2, col 0~2)에 매핑해주세요.
(0,0)은 왼쪽 위, (2,2)는 오른쪽 아래입니다.

반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트는 포함하지 마세요:
{
  "device_type": "전자레인지",
  "description": "전자레인지 터치패드입니다. 시작, 취소 등 6개 버튼을 인식했습니다.",
  "buttons": [
    {"row": 0, "col": 0, "label": "시작"},
    {"row": 0, "col": 1, "label": "취소"},
    {"row": 0, "col": 2, "label": "+30초"}
  ]
}

버튼이 없는 위치는 포함하지 마세요. 라벨은 간결한 한국어로 작성하세요.
''';

      final response = await model.generateContent([
        Content.multi([
          DataPart(mimeType, imageBytes),
          TextPart(prompt),
        ]),
      ]);

      if (!mounted) return;

      final text = response.text?.trim() ?? '';
      String jsonStr = text;
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
        jsonStr = jsonStr.substring(0, jsonStr.lastIndexOf('```')).trim();
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
        jsonStr = jsonStr.substring(0, jsonStr.lastIndexOf('```')).trim();
      }

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final deviceType = data['device_type'] as String? ?? '기기';
      final description = data['description'] as String? ?? '';
      final buttons = data['buttons'] as List<dynamic>? ?? [];

      final newGrid = List.generate(3, (_) => List.filled(3, null as String?));
      for (final btn in buttons) {
        final row = (btn['row'] as num).toInt();
        final col = (btn['col'] as num).toInt();
        final label = btn['label'] as String? ?? '';
        if (row >= 0 && row < 3 && col >= 0 && col < 3 && label.isNotEmpty) {
          newGrid[row][col] = label;
        }
      }

      setState(() {
        _grid = newGrid;
        _deviceType = deviceType;
        _isAnalyzing = false;
        _statusMessage = description.isNotEmpty ? description : '$deviceType 버튼 인식 완료';
      });

      _tts.speak(
        description.isNotEmpty
            ? description
            : '$deviceType 버튼 인식이 완료되었습니다. 각 셀을 탭하여 라벨을 수정할 수 있습니다.',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Gemini Vision error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusMessage = 'AI 분석에 실패했습니다. 다시 촬영해 주세요.';
        });
        _tts.speak(_statusMessage);
      }
    }
  }

  void _editCell(int row, int col) {
    final current = _grid[row][col] ?? '';
    final ctrl = TextEditingController(text: current);

    _tts.speak(
      current.isEmpty
          ? '${row + 1}행 ${col + 1}열 빈 셀입니다. 버튼 이름을 입력하세요.'
          : '${row + 1}행 ${col + 1}열 $current 버튼입니다. 이름을 수정하세요.',
    );

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '${row + 1}행 ${col + 1}열 버튼 편집',
          style: const TextStyle(
            color: Color(0xFFFDE047),
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          decoration: InputDecoration(
            hintText: '버튼 이름 입력 (비우면 삭제)',
            hintStyle: const TextStyle(color: Color(0xFF555577)),
            filled: true,
            fillColor: const Color(0xFF0D1C32),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF333355)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFFDE047), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소', style: TextStyle(color: Color(0xFF888888))),
          ),
          ElevatedButton(
            onPressed: () {
              final label = ctrl.text.trim();
              setState(() => _grid[row][col] = label.isEmpty ? null : label);
              Navigator.of(ctx).pop();
              HapticFeedback.selectionClick();
              _tts.speak(
                label.isEmpty ? '셀이 삭제되었습니다.' : '$label 버튼으로 저장되었습니다.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFDE047),
              foregroundColor: const Color(0xFF041329),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('저장', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final label = _grid[row][col];
    final hasLabel = label != null && label.isNotEmpty;

    return Semantics(
      label: hasLabel ? '$label 버튼. 탭하여 수정.' : '빈 셀 ${row + 1}행 ${col + 1}열. 탭하여 추가.',
      button: true,
      child: GestureDetector(
        onTap: () => _editCell(row, col),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: hasLabel ? const Color(0x33FDE047) : const Color(0x0AFDE047),
            border: Border.all(
              color: hasLabel
                  ? const Color(0x88FDE047)
                  : const Color(0x33FDE047),
              width: hasLabel ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: hasLabel
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFFE2C62D),
                        size: 18,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFDE047),
                          letterSpacing: 0.3,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  )
                : const Icon(
                    Icons.add_rounded,
                    color: Color(0x55FDE047),
                    size: 28,
                  ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final assignedCount = _grid.expand((r) => r).where((c) => c != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      body: Stack(
        children: [
          // 배경 그라디언트
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.8, -0.7),
                radius: 1.2,
                colors: [Color(0x2200B8FF), Color(0xFF041329)],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // 앱바
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0x33FDE047))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          _tts.speak('이전 화면으로 돌아갑니다.');
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFFFDE047),
                        ),
                      ),
                      const Text(
                        'Touch Bridge',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFDE047),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 헤더
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AI 버튼 매핑',
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if (_deviceType.isNotEmpty)
                                    Text(
                                      _deviceType,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFFE2C62D),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // 진행 상황 배지
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: assignedCount > 0
                                    ? const Color(0x33FDE047)
                                    : const Color(0x1AFFFFFF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: assignedCount > 0
                                      ? const Color(0x88FDE047)
                                      : const Color(0x33FFFFFF),
                                ),
                              ),
                              child: Text(
                                '$assignedCount / 9',
                                style: TextStyle(
                                  color: assignedCount > 0
                                      ? const Color(0xFFFDE047)
                                      : const Color(0x88FFFFFF),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // 상태 메시지
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Color(0xAAD6E3FF),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 12),

                        // 이미지 + 그리드 영역
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 배경: 사진 or 플레이스홀더
                                if (_imageBytes != null)
                                  Image.memory(
                                    _imageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                else
                                  Container(
                                    color: const Color(0xFF0D1C32),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.photo_camera_rounded,
                                          size: 56,
                                          color: Color(0x55FDE047),
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          '카메라 버튼을 눌러 기기를 촬영하세요',
                                          style: TextStyle(
                                            color: Color(0x88FDE047),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // 반투명 오버레이
                                Container(color: const Color(0x77041329)),

                                // 분석 중 로딩
                                if (_isAnalyzing)
                                  Container(
                                    color: const Color(0xCC041329),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Color(0xFFFDE047),
                                          strokeWidth: 3,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'AI가 버튼을 분석 중...',
                                          style: TextStyle(
                                            color: Color(0xFFFDE047),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  // 3x3 그리드
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: const Color(0x55FDE047),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: GridView.builder(
                                      physics: const NeverScrollableScrollPhysics(),
                                      gridDelegate:
                                          const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 3,
                                      ),
                                      itemCount: 9,
                                      itemBuilder: (_, index) {
                                        final row = index ~/ 3;
                                        final col = index % 3;
                                        return _buildCell(row, col);
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // 하단 버튼 행
                        Row(
                          children: [
                            // 촬영 버튼
                            Expanded(
                              child: Semantics(
                                label: '카메라로 기기 촬영 및 AI 분석 버튼',
                                button: true,
                                child: ElevatedButton.icon(
                                  onPressed: _isAnalyzing ? null : _takePhoto,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF27354C),
                                    foregroundColor: const Color(0xFFE2C62D),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.photo_camera_rounded,
                                    size: 20,
                                  ),
                                  label: Text(
                                    _imageBytes == null ? '기기 촬영' : '다시 촬영',
                                    style: const TextStyle(fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // 매핑 완료 버튼
                            Expanded(
                              child: Semantics(
                                label: '매핑 완료 버튼. 현재 $assignedCount개 버튼 설정됨.',
                                button: true,
                                child: ElevatedButton.icon(
                                  onPressed: assignedCount == 0
                                      ? null
                                      : () {
                                          _tts.speak(
                                            '$assignedCount개 버튼 매핑이 완료되었습니다. 하드웨어 연결 후 적용됩니다.',
                                          );
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                '$assignedCount개 버튼 매핑 완료! (BLE 연결 후 적용)',
                                              ),
                                              backgroundColor: const Color(0xFFFDE047),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: assignedCount > 0
                                        ? const Color(0xFFFDE047)
                                        : const Color(0xFF1A2A3A),
                                    foregroundColor: assignedCount > 0
                                        ? const Color(0xFF041329)
                                        : const Color(0xFF555577),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_rounded, size: 20),
                                  label: const Text(
                                    '매핑 완료',
                                    style: TextStyle(fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
