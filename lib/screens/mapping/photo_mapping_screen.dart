import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/device_service.dart';
import '../../services/device_mapping_service.dart';
import '../../services/ai_backend_service.dart';
import '../../services/tts_service.dart';
import '../../services/ble_service.dart';
import '../../widgets/responsive_scale.dart';
import '../../widgets/top_app_bar.dart';

class ButtonPoint {
  final String id;
  final Offset position;
  final String label;

  ButtonPoint({required this.id, required this.position, required this.label});
}

class PhotoMappingScreen extends StatefulWidget {
  final String deviceId;
  final String? imagePath;
  const PhotoMappingScreen({super.key, required this.deviceId, this.imagePath});

  @override
  State<PhotoMappingScreen> createState() => _PhotoMappingScreenState();
}

class _PhotoMappingScreenState extends State<PhotoMappingScreen> {
  final List<ButtonPoint> _points = [];
  final GlobalKey _imageKey = GlobalKey();
  final DeviceService _deviceService = MockDeviceService();
  DeviceMappingProfile? _loadedProfile;
  final TtsService _tts = TtsService();

  @override
  void initState() {
    super.initState();
    _loadProfileAndConnect();
  }

  void _handleTap(TapUpDetails details) {
    final RenderBox? renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    final localPosition = renderBox.globalToLocal(details.globalPosition);
    final relativeX = (localPosition.dx / renderBox.size.width).clamp(0.0, 1.0);
    final relativeY = (localPosition.dy / renderBox.size.height).clamp(0.0, 1.0);

    setState(() {
      if (_points.length < 9) {
        _points.add(ButtonPoint(
          id: DateTime.now().toString(),
          position: Offset(relativeX, relativeY),
          label: '버튼 ${_points.length + 1}',
        ));
      }
    });
  }

  void _removePoint(int index) {
    setState(() => _points.removeAt(index));
  }

  Future<void> _loadProfileAndConnect() async {
    try {
      final profile = await DeviceMappingService.instance.load(widget.deviceId);
      setState(() => _loadedProfile = profile);
    } catch (_) {
      // ignore
    }
    // connect to device (mock)
    _deviceService.connect(widget.deviceId);

    // If an image path is provided and AI backend is configured, request auto-mapping
    if (widget.imagePath != null && AiBackendService.instance.isConfigured) {
      try {
        if (!widget.imagePath!.startsWith('http')) {
          final file = File(widget.imagePath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final mime = widget.imagePath!.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
            final res = await AiBackendService.instance.analyzeMappingImage(imageBytes: bytes, mimeType: mime);
            _applyAiMappingResult(res);
          }
        }
      } catch (e) {
        debugPrint('AI mapping failed: $e');
      }
    }
  }

