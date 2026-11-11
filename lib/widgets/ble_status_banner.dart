import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ble_service.dart';
import '../services/speech_session_service.dart';
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
            if (!SpeechSessionService.instance.shouldStayQuiet) {
              _tts.speak('블루투스 재연결됐습니다.', source: 'BleStatusBanner');
            }
          case BleReconnectState.failed:
            _status = _BleStatus.failed;
            // 마이크가 말을 기다리는 중이면 말하지 않는다(녹음에 섞인다). 배너 글자는 바뀐다.
            if (SpeechSessionService.instance.shouldStayQuiet) break;
            _tts.speak(
              // 연결 설정은 보호자 기능이라 사용자에게 시키지 않는다(외부 평가).
              // 다음 명령 때 앱이 자동으로 다시 연결을 시도한다.
              '기기와 연결이 끊겼습니다. 다시 말씀하시면 자동으로 연결을 시도합니다. 계속 안 되면 보호자에게 알려 주세요.',
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
          'Touch Bridge 연결 안 됨',
          AppColors.textTertiary,
          Icons.hub_outlined,
        ),
    };

    return Semantics(
      // 다른 글자와 한 덩어리로 합쳐 읽히지 않게 따로 둔다.
      container: true,
      // 상태가 바뀔 때마다 낭독기가 읽는다. 단, 마이크가 사용자의 말을 기다리는 동안에는
      // 읽지 않는다(그 소리가 녹음돼 명령으로 들어갔다 — 실기).
      liveRegion: !SpeechSessionService.instance.shouldStayQuiet,
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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  // 저시력 사용자가 연결 상태를 읽을 수 있게 키우고, 시스템 글자 확대를 따른다.
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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
