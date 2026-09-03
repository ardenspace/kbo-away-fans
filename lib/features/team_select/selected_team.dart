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
///    그린다. **서버를 읽지 못한 구간(스냅샷 오류)도 여기 든다** — 이미 팀을
///    고른 사람을 통신 문제로 온보딩에 되돌려 세우지 않는다.
///  - 서버 문서가 없으면(= 온보딩 전) 캐시에 값이 남아 있어도 미선택이다.
///  - **서버의 답을 기다리는 중이고 캐시도 비어 있으면 "팀 없음"이 아니라
///    "모름"이다.** 기기를 바꿔 처음 로그인한 사람이 그 구간에 있다: 캐시
///    읽기는 몇 ms 만에 끝나고 첫 스냅샷은 네트워크 왕복이라, 캐시의 부재를
///    답으로 쓰면 이미 팀을 고른 사람이 첫 왕복 내내 온보딩을 본다. 그 구간은
///    대기 화면이고, 영영 답하지 않는 실행이 사람을 거기 가두지 않도록 상한을
///    두는 자리는 `lib/backend/user_data_firestore.dart` 의 `watchProfile`
///    이다(`kProfileServerConfirmGrace`). 반면 **서버를 읽지 못한 구간(스냅샷
///    오류)은 기다림이 아니다** — 더 물어볼 길이 없으므로 캐시가 비어 있으면
///    미선택으로 확정한다.
///
/// 캐시가 **낡지 않는 것**이 위 문장들의 전제다. 그래서 기기 저장에 적는
/// 자리를 [CachedTeamId] 하나로 모으고, 적는 순간 그 provider 의 상태도 함께
/// 옮긴다 — "기기 저장에는 값이 있는데 그것을 읽는 provider 는 없다고 말한다"는
/// 상태가 남으면, 스냅샷 오류가 캐시 값으로 바뀐다는 위 문장이 기기를 바꾼
/// 사람에게만 거짓이 된다.
///
/// **캐시는 계정에 매여 있다.** 저장하는 값이 소유 계정의 uid 를 함께 들고,
/// 읽을 때 지금 계정과 다르면 없는 것으로 본다. 그래서 같은 기기에서 다른
/// 계정으로 처음 로그인한 사람은 스냅샷을 기다리는 동안에도 앞사람의 팀으로
/// 홈에 들지 않는다 — "서버 문서가 없으면 미선택" 한 줄로는 그것을 막지
/// 못한다(그 판정은 **서버를 알게 된 뒤**에야 서고, 그 앞 구간을 그리는 것이
/// 바로 캐시다). 로그아웃 시점에 캐시를 지우는 길은 쓰지 않는다 — 로그아웃
/// UI 가 아직 없고, 앱이 강제 종료되는 갈래는 그 처리를 지나지 않아 같은
/// 빈틈이 그대로 남는다.
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

/// 캐시 값 안에서 소유 계정과 팀 id 를 가르는 글자.
///
/// 팀 로스터에는 이 글자가 없고 Firebase uid 에도 없다. 그래도 가르는 자리를
/// **마지막** 것으로 잡는 것은, 어떤 제공자가 uid 에 이 글자를 넣더라도 팀 id
/// 쪽이 잘못 읽히지 않게 하기 위해서다.
const String _cacheOwnerSeparator = '|';

/// 응원 팀 id 의 기기 캐시 (shared_preferences 래퍼).
///
/// 이 값은 원본이 아니다 — 서버 문서를 아직 읽지 못한 첫 프레임을 그리기 위한
/// 사본이고, 서버 값을 알게 되면 그것으로 덮인다.
///
/// **캐시는 계정에 매여 있다.** 한 키 안에 `{uid}|{teamId}` 를 적고, 읽을 때
/// 소유자가 지금 계정과 다르면 없는 것으로 본다. 계정마다 키를 따로 두지 않는
/// 것은 그러면 로그인한 계정 수만큼 키가 쌓이기 때문이고, 한 키를 덮어쓰면
/// 앞사람의 값이 저절로 사라진다.
class SelectedTeamStore {
  const SelectedTeamStore();

