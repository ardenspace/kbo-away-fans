/// 응원 팀 선택의 상태 계층 (step 2.2 → 2.4).
///
/// **원본은 Firestore 사용자 문서의 `favoriteTeamId` 다.** 기기의
/// shared_preferences 단일 키는 원본이 아니라 **첫 렌더용 캐시**로 남는다
/// (decisions.md 2026-09-01 [M]: 계정이 필수가 되면서 기기 저장이 원본일 이유가
/// 없어졌고, 캐시를 없애면 로그인 직후 첫 프레임에 팀 테마가 늦게 붙는다).
/// 값은 common.defs teamId 10종(`lib/content/content_ids.dart` 의 [kTeamIds])
/// 그대로이고, 미지·오염 값은 읽기 시 null 로 취급해 온보딩으로 복귀한다.
///
/// 두 자리의 관계는 한 방향이다.
///  - 서버 값을 아는 순간부터는 서버가 이긴다. 캐시가 다르면 캐시를 서버에
///    맞춘다(반대 방향은 없다).
///  - 서버를 아직 모르는 구간(콜드 스타트, 스냅샷 대기)에서만 캐시가 화면을
///    그린다.
///  - 서버 문서가 없으면(= 온보딩 전) 캐시에 값이 남아 있어도 미선택이다.
///    같은 기기에서 다른 계정으로 처음 로그인한 사람이 앞사람의 팀으로 홈에
///    들어가지 않게 하는 자리다.
///
/// 팀 선택이 사용자 문서를 만드는 자리이기도 하다 — 문서는 다섯 필수 필드를
/// 갖춰 한 번에 만들어지고(`docs/firestore-schema.md`), 그중 `favoriteTeamId`
/// 가 정해지는 시점이 곧 온보딩의 끝이다.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/auth.dart';
import '../../backend/errors.dart';
import '../../backend/user_data.dart';
import '../../content/content_ids.dart';

/// 선택한 응원 팀 id 가 저장되는 prefs 키.
const String kSelectedTeamPrefsKey = 'selected_team_id';

/// 응원 팀 id 의 기기 캐시 (shared_preferences 래퍼).
///
/// 이 값은 원본이 아니다 — 서버 문서를 아직 읽지 못한 첫 프레임을 그리기 위한
/// 사본이고, 서버 값을 알게 되면 그것으로 덮인다.
class SelectedTeamStore {
  const SelectedTeamStore();

  /// 캐시된 팀 id. 없거나 로스터([kTeamIds]) 밖 값이면 null.
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(kSelectedTeamPrefsKey);
    if (id == null || !kTeamIds.contains(id)) return null;
    return id;
  }

  /// 팀 id 를 캐시에 적는다. 로스터 밖 id 는 프로그래밍 오류.
  Future<void> write(String teamId) async {
    assert(kTeamIds.contains(teamId), '알 수 없는 teamId: $teamId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSelectedTeamPrefsKey, teamId);
  }
}

/// 캐시 주입 지점 (테스트에서 override 가능).
final selectedTeamStoreProvider = Provider<SelectedTeamStore>(
  (_) => const SelectedTeamStore(),
);

/// 캐시에 남아 있는 팀 id — 서버 값을 모르는 동안의 첫 프레임용.
///
/// 별도 provider 로 둔 것은 [SelectedTeamNotifier] 를 동기 [Notifier] 로 두기
/// 위해서다. 서버 값이 도착할 때마다 비동기 build 가 다시 도는 구조에서는 그
/// 사이가 로딩 상태로 보여, 이미 홈에 있던 사람의 화면이 스피너로 한 번
/// 깜빡인다.
///
/// 자동 재시도는 끈다 — 캐시 읽기 실패는 "선택 없음"과 같이 다루므로(아래
/// [SelectedTeamNotifier] 참조) 다시 시도할 이유가 없고, 위젯 테스트에 타이머만
/// 남긴다.
final cachedTeamIdProvider = FutureProvider<String?>(
  (ref) => ref.watch(selectedTeamStoreProvider).read(),
  retry: (retryCount, error) => null,
);

/// 현재 응원 팀 id — null 이면 미선택(온보딩 대상).
///
/// 루트 게이트(`lib/app.dart` 의 `_SignedInGate`)가 이 값 하나로 온보딩과 홈을
/// 가른다. 오류 상태는 종전대로 온보딩으로 읽힌다(잘못된 값으로 홈에 들어가지
/// 않게).
final selectedTeamIdProvider =
    NotifierProvider<SelectedTeamNotifier, AsyncValue<String?>>(
  SelectedTeamNotifier.new,
);

