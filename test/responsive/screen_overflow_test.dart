// 화면 크기·글자 확대·키보드 조합별 레이아웃 overflow 탐지.
//
// 실기기(Galaxy A31, 약 411x914dp)에서 홈 "기기 추가하기" 라벨이 잘린 사례를
// 계기로, lib/screens 아래 최상위 화면을 여러 설정으로 띄워 RenderFlex 등
// overflow 오류를 모두 수집한다. 첫 오류에서 멈추지 않도록 펌프 중에는
// FlutterError.onError를 가로채고, 마지막에 화면 × 설정 요약을 출력한다.
//
// 이 테스트는 탐지용이라 overflow가 있어도 실패하지 않는다(요약만 출력).
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touch_bridge/screens/connection/device_connect_screen.dart';
import 'package:touch_bridge/screens/connection/qr_scan_screen.dart';
import 'package:touch_bridge/screens/control/course_control_screen.dart';
import 'package:touch_bridge/screens/control/image_control_screen.dart';
import 'package:touch_bridge/screens/control/remote_control_screen.dart';
import 'package:touch_bridge/screens/home/appliance_selection_screen.dart';
import 'package:touch_bridge/screens/home/home_screen.dart';
import 'package:touch_bridge/screens/home/widgets/home_add_device_card.dart';
import 'package:touch_bridge/screens/main_navigation_screen.dart';
import 'package:touch_bridge/screens/mapping/guardian_handoff_screen.dart';
import 'package:touch_bridge/screens/mapping/manual_mapping_screen.dart';
import 'package:touch_bridge/screens/mapping/photo_mapping_screen.dart';
import 'package:touch_bridge/screens/practice/practice_screen.dart';
import 'package:touch_bridge/screens/safety/emergency_access_screen.dart';
import 'package:touch_bridge/screens/safety/emergency_stop_screen.dart';
import 'package:touch_bridge/screens/safety/stop_done_screen.dart';
import 'package:touch_bridge/screens/settings/ble_log_screen.dart';
import 'package:touch_bridge/screens/settings/developer_console_screen.dart';
import 'package:touch_bridge/screens/settings/device_management_screen.dart';
import 'package:touch_bridge/screens/settings/settings_screen.dart';
import 'package:touch_bridge/screens/voice/voice_listening_screen.dart';
import 'package:touch_bridge/services/accessibility_settings.dart';
import 'package:touch_bridge/services/active_device_service.dart';
import 'package:touch_bridge/services/ble_service.dart';
import 'package:touch_bridge/services/run_status_service.dart';
import 'package:touch_bridge/services/speech_session_service.dart';
import 'package:touch_bridge/services/tts_service.dart';
import 'package:touch_bridge/theme/app_theme.dart';

class _Config {
  const _Config(this.id, this.size, this.textScale,
      {this.keyboard = 0, this.realFont = true});
  final String id;
  /// true: NotoSansKR(실기기 Noto Sans CJK와 비슷한 줄 높이)로 렌더.
  /// false: flutter_test 기본 'FlutterTest' 폰트(1em 정사각, 줄 높이가 작아 낙관적).
  final bool realFont;
  final Size size; // logical dp
  final double textScale;
  final double keyboard; // viewInsets.bottom (dp)
}

const _configs = <_Config>[
  _Config('a 360x640 x1.0', Size(360, 640), 1.0),
  _Config('b 411x914 x1.0', Size(411, 914), 1.0),
  _Config('c 411x914 x1.3', Size(411, 914), 1.3),
  _Config('d 411x914 kb300', Size(411, 914), 1.0, keyboard: 300),
  // 추가 진단: 시스템 글자 확대가 더 큰 경우(앱은 최대 2.0까지 허용)
  _Config('e 411x914 x1.5', Size(411, 914), 1.5),
  _Config('f 411x914 x2.0', Size(411, 914), 2.0),
  // 비교용: 테스트 기본 폰트(줄 높이가 실기기보다 작다)
  _Config('a* 360x640 x1.0 test-font', Size(360, 640), 1.0, realFont: false),
  _Config('b* 411x914 x1.0 test-font', Size(411, 914), 1.0, realFont: false),
  _Config('c* 411x914 x1.3 test-font', Size(411, 914), 1.3, realFont: false),
];

const _realFontFamily = 'NotoSansKR';
bool _realFontLoaded = false;

