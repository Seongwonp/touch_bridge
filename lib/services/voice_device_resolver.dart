class RegisteredVoiceDevice {
  const RegisteredVoiceDevice({
    required this.id,
    required this.name,
    this.bleId,
    this.bleName,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final String? bleId;
  final String? bleName;

  /// 사용자/보호자가 붙인 별명 ("우리집 세탁기" 등) — 음성 매칭에 이름과
  /// 동급으로 사용된다. 기기 관리 화면에서 편집.
  final List<String> aliases;

  factory RegisteredVoiceDevice.fromJson(Map<String, dynamic> json) {
    final rawAliases = json['aliases'];
    return RegisteredVoiceDevice(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '스마트 기기',
      bleId: json['bleId'] as String?,
      bleName: json['bleName'] as String?,
      aliases: rawAliases is List
          ? rawAliases.whereType<String>().toList(growable: false)
          : const [],
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

    // 이름과 별명을 동급으로 매칭한다. 어떤 표현으로 불렸는지(term)를 기억해
    // 명령 텍스트에서 그 표현을 제거할 수 있게 한다.
    // 긴 표현부터 검사한다(최장 일치) — "우리집 세탁기"라고 불렀는데 이름
    // "세탁기"가 먼저 매칭되면 명령 텍스트에 "우리집"이 찌꺼기로 남는다.
    final mentionedEntries =
        <({RegisteredVoiceDevice device, String term})>[];
    for (final device in devices) {
      final terms = [device.name, ...device.aliases]
        ..sort((a, b) => _normalize(b).length.compareTo(_normalize(a).length));
      for (final term in terms) {
        final normalizedTerm = _normalize(term);
        if (normalizedTerm.isNotEmpty &&
            normalizedText.contains(normalizedTerm)) {
          mentionedEntries.add((device: device, term: term));
          break; // 기기당 한 번만
        }
      }
    }
    final mentioned =
        mentionedEntries.map((e) => e.device).toList(growable: false);

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

    final commandText = mentionedEntries.isEmpty
        ? text.trim()
        : _removeDeviceName(text, mentionedEntries.first.term);

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
