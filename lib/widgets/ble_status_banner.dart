import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../services/tts_service.dart';
import '../theme/app_colors.dart';

/// BLE 연결 상태를 실시간으로 표시하고 스크린리더에 자동 낭독하는 배너.
///
/// - 연결됨 / 재연결 중 / 재연결 실패 / 미연결 상태를 색상·아이콘으로 표시.
/// - [Semantics.liveRegion] = true → 상태 변화 시 TalkBack/VoiceOver 자동 읽기.
/// - 재연결 성공/실패 시 [TtsService]로도 한국어 안내 발화.
class BleStatusBanner extends StatefulWidget {
  const BleStatusBanner({super.key});

  @override
  State<BleStatusBanner> createState() => _BleStatusBannerState();
}

class _BleStatusBannerState extends State<BleStatusBanner> {
  final TtsService _tts = TtsService();

  _BleStatus _status = _BleStatus.disconnected;
  String _deviceName = '';

  StreamSubscription<bool>? _connSub;
  StreamSubscription<BleReconnectState>? _reconnSub;

  @override
  void initState() {
    super.initState();
    _syncFromService();

    _connSub = BleService.instance.isConnectedStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        if (connected) {
          _status = _BleStatus.connected;
          _deviceName = BleService.instance.connectedDeviceName;
        } else if (!BleService.instance.isReconnecting) {
          _status = _BleStatus.disconnected;
        }
      });
    });

    _reconnSub = BleService.instance.reconnectStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        switch (state) {
          case BleReconnectState.reconnecting:
            _status = _BleStatus.reconnecting;
          case BleReconnectState.reconnected:
            _status = _BleStatus.connected;
            _deviceName = BleService.instance.connectedDeviceName;
            _tts.speak('블루투스 재연결됐습니다.', source: 'BleStatusBanner');
          case BleReconnectState.failed:
            _status = _BleStatus.failed;
            _tts.speak(
              '블루투스 재연결에 실패했습니다. 설정에서 기기를 다시 연결해 주세요.',
              source: 'BleStatusBanner',
              priority: TtsPriority.result,
              interrupt: true,
            );
        }
      });
    });
  }

  void _syncFromService() {
    if (BleService.instance.isConnected) {
      _status = _BleStatus.connected;
      _deviceName = BleService.instance.connectedDeviceName;
    } else if (BleService.instance.isReconnecting) {
      _status = _BleStatus.reconnecting;
    } else {
      _status = _BleStatus.disconnected;
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _reconnSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (_status) {
      _BleStatus.connected => (
          '연결됨: $_deviceName',
          AppColors.success,
          Icons.hub_rounded,
        ),
      _BleStatus.reconnecting => (
          '재연결 중...',
          AppColors.warning,
          Icons.sync_rounded,
        ),
      _BleStatus.failed => (
          '연결 끊김 · 재연결 실패',
          AppColors.emergency,
          Icons.hub_outlined,
        ),
      _BleStatus.disconnected => (
          '허브 연결 필요',
          AppColors.textTertiary,
          Icons.hub_outlined,
        ),
    };

    return Semantics(
      // liveRegion: true → 상태가 바뀔 때마다 스크린리더가 label을 자동 낭독.
      liveRegion: true,
      label: label,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_status == _BleStatus.reconnecting)
                _SpinningIcon(icon: icon, color: color, size: 13)
              else
                Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 재연결 중 표시용 회전 아이콘.
class _SpinningIcon extends StatefulWidget {
  const _SpinningIcon({
    required this.icon,
    required this.color,
    required this.size,
  });
  final IconData icon;
  final Color color;
  final double size;

  @override
  State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _ctrl,
      child: Icon(widget.icon, size: widget.size, color: widget.color),
    );
  }
}

enum _BleStatus { connected, reconnecting, failed, disconnected }