Future<void> _loadRealFont() async {
  const candidates = [
    r'C:\Windows\Fonts\NotoSansKR-VF.ttf',
    r'C:\Windows\Fonts\malgun.ttf',
  ];
  for (final path in candidates) {
    final f = File(path);
    if (f.existsSync()) {
      final bytes = f.readAsBytesSync();
      final loader = FontLoader(_realFontFamily)
        ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
      await loader.load();
      _realFontLoaded = true;
      _notes['font'] = 'real font loaded from $path';
      return;
    }
  }
  _notes['font'] = 'no Korean font found; "real font" configs use test font';
}

ThemeData _themeFor(_Config c) {
  final base = AppTheme.lightTheme;
  if (!c.realFont || !_realFontLoaded) return base;
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: _realFontFamily),
    primaryTextTheme: base.primaryTextTheme.apply(fontFamily: _realFontFamily),
  );
}

class _Screen {
  const _Screen(
    this.name,
    this.builder, {
    this.hasTextField = false,
    this.prefs = const {},
    this.withActiveDevice = false,
    this.afterPump,
  });
  final String name;
  final Widget Function() builder;
  final bool hasTextField;
  final Map<String, Object> prefs;
  final bool withActiveDevice;
  final Future<void> Function(WidgetTester tester)? afterPump;
}

final _oneDevice = jsonEncode([
  {
    'id': 'test-microwave',
    'name': '전자레인지',
    'status': '작동 대기 중',
    'iconCodePoint': Icons.microwave.codePoint,
    'bleId': 'TEST-BLE-0001',
    'bleName': '테스트 브리지',
  },
]);

/// 홈 PageView를 마지막 페이지("새 기기 추가하기" 카드)로 넘긴다.
Future<void> _jumpToAddCard(WidgetTester tester) async {
  final pv = find.byType(PageView);
  if (pv.evaluate().isEmpty) return;
  final w = tester.widget<PageView>(pv.first);
  final ctrl = w.controller;
  if (ctrl == null || !ctrl.hasClients) return;
  final count = (w.childrenDelegate.estimatedChildCount ?? 1);
  ctrl.jumpToPage(count - 1);
  await tester.pump(const Duration(milliseconds: 300));
  // 진단: 추가 카드 안 SingleChildScrollView가 숨긴 높이(조용한 잘림)를 기록.
  final card = find.byType(HomeAddDeviceCard);
  if (card.evaluate().isEmpty) {
    _notes['$_currentKey add-card'] = 'HomeAddDeviceCard not built';
    return;
  }
  final sc = find.descendant(of: card, matching: find.byType(Scrollable));
  final label = find.descendant(of: card, matching: find.text('새 기기 추가하기'));
  final pos = tester.state<ScrollableState>(sc.first).position;
  final cardBox = tester.getRect(card);
  final labelRect = label.evaluate().isEmpty ? null : tester.getRect(label);
  _notes['$_currentKey add-card'] =
      'card ${cardBox.width.toStringAsFixed(0)}x${cardBox.height.toStringAsFixed(0)}, '
      'scroll viewport ${pos.viewportDimension.toStringAsFixed(0)}, hidden ${pos.maxScrollExtent.toStringAsFixed(1)}px, '
      'label rect ${labelRect == null ? '-' : '${labelRect.top.toStringAsFixed(0)}..${labelRect.bottom.toStringAsFixed(0)}'}';
}

String _currentKey = '';