/// 응원 팀 선택 상태 — 서버 문서를 원본으로 삼고 캐시를 그 뒤에 맞춘다.
class SelectedTeamNotifier extends Notifier<AsyncValue<String?>> {
  /// 캐시에 마지막으로 적은 값 — 같은 값을 반복해서 쓰지 않으려고 들고 있다.
  String? _mirrored;

  @override
  AsyncValue<String?> build() {
    final profile = ref.watch(userProfileProvider);
    if (profile case AsyncData(:final value)) {
      final teamId = value?.favoriteTeamId;
      // 서버를 알게 된 순간부터 캐시는 사본이다 — 다음 콜드 스타트의 첫
      // 프레임이 이 값으로 그려진다.
      _mirror(teamId);
      return AsyncData(teamId);
    }
    // 서버를 아직 모르는 구간: 캐시가 첫 프레임을 그린다. 로딩·오류를 그대로
    // 흘려보내는 것은 게이트가 이미 그 둘을 어떻게 받을지 정해 두었기
    // 때문이다(로딩은 대기 화면, 오류는 온보딩).
    return ref.watch(cachedTeamIdProvider);
  }

  /// 팀을 고른다 — 화면은 그 자리에서 바뀌고, 원본(사용자 문서)이 뒤이어
  /// 갱신된다.
  ///
  /// 상태와 캐시를 먼저 옮기는 것은 오프라인 때문이다: Firestore 쓰기의 Future
  /// 는 서버에 닿아야 끝나므로, 그것을 기다렸다가 화면을 바꾸면 통신이 나쁜
  /// 자리에서 선택이 먹히지 않는 것처럼 보인다. 쓰기 실패는 던져서 부르는
  /// 쪽이 안내하게 한다.
  Future<void> select(String teamId) async {
    assert(kTeamIds.contains(teamId), '알 수 없는 teamId: $teamId');
    state = AsyncData(teamId);
    _mirrored = teamId;
    await ref.read(selectedTeamStoreProvider).write(teamId);
    await _writeProfile(teamId);
  }

  /// 선택을 사용자 문서에 남긴다 — 문서가 없으면 만들고, 있으면 고친다.
  Future<void> _writeProfile(String teamId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      // 계정 없이 쓰는 경로가 없는 앱이라 여기 오는 것은 게이트를 지나지 않은
      // 실행뿐이다. 조용히 캐시에만 남기면 그 선택은 어느 계정의 것도 아니다.
      throw const BackendPermissionError(code: 'unauthenticated');
    }
    final store = ref.read(userDataStoreProvider);
    // 스냅샷이 아직 오지 않았을 수 있다(온보딩 화면은 서버를 모르는 구간에도
    // 뜬다). 그때는 서버에 직접 물어 문서 유무를 판정한다 — 짐작으로
    // createProfile 을 부르면 이미 있는 문서를 덮을 뻔한 경로가 열린다.
    final known = ref.read(userProfileProvider);
    final profile = known is AsyncData<UserProfile?>
        ? known.value
        : await store.readProfile(user.uid);

    if (profile == null) {
      final created = await store.createProfile(
        user.uid,
        NewUserProfile(
          nickname: seedNickname(uid: user.uid, displayName: user.displayName),
          favoriteTeamId: teamId,
          // 프로필 색은 선택한 팀 색으로 함께 선다. 두 값을 따로 둔 것은
          // "색만 바꾸는" 경로(마이페이지)를 위해서지, 팀을 바꾼 사람의 색을
          // 옛 팀에 남겨 두려는 것이 아니다.
          profileThemeKey: teamId,
        ),
      );
      // 만들지 못했다는 것은 그 사이에 문서가 생겼다는 뜻이다 — 첫 문서가
      // 서기 전에 팀을 두 번 고르면 두 선택 모두 여기로 온다. 여기서 멈추면
      // 마지막 선택이 서버에 닿지 못한 채 사라지고, 뒤이어 오는 스냅샷이
      // 화면을 옛 팀으로 되돌린다.
      if (created) return;
    }
    await store.patchProfile(
      user.uid,
      UserProfilePatch(favoriteTeamId: teamId, profileThemeKey: teamId),
    );
  }

  /// 캐시를 서버 값에 맞춘다 (같은 값이면 쓰지 않는다).
  void _mirror(String? teamId) {
    if (teamId == null || teamId == _mirrored) return;
    _mirrored = teamId;
    // 기다리지 않는 것은 이 갱신이 화면을 막을 이유가 없어서다 — 캐시는 다음
    // 콜드 스타트의 첫 프레임에만 쓰인다.
    unawaited(ref.read(selectedTeamStoreProvider).write(teamId));
  }
}
