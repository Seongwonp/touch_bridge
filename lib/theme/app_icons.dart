import 'package:flutter/material.dart';

/// 저장된 아이콘 코드포인트를 const [IconData]로 되돌린다.
///
/// 기기 목록과 추천 킷은 아이콘을 코드포인트(int)로 SharedPreferences에
/// 저장한다. 이걸 읽을 때 `IconData(런타임 int)`로 되살리면 두 가지 문제가 있다.
///
/// 1. 릴리스 빌드의 아이콘 트리 셰이킹(`--tree-shake-icons`, 기본 활성)이
///    어떤 글리프가 실제로 쓰이는지 알 수 없다. 빌드가 막히거나, 빌드가
///    되더라도 폰트에서 글리프가 제거돼 아이콘이 빈 사각형으로 보인다.
/// 2. 저장값이 손상되면 폰트에 없는 코드포인트를 그려 tofu(□)가 표시된다.
///
/// 그래서 앱이 저장할 수 있는 아이콘만 const로 모아 두고, 코드포인트로
/// 되찾는다. 모르는 값이면 대체 아이콘을 쓴다.
///
/// 새 아이콘을 기기·킷에 쓰기 시작하면 반드시 [_knownIcons]에 추가할 것.
/// 빠뜨리면 저장은 되지만 다시 열었을 때 대체 아이콘으로 보인다.
const List<IconData> _knownIcons = <IconData>[
  // 기기 종류 (device_connect_screen, appliance_selection_screen,
  // photo_mapping_view_model, demo_seed에서 저장)
  Icons.microwave,
  Icons.microwave_rounded,
  Icons.local_laundry_service_rounded,
  Icons.wash_rounded,
  Icons.dry_cleaning_rounded,
  Icons.air_rounded,
  Icons.ac_unit_rounded,
  Icons.light_mode_rounded,
  Icons.tv_rounded,
  Icons.kitchen_rounded,
  Icons.settings_remote_rounded,
  Icons.devices_rounded,

  // 추천 킷 부품 (recommendation_service)
  Icons.settings_input_component_rounded,
  Icons.layers_rounded,
  Icons.radio_button_checked_rounded,
  Icons.toll_rounded,
  Icons.cable_rounded,
  Icons.touch_app_rounded,
  Icons.align_vertical_bottom_rounded,
  Icons.circle_outlined,
  Icons.square_rounded,
];

final Map<int, IconData> _byCodePoint = <int, IconData>{
  for (final icon in _knownIcons) icon.codePoint: icon,
};

/// 기기 목록에서 쓰는 대체 아이콘.
const IconData kFallbackDeviceIcon = Icons.devices_rounded;

/// 추천 킷 부품에서 쓰는 대체 아이콘.
const IconData kFallbackPartIcon = Icons.build_circle_rounded;

/// 저장된 [codePoint]에 해당하는 const 아이콘을 돌려준다.
///
/// 값이 없거나 등록되지 않은 코드포인트면 [fallback]을 쓴다.
IconData iconFromCodePoint(
  Object? codePoint, {
  IconData fallback = kFallbackDeviceIcon,
}) {
  if (codePoint is! int) return fallback;
  return _byCodePoint[codePoint] ?? fallback;
}