final _screens = <_Screen>[
  _Screen('HomeScreen (no devices)', () => const HomeScreen()),
  _Screen(
    'HomeScreen (1 device, add-card page)',
    () => const HomeScreen(),
    prefs: {'home_devices': _oneDevice},
    afterPump: _jumpToAddCard,
  ),
  _Screen(
    'MainNavigation>Home (1 device, add-card page)',
    () => const MainNavigationScreen(),
    prefs: {'home_devices': _oneDevice, 'quick_start_seen': true},
    afterPump: _jumpToAddCard,
  ),
  _Screen(
    'MainNavigation>Home (no devices)',
    () => const MainNavigationScreen(),
    prefs: {'quick_start_seen': true},
  ),
  _Screen(
    'DeviceConnectScreen',
    () => const DeviceConnectScreen(),
    hasTextField: true,
  ),
  _Screen('QrScanScreen', () => const QrScanScreen()),
  _Screen(
    'CourseControlScreen',
    () => const CourseControlScreen(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
    ),
    withActiveDevice: true,
  ),
  _Screen(
    'ImageControlScreen',
    () => const ImageControlScreen(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
    ),
    withActiveDevice: true,
  ),
  _Screen(
    'RemoteControlScreen',
    () => const RemoteControlScreen(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
    ),
    withActiveDevice: true,
  ),
  _Screen(
    'ApplianceSelectionScreen',
    () => const ApplianceSelectionScreen(
      bleId: 'TEST-BLE-0001',
      bleName: '테스트 브리지',
    ),
  ),
  _Screen(
    'GuardianHandoffScreen',
    () => const GuardianHandoffScreen(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
    ),
  ),
  _Screen(
    'ManualMappingScreen',
    () => const ManualMappingScreen(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
    ),
    hasTextField: true,
  ),
  _Screen(
    'PhotoMappingScreen',
    () => const PhotoMappingScreen(deviceId: 'test-microwave'),
    hasTextField: true,
  ),
  _Screen('PracticeScreen', () => const PracticeScreen()),
  _Screen('EmergencyAccessScreen', () => const EmergencyAccessScreen()),
  _Screen(
    'EmergencyStopScreen',
    () => const EmergencyStopScreen(deviceName: '전자레인지'),
    withActiveDevice: true,
  ),
  _Screen('StopDoneScreen (completed)',
      () => const StopDoneScreen(completed: true)),
  _Screen('StopDoneScreen (not completed)', () => const StopDoneScreen()),
  _Screen('BleLogScreen', () => const BleLogScreen()),
  _Screen(
    'DeveloperConsoleScreen',
    () => const DeveloperConsoleScreen(),
    hasTextField: true,
  ),
  _Screen(
    'DeviceManagementScreen',
    () => const DeviceManagementScreen(),
    hasTextField: true,
    prefs: {'home_devices': _oneDevice},
  ),
  _Screen('SettingsScreen', () => const SettingsScreen(), hasTextField: true),
  _Screen(
    'VoiceListeningScreen',
    () => const VoiceListeningScreen(
      deviceId: 'test-microwave',
      deviceName: '전자레인지',
    ),
    withActiveDevice: true,
  ),
];

class _Finding {
  _Finding(this.kind, this.message, this.location);
  final String kind; // overflow | error
  final String message;
  final String location;
  @override
  String toString() => '$kind: $message @ $location';
}

final Map<String, Map<String, List<_Finding>>> _results = {};
final Map<String, String> _notes = {};

final _locRe = RegExp(r'(lib/[\w/]+\.dart):(\d+):(\d+)');

_Finding _toFinding(FlutterErrorDetails d) {
  final full = d.toString();
  final exc = d.exceptionAsString().split('\n').first.trim();
  final isOverflow = exc.contains('overflowed by');
  // "The relevant error-causing widget was:" 다음의 위치(lib/…)를 우선 사용.
  String location = '?';
  final idx = full.indexOf('relevant error-causing widget');
  final searchIn = idx >= 0 ? full.substring(idx) : full;
  final m = _locRe.firstMatch(searchIn) ?? _locRe.firstMatch(full);
  if (m != null) location = '${m.group(1)}:${m.group(2)}';
  // 위젯 이름(예: "Column Column:file:///...")
  if (idx >= 0) {
    final lines = searchIn.split('\n');
    if (lines.length > 1) {
      final w = lines[1].trim().split(' ').first;
      if (w.isNotEmpty) location = '$location ($w)';
    }
  }
  return _Finding(isOverflow ? 'overflow' : 'error', exc, location);
}


