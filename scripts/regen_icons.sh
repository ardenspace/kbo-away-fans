#!/usr/bin/env bash
# 런처 아이콘 재생성. `dart run flutter_launcher_icons` 를 직접 돌리지 말고 이걸 쓴다.
#
# 직접 돌리면 안 되는 이유: flutter_launcher_icons 0.14.4 의 lib/ios.dart 는
# pbxproj 에서 'ASSETCATALOG' 가 들어간 모든 줄의 값을 아이콘 이름으로 치환한다.
# 그래서 ASSETCATALOG_COMPILER_APPICON_NAME 만 바꿔야 하는데
# ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES 까지
# = AppIcon 으로 덮어써서 iOS 빌드 설정이 망가진다. 이 스크립트는 생성 직후
# 그 줄들을 YES 로 되돌리고, 복원이 됐는지 검증까지 한다.
set -euo pipefail
cd "$(dirname "$0")/.."

dart run flutter_launcher_icons

pbxproj=ios/Runner.xcodeproj/project.pbxproj
sed -i '' \
  's/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon;/ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;/' \
  "$pbxproj"

if grep -q 'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = AppIcon' "$pbxproj"; then
  echo "오류: pbxproj 복원에 실패했다. diff 를 직접 확인할 것." >&2
  exit 1
fi

echo "완료: 아이콘 생성 + pbxproj 복원 검증 통과"