  /// [uid] 계정의 캐시된 팀 id. 없거나, 소유자가 다르거나, 로스터([kTeamIds])
  /// 밖 값이면 null.
  ///
  /// 소유자를 적지 않던 옛 판이 남긴 값(가르는 글자가 없는 값)도 null 이다 —
  /// 누구 것인지 알 수 없는 값은 없는 것으로 본다.
  Future<String?> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(kSelectedTeamPrefsKey);
    if (stored == null) return null;
    final cut = stored.lastIndexOf(_cacheOwnerSeparator);
    if (cut < 0 || stored.substring(0, cut) != uid) return null;
    final id = stored.substring(cut + 1);
    if (!kTeamIds.contains(id)) return null;
    return id;
  }

  /// [uid] 계정의 팀 id 를 캐시에 적는다. 로스터 밖 id 는 프로그래밍 오류.
  Future<void> write(String uid, String teamId) async {
    assert(kTeamIds.contains(teamId), '알 수 없는 teamId: $teamId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kSelectedTeamPrefsKey,
      '$uid$_cacheOwnerSeparator$teamId',
    );
  }
}

/// 캐시 주입 지점 (테스트에서 override 가능).
final selectedTeamStoreProvider = Provider<SelectedTeamStore>(
  (_) => const SelectedTeamStore(),
);

/// 캐시에 남아 있는 **지금 계정의** 팀 id — 서버 값을 모르는 동안의 첫
/// 프레임용.
///
/// 별도 provider 로 둔 것은 [SelectedTeamNotifier] 를 동기 [Notifier] 로 두기
/// 위해서다. 서버 값이 도착할 때마다 비동기 build 가 다시 도는 구조에서는 그
/// 사이가 로딩 상태로 보여, 이미 홈에 있던 사람의 화면이 스피너로 한 번
/// 깜빡인다.
///
/// 자동 재시도는 끈다 — 캐시 읽기 실패는 "선택 없음"과 같이 다루므로(아래
/// [SelectedTeamNotifier] 참조) 다시 시도할 이유가 없고, 위젯 테스트에 타이머만
/// 남긴다.
/// 세션을 아직 모르거나 로그아웃 상태면 읽을 계정이 없으므로 null 이다 — 그
/// 구간에서 루트 게이트는 어차피 대기 화면이나 로그인 화면에 있다.
final cachedTeamIdProvider =
    AsyncNotifierProvider<CachedTeamId, String?>(
  CachedTeamId.new,
  retry: (retryCount, error) => null,
);

/// 기기 캐시를 **읽는 자리이자 쓰는 자리**.
///
/// 둘을 한 자리에 둔 것은 읽는 쪽이 낡지 않게 하려는 것이다. 읽기만 하는
/// provider 로 두면 앱이 뜬 순간의 값에 묶여, 그 뒤에 기기 저장이 바뀌어도
/// "없다"고 계속 말한다 — 서버 값을 처음 받아 캐시에 적은 실행(= 기기를 바꾼
/// 사람)이 바로 그 자리에 걸린다.
class CachedTeamId extends AsyncNotifier<String?> {
  /// 마지막으로 **적어 낸** 값과 그 소유 계정.
  ///
  /// 소유 계정을 함께 들고 있는 것은 한 실행 안에서 계정이 바뀔 수 있기
  /// 때문이다(로그아웃한 뒤 다른 계정으로 로그인). 팀 id 만 기억하면 새 계정이
  /// 같은 팀을 고른 순간 "이미 적었다"로 판정되어 캐시의 소유자가 앞사람인 채
  /// 남는다.
  ({String uid, String teamId})? _written;