/// 앱 위젯 이름(lib 소속 추정: 대문자 시작, Flutter 기본 위젯 제외)을 creator chain에서 찾는다.
String _creatorHint(RenderObject ro) {
  final c = ro.debugCreator;
  if (c is! DebugCreator) return '?';
  final chain = c.element.debugGetCreatorChain(40).split(' \u2190 ');
  const appPrefixes = [
    'Home', 'Device', 'Stop', 'Emergency', 'Voice', 'Settings', 'Mapping',
    'Calibration', 'Jog', 'Esp', 'Practice', 'Manual', 'Photo', 'Remote',
    'Course', 'Image', 'Appliance', 'Guardian', 'Ble', 'Top', 'Primary',
    'Info', 'Press', 'Qr', '_',
  ];
  final hits = <String>[];
  for (final raw in chain) {
    final name = raw.split(RegExp(r'[-(\[]')).first.trim();
    if (appPrefixes.any(name.startsWith) &&
        !name.startsWith('_Render') && !name.startsWith('_Scrollable') &&
        !name.startsWith('_Ink') && !name.startsWith('_Effective') &&
        !name.startsWith('_Pointer') && !name.startsWith('_Gesture') &&
        !name.startsWith('_Focus') && !name.startsWith('_Semantics') &&
        !name.startsWith('_Overlay') && !name.startsWith('_Modal') &&
        !name.startsWith('_Theater') && !name.startsWith('_Body') &&
        !name.startsWith('_Scaffold') && !name.startsWith('_Material') &&
        !name.startsWith('_Default') && !name.startsWith('_Inherited') &&
        !name.startsWith('_Shared') && !name.startsWith('_Localizations') &&
        !name.startsWith('_Action') && !name.startsWith('_Shortcut') &&
        !name.startsWith('_Widgets') && !name.startsWith('_Media') &&
        !name.startsWith('_View') && !name.startsWith('_Raw') &&
        !name.startsWith('_Animated') && !name.startsWith('_Page') &&
        !name.startsWith('_Glowing') && !name.startsWith('_Stretching') &&
        !name.startsWith('_Toggle') && !name.startsWith('_Hero') &&
        !name.startsWith('_Text') && !name.startsWith('_Selectable') &&
        !name.startsWith('_Editable') && !name.startsWith('_Single') &&
        !name.startsWith('_Ticker') && !name.startsWith('_Interior') &&
        !name.startsWith('_Button') && !name.startsWith('_Elevated') &&
        !name.startsWith('_Outlined') && !name.startsWith('_Icon') &&
        !name.startsWith('_Filled') && !name.startsWith('_Input') &&
        !name.startsWith('_Decorat') && !name.startsWith('_Borders') &&
        !name.startsWith('_Helper') && !name.startsWith('_Ripple') &&
        !name.startsWith('_Override') && !name.startsWith('_Popup') &&
        !name.startsWith('_Dropdown') && !name.startsWith('_Switch') &&
        !name.startsWith('_Slider') && !name.startsWith('_Expansion') &&
        !name.startsWith('_ListTile') && !name.startsWith('_Chip') &&
        !name.startsWith('_Snack') && !name.startsWith('_Dialog') &&
        !name.startsWith('_Bottom') && !name.startsWith('_Navigation') &&
        !name.startsWith('_App') && !name.startsWith('_Root') &&
        !name.startsWith('_Lazy') && !name.startsWith('_Keep') &&
        !name.startsWith('_Sliver') && !name.startsWith('_Viewport') &&
        !name.startsWith('_Nested') && !name.startsWith('_Primary') &&
        !name.startsWith('_Fade') && !name.startsWith('_Zoom') &&
        !name.startsWith('_Cupertino') && !name.startsWith('_Hover') &&
        !name.startsWith('_Ink') && !name.startsWith('_Tooltip')) {
      hits.add(name);
      if (hits.length >= 2) break;
    }
  }
  return hits.isEmpty ? '?' : hits.join(' < ');
}

String _textOf(RenderParagraph p) {
  final t = p.text.toPlainText().replaceAll('\n', ' ');
  return t.length > 30 ? '${t.substring(0, 30)}…' : t;
}