  Future<void> _onSavePressed() async {
    final profile = await DeviceMappingService.instance.load(widget.deviceId);
    final rows = profile.rows;
    final cols = profile.cols;
    final map = <String, ({int row, int col})>{};
    final usedIds = <String>{};
    const int maxButtons = 9;

    for (var i = 0; i < _points.length; i++) {
      final point = _points[i];
      var colIdx = (point.position.dx * cols).floor();
      if (colIdx < 0) colIdx = 0;
      if (colIdx >= cols) colIdx = cols - 1;
      var rowIdx = (point.position.dy * rows).floor();
      if (rowIdx < 0) rowIdx = 0;
      if (rowIdx >= rows) rowIdx = rows - 1;

      // Prefer AI/user label -> button id mapping
      String? btId = DeviceMappingService.instance.labelToButtonId(point.label);
      if (btId == null || usedIds.contains(btId)) {
        // find next available default BT-xx id
        for (var k = 1; k <= maxButtons; k++) {
          final cand = 'BT-${k.toString().padLeft(2, '0')}';
          if (!usedIds.contains(cand)) {
            btId = cand;
            break;
          }
        }
      }
      if (btId == null) continue;
      usedIds.add(btId);
      map[btId] = (row: rowIdx, col: colIdx);
    }

    final newProfile = DeviceMappingProfile(
      rows: rows,
      cols: cols,
      originX: profile.originX,
      originY: profile.originY,
      pitchX: profile.pitchX,
      pitchY: profile.pitchY,
      buttonMap: map,
    );

    await DeviceMappingService.instance.save(widget.deviceId, newProfile);

    // Try sending to BLE if connected (set grid + small verification presses)
    String snackText = '매핑 저장 완료';
    try {
      if (BleService.instance.isConnected) {
        final ok = await BleService.instance.sendSetGrid(
          rows: newProfile.rows,
          cols: newProfile.cols,
          originX: newProfile.originX,
          originY: newProfile.originY,
          pitchX: newProfile.pitchX,
          pitchY: newProfile.pitchY,
          deviceId: widget.deviceId,
        );
        if (ok) {
          int verified = 0;
          final entries = map.entries.toList();
          final toVerify = entries.take(3).toList();
          for (final e in toVerify) {
            final r = e.value.row;
            final c = e.value.col;
            final pressOk = await BleService.instance.sendPress(x: c, y: r, deviceId: widget.deviceId);
            if (pressOk) verified++;
            await Future<void>.delayed(const Duration(milliseconds: 300));
          }
          snackText += ' · BLE 전송 성공 (검증: $verified/${toVerify.length})';
          try { await _tts.speak('BLE에 프로필 업로드 완료. ${verified}개 버튼을 확인했습니다.'); } catch (_) {}
        } else {
          snackText += ' · BLE 업로드 실패';
          try { await _tts.speak('BLE 업로드에 실패했습니다.'); } catch (_) {}
        }
      } else {
        snackText += ' · BLE 미연결';
      }
    } catch (e) {
      snackText += ' · BLE 오류';
    }

    try {
      await _deviceService.saveMappingData(_points.map((p) => p.position).toList());
    } catch (_) {}

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(snackText)));
      Navigator.of(context).pop();
    }
  }

  void _applyAiMappingResult(Map<String, dynamic> res) {
    final items = (res['buttons'] ?? res['items'] ?? res['detections']) as List<dynamic>?;
    if (items == null) return;
    final newPoints = <ButtonPoint>[];
    for (final raw in items) {
      if (raw is Map<String, dynamic>) {
        double? nx;
        double? ny;
        String label = (raw['label'] ?? raw['text'] ?? '') as String;
        if (raw.containsKey('x') && raw.containsKey('y')) {
          final xv = raw['x'];
          final yv = raw['y'];
          if (xv is num && yv is num) {
            nx = xv.toDouble();
            ny = yv.toDouble();
          }
        } else if (raw.containsKey('box')) {
          final box = raw['box'];
          if (box is Map) {
            final left = (box['x'] ?? box['left'] ?? box['l']) as num?;
            final top = (box['y'] ?? box['top'] ?? box['t']) as num?;
            final w = (box['w'] ?? box['width']) as num?;
            final h = (box['h'] ?? box['height']) as num?;
            if (left != null && top != null && w != null && h != null) {
              nx = left.toDouble() + w.toDouble() / 2.0;
              ny = top.toDouble() + h.toDouble() / 2.0;
            }
          }
        }
        if (nx != null && ny != null) {
          nx = nx.clamp(0.0, 1.0);
          ny = ny.clamp(0.0, 1.0);
          newPoints.add(ButtonPoint(id: DateTime.now().toString(), position: Offset(nx, ny), label: label.isNotEmpty ? label : '버튼 ${newPoints.length + 1}'));
        }
      }
    }
    if (newPoints.isNotEmpty) {
      setState(() {
        _points.clear();
        _points.addAll(newPoints.take(9));
      });
      try { _tts.speak('AI 자동 매핑이 완료되었습니다. 필요하면 위치를 조정하세요.'); } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final rs = ResponsiveScale.factor(context);
    return Scaffold(
      backgroundColor: const Color(0xFF041329),
      appBar: TopAppBar(
        title: '버튼 매핑',
        showBack: true,
        actions: [
          TextButton(
            onPressed: () => setState(() => _points.clear()),
            child: Text('초기화', style: TextStyle(color: Colors.white70, fontSize: 14 * rs)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(16 * rs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('STEP 2: 정밀 매핑', style: TextStyle(fontSize: 13 * rs, fontWeight: FontWeight.w700, color: const Color(0xFFE2C62D))),
                    SizedBox(height: ResponsiveScale.v(context, 4)),
                    Text('실제 버튼 위치를 터치하세요', style: TextStyle(fontSize: 24 * rs, fontWeight: FontWeight.w900, color: Colors.white)),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16 * rs),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            GestureDetector(
                              onTapUp: _handleTap,
                              child: (widget.imagePath != null)
                                  ? (widget.imagePath!.startsWith('http')
                                      ? Image.network(widget.imagePath!, key: _imageKey, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.black26))
                                      : Image.file(File(widget.imagePath!), key: _imageKey, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.black26)))
                                  : Image.network(
                                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBnqtd9QhBxdz_JPVKIqregy0_eQ3-Kmm7GhJ8UoFacsWE5PEO-nYQkiuURtdw1a2Cs-HJLoqEIedm0jvg30rAPgKdOP31oZW5vxfMBJbKgF91uW3lKKboV4zYLwECV2iUnU_UEVKndaTiSpa38QlC_tjoqt7_M9_T9vRF0bU4s2DcqnJHCe6dAFIbehXzzPXMcudEPtJGpt2aY-AFAF4Mn3vw5n7xiaxpHljgqh7f0myzhl1b-copBdl6DRlJsKMDkY-1Pm1K4y8ZO',
                                      key: _imageKey, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.black26),
                                    ),
                            ),
                            IgnorePointer(child: Container(color: Colors.black.withValues(alpha: 0.3))),
                            LayoutBuilder(
                              builder: (context, constraints) => Stack(
                                children: _points.asMap().entries.map((entry) {
                                  final idx = entry.key; final point = entry.value;
                                  return Positioned(
                                    left: point.position.dx * constraints.maxWidth - (20 * rs),
                                    top: point.position.dy * constraints.maxHeight - (20 * rs),
                                    child: _buildMarker(idx, rs),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: ResponsiveScale.v(context, 16)),
                    Container(
                      padding: EdgeInsets.all(12 * rs),
                      decoration: BoxDecoration(color: const Color(0xFF0D1C32), borderRadius: BorderRadius.circular(12 * rs)),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, color: const Color(0xFFFDE047), size: 18 * rs),
                        SizedBox(width: 8 * rs),
                        Text('현재 ${_points.length}/9개 매핑됨', style: TextStyle(color: Colors.white70, fontSize: 13 * rs)),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(20 * rs),
              child: ElevatedButton(
                onPressed: _points.isEmpty ? null : _onSavePressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFEB00), foregroundColor: Colors.black,
                  minimumSize: Size(double.infinity, 60 * rs),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16 * rs)),
                ),
                child: Text('이 구성으로 저장하기', style: TextStyle(fontSize: 18 * rs, fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMarker(int index, double rs) {
    return GestureDetector(
      onTap: () => _removePoint(index),
      child: Column(children: [
        Container(
          width: 40 * rs, height: 40 * rs,
          decoration: BoxDecoration(
            color: const Color(0xFFFFEB00).withValues(alpha: 0.9), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2 * rs),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 8 * rs)],
          ),
          child: Center(child: Text('${index + 1}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18 * rs))),
        ),
        SizedBox(height: 4 * rs),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6 * rs, vertical: 2 * rs),
          decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4 * rs)),
          child: Text('삭제', style: TextStyle(color: Colors.white, fontSize: 10 * rs)),
        ),
      ]),
    );
  }
}