  @override
  Future<String?> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return null;
    final stored = await ref.watch(selectedTeamStoreProvider).read(user.uid);
    // 읽는 사이에 이 계정의 값을 적었으면 그것이 최신이다 — 늦게 끝난 읽기가
    // 방금 적은 값을 덮지 않게 한다.
    final written = _written;
    if (written != null && written.uid == user.uid) return written.teamId;
    return stored;
  }

  /// 기기 저장에 적고 **그 값을 상태에도 남긴다.** 같은 계정의 같은 값이면
  /// 적지 않는다.
  ///
  /// 실패는 그대로 던진다 — 무엇을 할지는 부르는 쪽이 정한다
  /// ([SelectedTeamNotifier._writeCache] 참조). 실패한 자리에서는 [_written] 을
  /// 옮기지 않으므로 다음 갱신이 다시 시도한다.
  Future<void> write(String uid, String teamId) async {
    final entry = (uid: uid, teamId: teamId);
    if (_written == entry) return;
    await ref.read(selectedTeamStoreProvider).write(uid, teamId);
    _written = entry;
    state = AsyncData(teamId);
  }
}

/// 현재 응원 팀 id — null 이면 미선택(온보딩 대상).
///
/// 루트 게이트(`lib/app.dart` 의 `_SignedInGate`)가 이 값으로 온보딩·홈·대기
/// 화면을 가른다. 여기가 오류가 되는 것은 **캐시 읽기가 실패했을 때**뿐이고,
/// 그때는 게이트가 온보딩으로 읽는다(아는 값이 하나도 없으므로).
///
/// **서버 스냅샷이 오류로 끝난 실행은 오류가 아니라 캐시 값이 된다.** 이미
/// 팀을 고른 사람을 통신 문제로 팀 선택에 되돌려 세우지 않는다 — 캐시를 남긴
/// 이유가 그것이고, 캐시가 계정에 매여 있어서 그 갈래에 남의 팀이 뜰 위험은
/// 없다. 그 문장이 참이려면 캐시가 **낡지 않아야** 하고, 그것을 지키는 자리가
/// [CachedTeamId] 다.
///
/// **값이 없는 상태(로딩)는 "팀이 없다"와 다르다.** 서버의 첫 답을 기다리는
/// 중이고 캐시도 비어 있으면 여기는 로딩이고, 게이트는 대기 화면에 머무른다.
final selectedTeamIdProvider =
    NotifierProvider<SelectedTeamNotifier, AsyncValue<String?>>(
  SelectedTeamNotifier.new,
);

/// 응원 팀 선택 상태 — 서버 문서를 원본으로 삼고 캐시를 그 뒤에 맞춘다.
class SelectedTeamNotifier extends Notifier<AsyncValue<String?>> {
  /// 이 실행이 사용자 문서를 **아는** 계정.
  ///
  /// 서버가 문서를 흘려 주었거나(스냅샷) 이 실행이 직접 만들었을 때 선다.
  /// 문서를 모르는 채 고른 선택은 이미 있는 원본을 덮지 않는다 — 아래
  /// [_writeProfile] 참조.
  String? _knownDocumentUid;

  /// 앞선 선택의 서버 쓰기 — 다음 선택은 그 뒤에 선다.
  ///
  /// 줄을 세우는 것은 통신이 느린 자리에서 두 선택이 뒤엉키기 때문이다. 두
  /// 선택이 나란히 달리면 둘 다 "문서를 모른다"로 판정해 둘 다 문서를 만들려
  /// 들고, 어느 쪽이 이겼는지를 서로 모르는 채 끝난다. 앞엣것이 끝나기를
  /// 기다리면 뒤엣것은 문서가 생겼다는 사실을 알고 수정 경로로 이어 간다.
  Future<void> _queue = Future<void>.value();