/// overflow 오류 없이 조용히 잘리는 경우를 찾는다.
///  - clipped-text: Text 박스가 글자 전체 높이보다 작아 아래가 잘림
///  - truncated: maxLines 초과로 말줄임/절단
///  - inner-scroll: 화면 높이 60% 미만인 세로 스크롤 영역에 숨은 내용이 있음
///    (카드 안 SingleChildScrollView 등 — 사용자는 스크롤 가능함을 알기 어렵다)
void _scanSilentClipping(WidgetTester tester, void Function(_Finding) record) {
  final root = tester.binding.rootElement?.renderObject;
  if (root == null) return;
  final screenH = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  void visit(RenderObject ro) {
    if (ro is RenderParagraph && ro.hasSize && ro.attached) {
      final full = ro.getMaxIntrinsicHeight(ro.size.width);
      if (ro.size.height + 0.5 < full) {
        record(_Finding(
          'clipped-text',
          '"${_textOf(ro)}" box ${ro.size.height.toStringAsFixed(1)} < text ${full.toStringAsFixed(1)} (cut ${(full - ro.size.height).toStringAsFixed(1)}px)',
          _creatorHint(ro),
        ));
      } else if (ro.didExceedMaxLines) {
        record(_Finding('truncated', '"${_textOf(ro)}" exceeded maxLines',
            _creatorHint(ro)));
      }
    }
    ro.visitChildren(visit);
  }
  visit(root);
  // 세로 스크롤 영역(SingleChildScrollView 포함) 중 화면 75% 미만 높이에서 내용을 숨긴 것.
  for (final e in find.byType(Scrollable).evaluate()) {
    final st = (e as StatefulElement).state as ScrollableState;
    final pos = st.position;
    if (pos.axis != Axis.vertical || !pos.hasContentDimensions) continue;
    if (pos.maxScrollExtent > 0.5 && pos.viewportDimension < screenH * 0.75) {
      final ro = e.findRenderObject();
      record(_Finding(
        'inner-scroll',
        'viewport h=${pos.viewportDimension.toStringAsFixed(0)} hides ${pos.maxScrollExtent.toStringAsFixed(1)}px',
        ro == null ? '?' : _creatorHint(ro),
      ));
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadRealFont);

  setUp(() {
    TtsService().disableEngineForTest = true;
    TtsService().resetForTest();
    RunStatusService.instance.resetForTest();
    SpeechSessionService.instance.resetForTest();
    BleService.instance.setTestOverrides(
      connect: (_) async => true,
      scan: (_) async => const [],
    );
    BleService.instance.setSendRawOverride((_) async => true);
    BleService.instance.setPriorityStopOverride((_) async => 'OK');
  });

  tearDown(() {
    TtsService().disableEngineForTest = false;
    BleService.instance.clearTestOverrides();
    BleService.instance.setSendRawOverride(null);
    BleService.instance.setPriorityStopOverride(null);
    RunStatusService.instance.resetForTest();
    SpeechSessionService.instance.resetForTest();
  });

  tearDownAll(() {
    final b = StringBuffer();
    b.writeln('');
    b.writeln('================ SCREEN OVERFLOW SUMMARY ================');
    for (final s in _screens) {
      final per = _results[s.name];
      if (per == null) {
        b.writeln('[${s.name}] NOT RUN');
        continue;
      }
      for (final c in _configs) {
        final f = per[c.id];
        if (f == null) continue; // 해당 없음(예: 텍스트 필드 없는 화면의 kb)
        final status = f.isEmpty ? 'OK' : '${f.length} issue(s)';
        b.writeln('[${s.name}] ${c.id}: $status');
        for (final x in f) {
          b.writeln('    - $x');
        }
      }
    }
    if (_notes.isNotEmpty) {
      b.writeln('---- notes ----');
      _notes.forEach((k, v) => b.writeln('$k: $v'));
    }
    b.writeln('=========================================================');
    // ignore: avoid_print
    print(b.toString());
  });

  for (final s in _screens) {
    for (final c in _configs) {
      if (c.keyboard > 0 && !s.hasTextField) continue;
      testWidgets('overflow scan: ${s.name} @ ${c.id}', (tester) async {
        SharedPreferences.setMockInitialValues(Map.of(s.prefs));
        await AccessibilitySettings.instance.load();
        await ActiveDeviceService.instance.init();
        if (s.withActiveDevice) {
          await ActiveDeviceService.instance.setActiveDevice(
            deviceId: 'test-microwave',
            deviceName: '전자레인지',
            bleId: 'TEST-BLE-0001',
            bleName: '테스트 브리지',
          );
        }

        const dpr = 2.625; // Galaxy A31 급 밀도
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = c.size * dpr;
        tester.platformDispatcher.textScaleFactorTestValue = c.textScale;
        // 실기기처럼 상태바(24dp)·하단 내비게이션 바(48dp)를 시스템 패딩으로 준다.
        const bars = FakeViewPadding(top: 24 * dpr, bottom: 48 * dpr);
        tester.view.padding = bars;
        tester.view.viewPadding = bars;
        if (c.keyboard > 0) {
          tester.view.viewInsets =
              FakeViewPadding(bottom: c.keyboard * dpr);
          // 키보드가 올라오면 하단 패딩은 inset에 흡수된다.
          tester.view.padding = const FakeViewPadding(top: 24 * dpr);
        }
        _currentKey = '${s.name} @ ${c.id}';
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final findings = <_Finding>[];
        final seen = <String>{};
        void record(_Finding f) {
          if (seen.add('${f.message}|${f.location}')) findings.add(f);
        }

        final original = FlutterError.onError;
        FlutterError.onError = (d) => record(_toFinding(d));
        try {
          await tester.pumpWidget(
              MaterialApp(theme: _themeFor(c), home: s.builder()));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
          _scanSilentClipping(tester, record);
          if (s.afterPump != null) {
            await s.afterPump!(tester);
            await tester.pump(const Duration(milliseconds: 250));
            _scanSilentClipping(tester, record);
          }
          // 트리를 내려 타이머·애니메이션을 정리한다.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 30));
        } catch (e) {
          record(_Finding('error', 'pump threw: ${e.toString().split('\n').first}', '-'));
        } finally {
          FlutterError.onError = original;
        }
        Object? ex;
        while ((ex = tester.takeException()) != null) {
          record(_Finding('error', ex.toString().split('\n').first, '-'));
        }
        _results.putIfAbsent(s.name, () => {})[c.id] = findings;
      });
    }
  }
}
