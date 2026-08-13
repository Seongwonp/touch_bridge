class RegisteredVoiceDevice {
  const RegisteredVoiceDevice({
    required this.id,
    required this.name,
    this.bleId,
    this.bleName,
  });

  final String id;
  final String name;
  final String? bleId;
  final String? bleName;

  factory RegisteredVoiceDevice.fromJson(Map<String, dynamic> json) {
    return RegisteredVoiceDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '스마트 기기',
      bleId: json['bleId'] as String?,
      bleName: json['bleName'] as String?,
    );
  }
}

class VoiceDeviceResolution {
  const VoiceDeviceResolution({
    required this.commandText,
    this.device,
    this.needsClarification = false,
    this.needsAction = false,
    this.message = '',
  });

  final String commandText;
  final RegisteredVoiceDevice? device;
  final bool needsClarification;
  final bool needsAction;
  final String message;
}

class VoiceDeviceResolver {
  const VoiceDeviceResolver._();

  static VoiceDeviceResolution resolve({
    required String text,
    required List<RegisteredVoiceDevice> devices,
    String? preferredDeviceId,
    String? preferredDeviceName,
  }) {
    final normalizedText = _normalize(text);
    if (normalizedText.isEmpty) {
      return const VoiceDeviceResolution(
        commandText: '',
        needsClarification: true,
        message: '명령을 다시 말씀해 주세요.',
      );
    }

    if (devices.isEmpty) {
      return const VoiceDeviceResolution(
        commandText: '',
        needsClarification: true,
        message: '등록된 기기가 없습니다. 보호자에게 기기 추가를 요청하세요.',
      );
    }

    final mentioned = devices.where((device) {
      final normalizedName = _normalize(device.name);
      return normalizedName.isNotEmpty &&
          normalizedText.contains(normalizedName);
    }).toList();

    if (mentioned.length > 1) {
      final names = mentioned.map((d) => d.name).join(', ');
      return VoiceDeviceResolution(
        commandText: text,
        needsClarification: true,
        message: '기기가 여러 개로 들렸습니다. $names 중 어떤 기기인가요?',
      );
    }

    final selected =
        mentioned.singleOrNull ??
        _findPreferred(
          devices,
          preferredDeviceId: preferredDeviceId,
          preferredDeviceName: preferredDeviceName,
        ) ??
        (devices.length == 1 ? devices.first : null);

    if (selected == null) {
      final names = devices.take(3).map((d) => d.name).join(', ');
      return VoiceDeviceResolution(
        commandText: text,
        needsClarification: true,
        message: '어떤 기기를 작동할까요? $names 중에서 말씀해 주세요.',
      );
    }

    final commandText = mentioned.isEmpty
        ? text.trim()
        : _removeDeviceName(text, selected.name);

    if (!_looksLikeAction(commandText)) {
      return VoiceDeviceResolution(
        commandText: commandText,
        device: selected,
        needsAction: true,
        message: '${selected.name}에서 어떤 동작을 할까요?',
      );
    }

    return VoiceDeviceResolution(commandText: commandText, device: selected);
  }

  static RegisteredVoiceDevice? _findPreferred(
    List<RegisteredVoiceDevice> devices, {
    String? preferredDeviceId,
    String? preferredDeviceName,
  }) {
    final preferredId = preferredDeviceId?.trim();
    if (preferredId != null && preferredId.isNotEmpty) {
      for (final device in devices) {
        if (device.id == preferredId) return device;
      }
    }

    final preferredName = _normalize(preferredDeviceName ?? '');
    if (preferredName.isNotEmpty) {
      for (final device in devices) {
        if (_normalize(device.name) == preferredName) return device;
      }
    }

    return null;
  }

  static String _removeDeviceName(String text, String deviceName) {
    final removed = text.replaceAll(deviceName, '').trim();
    return removed.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static bool _looksLikeAction(String text) {
    final t = _normalize(text);
    if (t.isEmpty) return false;

    final actionTokens = [
      '시작',
      '데워',
      '돌려',
      '조리',
      '취소',
      '정지',
      '중단',
      '멈춰',
      '그만',
      '해동',
      '우유',
      '자동',
      '눌러',
      '버튼',
      '초',
      '분',
      'stop',
    ];
    return actionTokens.any(t.contains) || RegExp(r'\d+번').hasMatch(t);
  }

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }
}