  @override
  AsyncValue<String?> build() {
    final profile = ref.watch(userProfileProvider);
    if (profile case AsyncData(:final value)) {
      if (value != null) _knownDocumentUid = value.uid;
      final teamId = value?.favoriteTeamId;
      // 서버를 알게 된 순간부터 캐시는 사본이다 — 다음 콜드 스타트의 첫
      // 프레임이 이 값으로 그려진다.
      _mirror(teamId);
      return AsyncData(teamId);
    }
    // 서버를 아직 모르는(또는 읽지 못한) 구간: 캐시가 화면을 그린다. 서버
    // 스냅샷의 오류가 여기서 캐시 값으로 바뀌는 자리이고, 그래서 게이트가
    // 받는 로딩·오류는 **캐시 쪽의 것**이다(로딩은 대기 화면, 오류는 온보딩).
    // 서버를 읽지 못한 사람을 온보딩으로 되돌리면 이미 팀을 고른 사람이 통신
    // 문제로 팀 선택을 다시 하게 되고, 그것이 캐시를 남긴 이유와 어긋난다.
    final cached = ref.watch(cachedTeamIdProvider);
    return switch (cached) {
      AsyncData(value: final teamId?) => AsyncData(teamId),
      // 캐시 읽기가 실패했다 = 아는 값이 하나도 없다. 게이트가 온보딩으로
      // 읽는 유일한 오류다.
      AsyncError() => cached,
      // 캐시가 비어 있다. 여기서 갈래가 둘로 나뉘고, 그 둘을 가르는 것은
      // **서버에 물어볼 길이 남아 있는가**다.
      AsyncData() => profile.hasError
          // 서버를 읽지 **못했다**. 스냅샷 스트림은 오류와 함께 끝나고 자동
          // 재시도도 없으므로 더 기다려도 답이 오지 않는다 — 아는 것(캐시,
          // 여기서는 빈 값)으로 갈래를 정한다. 캐시에 값이 있는 실행이 홈에
          // 머무르는 것과 같은 규칙이고, 다른 결과는 캐시가 비어 있어서다.
          ? const AsyncData<String?>(null)
          // 서버가 아직 답하지 않았을 뿐이다. 이것은 "팀이 없다"가 아니라
          // "아직 모른다"이고, 답이 아닌 것을 답으로 쓰면 기기를 바꿔
          // 로그인한 사람이 첫 왕복 내내 온보딩을 본다. 이 기다림의 상한은
          // `watchProfile` 이 든다.
          : const AsyncLoading<String?>(),
      _ => const AsyncLoading<String?>(),
    };
  }

  /// 팀을 고른다 — 화면은 그 자리에서 바뀌고, 원본(사용자 문서)이 뒤이어
  /// 갱신된다.
  ///
  /// 상태를 먼저 옮기는 것은 오프라인 때문이다: Firestore 쓰기의 Future 는
  /// 서버에 닿아야 끝나므로, 그것을 기다렸다가 화면을 바꾸면 통신이 나쁜
  /// 자리에서 선택이 먹히지 않는 것처럼 보인다. 서버 쓰기의 실패는 던져서
  /// 부르는 쪽이 안내하게 한다.
  ///
  /// **원본을 먼저 쓰고 사본을 뒤에 맞춘다.** 캐시를 앞에 두면 서버에 닿지
  /// 못한 팀이 기기 저장에 남아 다음 콜드 스타트의 첫 프레임이 서버에 없는
  /// 팀으로 칠해지고, 기기 저장이 던지는 실행에서는 사용자 문서가 아예
  /// 만들어지지 않는다(그 예외는 화면 쪽 `BackendError` 처리에도 걸리지 않아
  /// 안내 없이 샌다). 순서가 이 계층이 스스로 적어 둔 "서버가 원본, 기기
  /// 저장은 캐시"와 같아야 한다.
  Future<void> select(String teamId) async {
    assert(kTeamIds.contains(teamId), '알 수 없는 teamId: $teamId');
    state = AsyncData(teamId);
    final task = _queue.then(
      // 앞선 선택이 실패했더라도 줄은 이어진다 — 한 번의 통신 실패가 그
      // 뒤의 선택을 통째로 막아서는 안 된다.
      (_) => _store(teamId),
      onError: (Object _) => _store(teamId),
    );
    _queue = task.then((_) {}, onError: (Object _) {});
    await task;
  }

