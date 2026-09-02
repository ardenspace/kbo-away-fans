/// iOS 빌드 단계의 **URL 스킴 주입 스크립트**를 잰다 — 저장소 안에서 볼 수
/// 없는 자리를 텍스트 대조로라도 잡아 두는 시험이다.
///
/// 선례는 `cross_layer_seams_test.dart` 가 `firestore.rules` 를 Dart 에서 파싱해
/// Dart 상수와 맞춰 보는 자리다. 여기서는 `ios/Runner.xcodeproj/project.pbxproj`
/// 안에 문자열로 박혀 있는 셸 스크립트를 꺼내, 저장소의 `ios/Runner/Info.plist`
/// 와 **앞뒤가 맞는지** 본다.
///
/// ## 왜 필요한가
///
/// 이 스크립트는 구글 로그인 URL 스킴(리버스 클라이언트 ID)을 **산출물의**
/// Info.plist 에 넣는다. 그 값은 프로젝트 좌표라 저장소에 두지 않기로 했고
/// (`.wellbegun/decisions.md` 2026-09-02 [M]), 대신 설정 파일에서 읽어 빌드
/// 때만 주입한다. 그런데 저장소의 Info.plist 는 이제 **카카오 로그인 스킴 한
/// 칸을 이미 들고 있다** — 그래서 주입을 고정 인덱스 `CFBundleURLTypes:0` 에
/// 하면 그 칸과 자리를 다투고, 증분 빌드에서 무엇이 남는지가 PlistBuddy 의
/// 삽입 규칙에 달리게 된다(2026-09-03 [S] 결정이 배열 끝 추가로 고친 자리).
///
/// 되돌아간 상태의 증상은 **iOS 실기기에서 구글 또는 카카오 로그인이 앱으로
/// 돌아오지 못하는 것**이고, `flutter test`·`flutter analyze`·훅 4종은 전부
/// 초록불이다. 그 침묵을 이 파일이 깬다.
///
/// ## 이 시험이 재는 것과 못 재는 것
///
/// 잰다: 주입 단계가 있는가, 스킴의 **출처**가 설정 파일인가, 저장소의 Info.plist
/// 를 건드리지 않는가, 인덱스를 **배열 끝에서 찾는가**(고정 0 이 아닌가), 같은
/// 스킴을 증분 빌드에서 두 번 넣지 않는가, 그리고 그 판단의 전제 — 저장소의
/// Info.plist 가 이미 0번 칸을 쓰고 있다 — 가 지금도 참인가.
///
/// 못 잰다(텍스트 대조의 한계): PlistBuddy 가 실제로 그렇게 동작하는지, Xcode 가
/// 이 단계를 실제로 그 순서에 도는지, 최종 산출물의 plist 가 옳은지. 그 셋은
/// 실기기 빌드에서만 확인된다 — `.wellbegun/run.md` 의 사람 몫 체크리스트가
/// 맡는 자리이고, 이 파일은 **거기까지 가기 전에 되돌아간 코드**를 잡는다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// pbxproj 에 문자열로 박힌 빌드 단계 스크립트를 꺼내 이스케이프를 푼다.
String _injectionScript() {
  final project = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();

  final match = RegExp(
    r'name = "Firebase config[^"]*";[\s\S]{0,400}?shellScript = "((?:[^"\\]|\\.)*)";',
  ).firstMatch(project);

  expect(
    match,
    isNotNull,
    reason:
        '구글 URL 스킴을 주입하는 빌드 단계(name 이 "Firebase config" 로 시작)를 '
        'pbxproj 에서 찾지 못했다 — 단계가 사라졌거나 이름이 바뀌었다면 이 시험도 '
        '함께 고쳐야 한다',
  );

  return match!
      .group(1)!
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\"', '"')
      .replaceAll(r'\\', r'\');
}

void main() {
  late String script;

  setUpAll(() => script = _injectionScript());

  group('주입할 값의 출처', () {
    test('리버스 클라이언트 ID 를 설정 파일에서 읽는다 (저장소에 박아 두지 않는다)', () {
      expect(script.contains('Print :REVERSED_CLIENT_ID'), isTrue);
      expect(
        script.contains('GoogleService-Info.plist'),
        isTrue,
        reason: '값의 출처는 설정 파일 하나다 — 저장소에 좌표를 적어 두지 않기로 했다',
      );
    });

    test('값이 없으면 아무것도 하지 않는다 (설정 없는 클론이 빌드된다)', () {
      expect(
        script.contains(r'if [ -z "$REVERSED" ]'),
        isTrue,
        reason:
            '구글 제공자를 아직 켜지 않은 프로젝트에는 REVERSED_CLIENT_ID 가 없다 — '
            '거기서 멈추면 설정 없는 클론이 빌드되지 않는다',
      );
    });

    test('저장소의 Info.plist 가 아니라 산출물의 것을 고친다', () {
      expect(script.contains(r'INFO="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"'), isTrue);
      expect(
        script.contains(r'${SRCROOT}/Runner/Info.plist'),
        isFalse,
        reason: '저장소의 Info.plist 를 고치면 빌드가 프로젝트 좌표를 저장소에 남긴다',
      );
    });
  });

  group('넣는 자리 — 카카오 칸과 다투지 않는다', () {
    test('고정 인덱스 0 에 밀어 넣지 않는다', () {
      expect(
        script.contains('Add :CFBundleURLTypes:0'),
        isFalse,
        reason:
            '저장소의 Info.plist 가 이미 0번 칸(카카오 로그인 스킴)을 쓰고 있다 — '
            '0 에 넣으면 두 스킴이 자리를 다투고, 증분 빌드에서 무엇이 남는지가 '
            'PlistBuddy 의 삽입 규칙에 달린다. 그 증상은 iOS 실기기에서 구글 또는 '
            '카카오 로그인이 앱으로 돌아오지 못하는 모양으로만 나타난다',
      );
    });

    test('배열 끝을 훑어 빈 인덱스를 찾는다', () {
      expect(
        RegExp(
          r'while .*Print :CFBundleURLTypes:\$IDX[\s\S]*?IDX=\$\(\(IDX \+ 1\)\)',
        ).hasMatch(script),
        isTrue,
        reason: '끝을 찾는 훑기가 사라지면 인덱스가 다시 고정된다',
      );
      expect(
        script.contains(r'Add :CFBundleURLTypes:$IDX dict'),
        isTrue,
        reason: '훑어 찾은 인덱스를 실제로 써야 한다',
      );
    });

    test('증분 빌드에서 같은 스킴을 두 번 넣지 않는다', () {
      expect(
        RegExp(r'Print :CFBundleURLTypes[\s\S]*?grep -q "\$REVERSED"').hasMatch(script),
        isTrue,
        reason: '이미 들어 있는지 보지 않으면 증분 빌드마다 같은 스킴이 쌓인다',
      );
    });
  });

  test('전제: 저장소의 Info.plist 가 이미 첫 칸을 쓰고 있다', () {
    // 위 "고정 인덱스 0 을 쓰지 않는다"가 지키는 사실의 반대쪽이다. 카카오 칸이
    // 사라지면 그 판단의 근거도 사라지므로, 근거가 없어졌을 때 여기서 드러난다.
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final urlTypes = RegExp(
      r'<key>CFBundleURLTypes</key>\s*<array>([\s\S]*?)</array>\s*<key>',
    ).firstMatch(plist);

    expect(
      urlTypes,
      isNotNull,
      reason: '저장소의 Info.plist 에 CFBundleURLTypes 배열이 없다',
    );
    expect(
      urlTypes!.group(1)!.contains('<string>kakao-sign-in</string>'),
      isTrue,
      reason:
          '카카오 스킴이 첫 칸을 쓰고 있다는 것이 "구글 스킴을 끝에 붙인다"는 판단의 '
          '근거다 (`kakao_app_key_sync_test.dart` 가 그 칸의 값을 앱 키와 대조한다)',
    );
  });
}