  /// 한 번의 선택을 원본과 사본에 남긴다 — 줄 안에서 도는 몸통.
  Future<void> _store(String teamId) async {
    if (await _writeProfile(teamId)) await _writeCache(teamId);
  }

  /// 선택을 사용자 문서에 남긴다 — 문서가 없으면 만들고, 있으면 고친다.
  ///
  /// 돌려주는 값은 **선택이 원본에 실제로 남았는가**다. false 는 "이미 있는
  /// 문서를 덮지 않고 물러섰다"는 뜻이고, 그때는 사본도 옮기지 않는다.
  Future<bool> _writeProfile(String teamId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      // 계정 없이 쓰는 경로가 없는 앱이라 여기 오는 것은 게이트를 지나지 않은
      // 실행뿐이다. 조용히 캐시에만 남기면 그 선택은 어느 계정의 것도 아니다.
      throw const BackendPermissionError(code: 'unauthenticated');
    }
    final store = ref.read(userDataStoreProvider);

    if (_knownDocumentUid != user.uid) {
      // 이 실행은 이 계정의 문서를 모른다 = 화면은 온보딩이었다. 문서 유무를
      // 따로 물어보지 않는 것은 `createProfile` 이 트랜잭션이라 그 판정을 이미
      // 안에서 하기 때문이다 — 앞에 읽기를 하나 더 두면 결과는 그대로인 채
      // 문서 읽기만 한 번 더 든다.
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
      if (created) {
        _knownDocumentUid = user.uid;
        return true;
      }
      // 만들지 못했다 = 이미 문서가 있다. 그런데 이 실행은 그것을 모른 채
      // 온보딩을 보여 주었으므로, 사람은 "처음 고르는 중"이라고 믿고 눌렀다.
      // 여기서 수정으로 이어 가면 그 사람은 자기가 팀을 **바꿨다는 것조차**
      // 모른 채 원본을 잃는다. 물러서고, 뒤이어 오는 스냅샷이 화면을
      // 바로잡게 둔다.
      return false;
    }

    await store.patchProfile(
      user.uid,
      UserProfilePatch(favoriteTeamId: teamId, profileThemeKey: teamId),
    );
    return true;
  }

  /// 캐시를 서버 값에 맞춘다.
  void _mirror(String? teamId) {
    if (teamId == null) return;
    // 기다리지 않는 것은 이 갱신이 화면을 막을 이유가 없어서다 — 캐시는 다음
    // 콜드 스타트의 첫 프레임에만 쓰인다.
    unawaited(_writeCache(teamId));
  }

  /// 캐시를 지금 계정의 것으로 적는다.
  ///
  /// 계정을 모르는 구간에서는 적지 않는다 — 소유자 없는 캐시는 다음 실행에서
  /// 누구의 것도 아니게 되어 어차피 읽히지 않는다.
  ///
  /// **실패를 밖으로 내보내지 않는다.** 이 값은 다음 콜드 스타트의 첫 프레임을
  /// 그리는 데만 쓰이므로, 적지 못한 결과는 그 한 프레임이 늦게 칠해지는
  /// 것뿐이다 — 원본은 이미 서버에 있다. 반면 이 실패를 던지면 이미 서버에
  /// 남은 선택이 실패한 것처럼 보이고, 화면 쪽 `BackendError` 처리에도 걸리지
  /// 않아 안내 없이 샌다.
  Future<void> _writeCache(String teamId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    try {
      await ref.read(cachedTeamIdProvider.notifier).write(user.uid, teamId);
    } on Object {
      // 위 문단 참조 — 사본을 적지 못한 것이 선택을 무르게 하지 않는다.
    }
  }
}
