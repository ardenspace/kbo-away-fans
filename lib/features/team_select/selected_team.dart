/// 응원 팀 선택의 상태 계층 (step 2.2 → 2.4).
///
/// **원본은 Firestore 사용자 문서의 `favoriteTeamId` 다.** 기기의
/// shared_preferences 단일 키는 원본이 아니라 **첫 렌더용 캐시**로 남는다
/// (decisions.md 2026-09-01 [M]: 계정이 필수가 되면서 기기 저장이 원본일 이유가
/// 없어졌고, 캐시를 없애면 로그인 직후 첫 프레임에 팀 테마가 늦게 붙는다).
/// 값은 common.defs teamId 10종(`lib/content/content_ids.dart` 의 [kTeamIds])
/// 그대로다.
///
/// **로스터 검사는 사본에만 건다.** 기기 저장에서 읽은 미지·오염 값은 null 로
/// 취급한다([SelectedTeamStore.read]) — 사본이 없는 것으로 보아도 원본이 곧
/// 답하므로 잃는 것이 첫 프레임의 테마 하나뿐이다. 반면 **서버가 준
/// `favoriteTeamId` 는 걸러 내지 않고 그대로 흘린다.** 값 공간을 강제하는 자리는
/// `firestore.rules` 의 `favoriteTeamId in teamIds()` 이고, 앱이 그 위에 검사를
/// 하나 더 얹으면 로스터가 어긋난 실행(콘솔 직접 수정, 앱보다 새로운 규칙·판)의
/// 사람이 온보딩으로 내려간다 — 거기서 고른 팀은 이미 있는 원본을 덮지 않고
/// 물러서는데 물러서기의 수렴이 읽어 오는 값도 같은 검사에 걸려 다시 온보딩이
/// 되므로, 나갈 길 없는 되돌이가 된다. 그래서 그 실행은 **테마 없는 홈**으로
/// 저하시킨다(`HomeScreen` 이 팀을 찾지 못한 갈래를 이미 견딘다) — 사람이 자기
/// 선택을 잃는 것보다 색이 빠지는 편이 작은 손해다. 사본에는 그 값을 옮기지
/// 않는다([SelectedTeamNotifier._mirror]).
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
///    대기 화면이다.
///  - **그 기다림에는 상한이 있고, 상한을 넘으면 기다림이 아니게 된다.**
///    상한을 두는 자리는 `lib/backend/user_data_firestore.dart` 의
///    `watchProfile` 이고(`kProfileServerConfirmGrace`), 그 안에 아무 답도
///    오지 않으면 "서버를 읽지 못했다"(오류)가 흐른다. 그래서 이 계층이 보는
///    **오류**의 출처는 셋인데(스냅샷 오류·상한을 넘긴 기다림·캐시 읽기 실패)
///    규칙은 하나다: 더 물어볼 길이 없으므로 아는 값으로 갈래를 정하고, 아는
///    값이 없으면 미선택으로 확정한다. 상한 뒤에 진짜 답이 오면 그때 서버가
///    다시 이긴다 — 상한은 갈래를 정하는 바닥이지 사람을 옛 판단에 가두는
///    자물쇠가 아니다.
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
/// 팀 선택이 사용자 문서를 만드는 자리이기도 하다 — 팀 없음도 계약 필드를
/// 갖춘 문서를 한 번에 만들고(`docs/firestore-schema.md`) 온보딩을 마친다.
///
/// **온보딩과 팀 변경은 같은 화면이지만 다른 갈래다.** 서버 문서를 아직 보지
/// 못한 채 온보딩에서 고른 팀은 이미 있는 원본을 덮지 않고 물러선다 — 그
/// 사람은 "처음 고르는 중"이라고 믿고 눌렀기 때문이다. 반면 "응원 팀 바꾸기"
/// 에서 고른 팀은 물러서지 않는다 — 그 사람은 바꾸려고 눌렀고, 물러서면 화면이
/// 잠깐 새 팀으로 바뀌었다가 옛 팀으로 돌아오는 것만 보게 된다. 둘을 가르는
/// 것은 화면이 아는 사실이라 [SelectedTeamNotifier.select] 의 `isChange` 로
/// 건너온다.
///
/// **그 판정은 선택이 줄에 설 때 정해지고 그 뒤로 바뀌지 않는다.** 서버 쓰기는
/// 줄을 서므로 한 선택이 판정되는 시점과 실행되는 시점 사이가 통신 왕복만큼
/// 벌어지는데, 그 사이에 도착한 스냅샷을 판단에 섞으면 온보딩이라고 믿고 누른
/// 둘째 탭이 수정 경로로 들어가 원본을 지운다. 그래서 "이 선택은 문서를 모르는
/// 채 골랐다"는 사실을 [SelectedTeamNotifier.select] 이 선택과 함께 태워
/// 보낸다 — 고른 계정을 태우는 것과 같은 결속이다.
///
/// **저장하지 못한 선택은 화면에서도 물러난다.** 서버 쓰기가 실패하면 화면은
/// 누르기 직전의 값으로 돌아가고(변경 모드는 원본이 아는 팀, 온보딩은 팀 없음)
/// 실패 안내가 함께 뜬다 — 되돌리지 않으면 사람은 그 세션 내내 저장되지 않은
/// 팀을 보다가 다음 콜드 스타트에서 옛 팀을 아무 설명 없이 다시 만난다.
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

/// 기기 캐시 읽기의 상한.
///
/// 기다림에 상한을 두는 까닭은 `kAppCheckActivationTimeout` 과 같다: 이
/// 기다림을 붙잡고 있는 것이 사람이 보는 화면(루트 게이트의 대기 화면)이라,
/// 끝나지 않는 읽기가 곧 앱을 다시 켜는 것 말고 나갈 길이 없는 상태가 된다.
/// 서버 쪽 기다림에는 `kProfileServerConfirmGrace` 가 이미 서 있고, 그 상한이
/// 지나 오류가 흘러도 캐시 쪽이 끝나지 않으면 게이트는 여전히 로딩을 그린다 —
/// 두 기다림 중 하나만 끝나서는 화면이 갈래를 정하지 못한다.
///
/// `shared_preferences` 의 플랫폼 채널이 멎는 일은 드물다. 상한을 두는 것은
/// 확률이 아니라 **빠져나갈 길이 없다는 성질** 때문이다.
const Duration kCachedTeamReadTimeout = Duration(seconds: 5);

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

  /// 빈 팀 자리도 계정에 귀속된 정상 프로필 캐시다.
  Future<void> writeNoTeam(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSelectedTeamPrefsKey, '$uid$_cacheOwnerSeparator');
  }

  Future<bool> hasNoTeamProfile(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(kSelectedTeamPrefsKey) ==
        '$uid$_cacheOwnerSeparator';
  }
}

/// 캐시 주입 지점 (테스트에서 override 가능).
final selectedTeamStoreProvider = Provider<SelectedTeamStore>(
  (_) => const SelectedTeamStore(),
);

final cachedNoTeamProfileProvider = FutureProvider<bool>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return false;
  return ref
      .watch(selectedTeamStoreProvider)
      .hasNoTeamProfile(user.uid)
      .timeout(kCachedTeamReadTimeout, onTimeout: () => false);
}, retry: (retryCount, error) => null);

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
final cachedTeamIdProvider = AsyncNotifierProvider<CachedTeamId, String?>(
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
  ({String uid, String? teamId})? _written;

  @override
  Future<String?> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return null;
    // 기다림에는 상한이 있다([kCachedTeamReadTimeout]) — 넘으면 "캐시에 값이
    // 없다"로 본다. 던지지 않는 것은 두 실패의 뜻이 다르기 때문이다: 읽기가
    // **던진** 실행은 이 기기에서 더 알아낼 것이 없다는 답이라 오류가 맞지만,
    // 상한을 넘긴 실행에서는 서버가 곧 답할 수 있고 그 답이 오면 화면은 그
    // 값으로 선다. 오류로 확정하면 서버의 답을 1초 앞둔 사람까지 온보딩으로
    // 내려간다.
    final stored = await ref
        .watch(selectedTeamStoreProvider)
        .read(user.uid)
        .timeout(kCachedTeamReadTimeout, onTimeout: () => null);
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
  Future<void> write(String uid, String? teamId) async {
    final entry = (uid: uid, teamId: teamId);
    if (_written == entry) return;
    final store = ref.read(selectedTeamStoreProvider);
    if (teamId == null) {
      await store.writeNoTeam(uid);
    } else {
      await store.write(uid, teamId);
    }
    _written = entry;
    state = AsyncData(teamId);
    ref.invalidate(cachedNoTeamProfileProvider);
  }
}

/// 온보딩에서 방금 새 사용자 문서가 만들어졌는가 — 위치 권한 설명(step 2.5)을
/// 띄울 유일한 신호.
///
/// **선다:** [SelectedTeamNotifier._writeProfile] 이 온보딩(`isChange` 가
/// false인) 화면에서 `createProfile` 로 문서를 **실제로 만들었을** 때만
/// ([SelectedTeamNotifier.mark] 호출 자리 참조). 그 밖의 어떤 갈래도 세우지
/// 않는다 — 서버에 남기지 못해 되돌아간 선택도, 이미 있는 문서를 보고 물러선
/// 선택도, 변경 모드의 패치도 서지 않는다. 셋 다 "이 사람이 방금 팀을 확정해
/// 새 계정을 만들었다"가 아니고, 그 사실이 아닌데 위치를 물으면 사람이
/// 고르지도 못한(또는 이미 갖고 있던) 팀에 대해 위치를 내주게 된다
/// (`.wellbegun/decisions.md` 2026-09-01 [M]).
///
/// **한 번 읽으면 꺼진다.** 소비하는 쪽
/// (`lib/features/onboarding/location_consent.dart`)이 신호를 본 즉시
/// [consume] 으로 끈다 — 이 provider 는 그 사실을 스스로 알 방법이 없다(같은
/// 세션에서 홈이 다시 그려질 때마다 신호가 남아 있으면 매번 다시 뜬다).
final onboardingJustOnboardedProvider =
    NotifierProvider<OnboardingJustOnboarded, bool>(
      OnboardingJustOnboarded.new,
    );

/// [onboardingJustOnboardedProvider] 의 몸통 — 세우는 자리는
/// [SelectedTeamNotifier] 하나, 끄는 자리는 소비하는 화면 하나로 좁혀 둔다.
class OnboardingJustOnboarded extends Notifier<bool> {
  @override
  bool build() => false;

  /// 온보딩에서 문서가 방금 만들어졌다.
  void mark() => state = true;

  /// 신호를 봤다 — 다시 세우지 않는 한 이 세션에서 다시 뜨지 않는다.
  void consume() => state = false;
}

/// 현재 응원 팀 id — null은 정상적인 팀 없음과 온보딩 전 모두 가능하다.
/// 온보딩 여부는 [selectedProfileExistsProvider]로 구분한다.
///
/// 루트 게이트(`lib/app.dart` 의 `_SignedInGate`)는 프로필 존재와 이 값의
/// 로딩·오류를 함께 본다. 여기가 오류가 되는 것은 **캐시 읽기가 실패했을 때**뿐이고,
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

/// 팀 유무와 별개인 프로필 완료 상태. 팀 없음도 홈으로 진입한다.
final selectedProfileExistsProvider = Provider<AsyncValue<bool>>((ref) {
  final selected = ref.watch(selectedTeamIdProvider);
  return selected.whenData(
    (_) => ref.read(selectedTeamIdProvider.notifier).hasProfile,
  );
});

/// 응원 팀 선택 상태 — 서버 문서를 원본으로 삼고 캐시를 그 뒤에 맞춘다.
class SelectedTeamNotifier extends Notifier<AsyncValue<String?>> {
  bool _hasProfile = false;
  bool get hasProfile => _hasProfile;

  // null → null인 선택도 온보딩 전 → 정상 프로필로 바뀔 수 있다.
  // 팀 값이 같아도 프로필 존재를 구독하는 게이트에는 변화를 전달한다.
  @override
  bool updateShouldNotify(
    AsyncValue<String?> previous,
    AsyncValue<String?> next,
  ) => true;

  /// 이 실행이 사용자 문서에 **직접 쓴** 계정 (만들었거나 고쳤거나).
  ///
  /// 이 하나가 이 계층이 문서에 관해 들고 다니는 유일한 상태다. 생애를 한자리에
  /// 적어 둔다 — 같은 자리를 세 번 고치게 만든 것이 "언제 서고 누가 읽는가"가
  /// 흩어져 있던 것이기 때문이다.
  ///
  ///  - **선다:** [_writeProfile] 이 `createProfile` 로 문서를 실제로 만들었을
  ///    때, 그리고 `patchProfile` 로 고쳤을 때. 그 둘뿐이다.
  ///  - **서지 않는다:** 스냅샷이 문서를 흘려 주었을 때도, 물러서다 원본을
  ///    발견했을 때도 서지 않는다. 둘 다 "이 실행이 썼다"가 아니다.
  ///  - **읽는다:** [_writeProfile] 한 곳에서만, 줄 안에서 실행될 때.
  ///
  /// 실행 시점에 읽어도 안전한 것은 **줄([_queue])만이 이 값을 옮기기**
  /// 때문이다 — 줄은 한 줄로 서 있으므로 두 선택 사이에 이 값이 바뀌는 일은
  /// 앞엣 선택이 실제로 쓴 경우뿐이고, 그때는 뒤엣 선택이 그 사실을 알아야
  /// 맞다(첫 문서가 생기기 전에 두 번 고른 사람의 마지막 선택이 남는 자리다).
  /// 스냅샷처럼 **바깥에서** 오는 사실을 여기 섞으면 그것이 줄에 서 있는
  /// 사이에 도착해 이미 내려진 판단을 뒤집는다 — 물러서기를 무너뜨린 것이
  /// 정확히 그 끼워 넣기였다. 바깥에서 오는 사실(스냅샷이 문서를 보여 주는가)은
  /// 필드로 기억하지 않고 [select] 이 **줄에 설 때** 한 번 읽어 그 선택에
  /// 태운다.
  String? _writtenDocumentUid;

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
      _hasProfile = value != null;
      final teamId = value?.favoriteTeamId;
      // 서버를 알게 된 순간부터 캐시는 사본이다 — 다음 콜드 스타트의 첫
      // 프레임이 이 값으로 그려진다.
      _mirror(value);
      return AsyncData(teamId);
    }
    // 서버를 아직 모르는(또는 읽지 못한) 구간: 캐시가 화면을 그린다. 서버
    // 스냅샷의 오류가 여기서 캐시 값으로 바뀌는 자리다 — 서버를 읽지 못한
    // 사람을 온보딩으로 되돌리면 이미 팀을 고른 사람이 통신 문제로 팀 선택을
    // 다시 하게 되고, 그것이 캐시를 남긴 이유와 어긋난다. 게이트가 받는
    // **오류**는 그래서 캐시 쪽의 것 하나뿐이다(→ 온보딩). 반면 **로딩**은
    // 둘에서 온다: 캐시를 아직 읽는 중이거나, 캐시가 비어 있어 서버의 첫
    // 답을 기다리는 중이거나.
    final cached = ref.watch(cachedTeamIdProvider);
    final noTeam = ref.watch(cachedNoTeamProfileProvider);
    _hasProfile = cached.value != null || noTeam.value == true;
    if (cached.hasValue && noTeam.value == true) {
      return const AsyncData(null);
    }
    return switch (cached) {
      AsyncData(value: final teamId?) => AsyncData(teamId),
      // 캐시 읽기가 실패했다 = 아는 값이 하나도 없다. 게이트가 온보딩으로
      // 읽는 유일한 오류다.
      AsyncError() => cached,
      // 캐시가 비어 있다. 여기서 갈래가 둘로 나뉘고, 그 둘을 가르는 것은
      // **서버에 물어볼 길이 남아 있는가**다.
      AsyncData() =>
        profile.hasError
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
  ///
  /// **고른 사람을 선택과 함께 줄에 태운다.** 실행 시점에 계정을 다시 읽으면,
  /// 줄에 서 있는 사이에 계정이 바뀐 실행에서 앞 계정의 선택이 새 계정의 첫
  /// 문서로 굳는다 — 그리고 "재로그인이 덮지 않는다"는 보장 때문에 새 계정은
  /// 그 잘못된 문서를 그대로 안고 간다. 캐시가 값에 소유 계정을 매다는 것
  /// ([CachedTeamId])과 같은 결속이고, 같은 까닭이다.
  ///
  /// [isChange] 는 이 선택이 **팀 변경**인지를 말한다(화면이 안다 —
  /// `TeamSelectScreen.isChange`). 변경 모드에서 고른 팀은 물러서지 않고 원본을
  /// 갱신한다: 사람이 "응원 팀 바꾸기"에서 고른 이상, 이미 있는 문서는 덮어야
  /// 할 대상이지 지켜야 할 대상이 아니다. 물러서기는 온보딩 갈래의 장치이고,
  /// 그것이 지키는 것은 "처음 고르는 중"이라고 믿은 사람의 옛 선택이다.
  ///
  /// **물러설지 말지는 이 자리에서 정해진다.** `isChange` 와 함께, 스냅샷이
  /// 지금 이 계정의 문서를 보여 주고 있는지(`documentSeen`)를 여기서 한 번 읽어
  /// 선택에 태운다. 실행 시점에 다시 읽으면 줄에 서 있는 사이에 도착한 늦은
  /// 스냅샷이 판단을 뒤집어, 온보딩이라고 믿고 누른 둘째 탭이 수정 경로로
  /// 들어가 원본을 지운다. 고른 사람([owner])을 태우는 것과 같은 결속이고 같은
  /// 까닭이다 — 선택은 **눌린 순간의 사정**으로 판정되어야 한다.
  ///
  /// **서버에 남기지 못한 선택은 화면에서도 물러난다.** 첫 줄에서 화면을 옮기는
  /// 것은 서버를 기다리지 않기 위해서지 실패를 감추기 위해서가 아니다. 실패를
  /// 이미 아는 자리에서 되돌리지 않으면 사람은 그 세션 내내 저장되지 않은 팀을
  /// 보다가 다음 콜드 스타트에서 옛 팀을 아무 설명 없이 다시 만난다. 되돌릴
  /// 값은 누르기 직전의 상태다 — 변경 모드에서는 원본이 아는 팀이고, 온보딩
  /// 에서는 "팀 없음"이다. 실패 안내(`TeamSelectScreen.saveFailureNotice`)와
  /// 짝이다.
  Future<void> select(String? teamId, {bool isChange = false}) async {
    assert(
      teamId == null || kTeamIds.contains(teamId),
      '알 수 없는 teamId: $teamId',
    );
    final owner = ref.read(authStateProvider).value;
    // 스냅샷이 지금 이 계정의 문서를 보여 주고 있는가 — 눌린 순간의 사정이다.
    final documentSeen =
        owner != null && ref.read(userProfileProvider).value?.uid == owner.uid;
    // 되돌릴 자리 — 아직 아무것도 바뀌지 않은 지금의 화면이다.
    final rollback = state;
    final rollbackHasProfile = _hasProfile;
    _hasProfile = true;
    state = AsyncData(teamId);
    final task = _queue.then(
      // 앞선 선택이 실패했더라도 줄은 이어진다 — 한 번의 통신 실패가 그
      // 뒤의 선택을 통째로 막아서는 안 된다.
      (_) => _store(teamId, owner, isChange, documentSeen),
      onError: (Object _) => _store(teamId, owner, isChange, documentSeen),
    );
    // 실패도 그대로 물려준다 — 앞 선택의 실패를 여기서 삼키면 위 `onError`
    // 갈래가 닿을 수 없는 코드가 되고, "앞이 실패해도 줄은 이어진다"는 문장을
    // 아무것도 지키지 않게 된다. 이 future 의 오류는 두 자리가 받는다: 바로
    // 아래 `await task`(부르는 쪽으로 던진다)와, 다음 선택의 `onError` 갈래.
    _queue = task;
    try {
      await task;
    } on Object {
      _rollbackFailedSelection(teamId, rollback, rollbackHasProfile);
      rethrow;
    }
  }

  /// 저장하지 못한 선택을 화면에서 물린다.
  ///
  /// **지금 화면이 그 선택일 때만 물린다.** 줄에 선 뒤 선택이 이미 화면을
  /// 옮겼으면 그것이 더 새로운 사실이고, 앞 선택의 실패로 그것을 지우면 성공한
  /// 선택이 실패한 선택 때문에 사라진다.
  ///
  /// 되돌릴 자리가 **로딩**이면 "팀 없음"으로 내린다 — 대기 화면으로 되돌리면
  /// 게이트가 스피너를 다시 그리고, 그 구간을 끝낼 기다림은 이미 지나갔다.
  void _rollbackFailedSelection(
    String? teamId,
    AsyncValue<String?> rollback,
    bool rollbackHasProfile,
  ) {
    if (state.value != teamId) return;
    _hasProfile = rollbackHasProfile;
    state = rollback.hasValue || rollback.hasError
        ? rollback
        : const AsyncData<String?>(null);
  }

  /// 한 번의 선택을 원본과 사본에 남긴다 — 줄 안에서 도는 몸통.
  ///
  /// [isChange] 와 [documentSeen] 은 이 선택이 **줄에 설 때** 정해진 사정이다
  /// ([select] 참조). 실행 시점에 다시 읽지 않는다.
  Future<void> _store(
    String? teamId,
    AuthUser? owner,
    bool isChange,
    bool documentSeen,
  ) async {
    if (owner == null) {
      // 계정 없이 쓰는 경로가 없는 앱이라 여기 오는 것은 게이트를 지나지 않은
      // 실행뿐이다. 조용히 캐시에만 남기면 그 선택은 어느 계정의 것도 아니다.
      throw const BackendPermissionError(code: 'unauthenticated');
    }
    if (await _writeProfile(teamId, owner, isChange, documentSeen)) {
      await _writeCache(teamId, owner.uid);
    }
  }

  /// 선택을 사용자 문서에 남긴다 — 문서가 없으면 만들고, 있으면 고친다.
  ///
  /// 돌려주는 값은 **선택이 원본에 실제로 남았는가**다. false 는 "이 선택을
  /// 원본에 남기지 않았다"는 뜻이고(계정이 바뀌었거나, 이미 있는 문서를 덮지
  /// 않고 물러섰거나), 그때는 사본도 옮기지 않는다.
  Future<bool> _writeProfile(
    String? teamId,
    AuthUser owner,
    bool isChange,
    bool documentSeen,
  ) async {
    if (ref.read(authStateProvider).value?.uid != owner.uid) {
      // 줄에 서 있는 사이에 계정이 바뀌었다. 이 선택은 지금 사람의 것이
      // 아니므로 버린다 — 고른 사람은 이미 떠났고, 그 선택을 지금 계정에
      // 남기면 새 계정의 첫 문서가 앞사람의 팀으로 굳는다. 안내하지 않는 것은
      // 실패가 아니어서다(들을 사람도 없다).
      return false;
    }
    final store = ref.read(userDataStoreProvider);

    if (!documentSeen && _writtenDocumentUid != owner.uid) {
      // 이 선택이 줄에 설 때 스냅샷은 이 계정의 문서를 보여 주지 않았고, 이
      // 실행이 직접 쓴 적도 없다. 문서 유무를 따로 물어보지 않는 것은
      // `createProfile` 이 트랜잭션이라 그 판정을 이미 안에서 하기 때문이다 —
      // 앞에 읽기를 하나 더 두면 결과는 그대로인 채 문서 읽기만 한 번 더 든다.
      final created = await store.createProfile(
        owner.uid,
        NewUserProfile(
          nickname: seedNickname(
            uid: owner.uid,
            displayName: owner.displayName,
          ),
          favoriteTeamId: teamId,
        ),
      );
      if (created) {
        _writtenDocumentUid = owner.uid;
        if (!isChange) {
          // 온보딩에서 방금 새 계정이 섰다 — 위치 권한 설명을 띄울 신호를
          // 켠다(step 2.5). 변경 모드에서 이 갈래에 이르는 것은 이 세션이
          // 스냅샷을 못 본 채 "응원 팀 바꾸기"를 눌러 문서가 없는 것처럼
          // 보인 드문 경우인데, 그 사람은 이미 계정이 있던 사람이라 위치를
          // 새로 물을 자리가 아니다.
          ref.read(onboardingJustOnboardedProvider.notifier).mark();
        }
        return true;
      }
      // 만들지 못했다 = 이미 문서가 있다.
      if (!isChange) {
        // 온보딩으로 뜬 화면에서 고른 선택이다. 이 선택이 줄에 설 때 스냅샷은
        // 문서를 보여 주지 않았으므로 게이트는 이 사람을 "팀이 없는 사람"으로
        // 다루었고, 사람은 "처음 고르는 중"이라고 믿고 눌렀다. 여기서 수정으로
        // 이어 가면 그 사람은 자기가 팀을 **바꿨다는 것조차** 모른 채 원본을
        // 잃는다. 물러서고, 그 자리에서 원본을 읽어 화면을 그 값으로
        // 수렴시킨다. 그 사이에 늦은 스냅샷이 도착해도 이 판정은 바뀌지
        // 않는다 — 줄에 서 있던 둘째·셋째 선택도 같은 사정을 태우고 있으므로
        // 함께 물러선다.
        await _convergeToServer(owner);
        return false;
      }
      // 변경 모드다 — 사람이 "응원 팀 바꾸기"에서 고른 선택이므로 이 문서는
      // 지켜야 할 옛 선택이 아니라 바꿔 달라고 요청받은 대상이다. 아래 수정
      // 경로로 그대로 이어 간다. 여기까지 오는 것은 이 세션이 스냅샷을 끝내
      // 보지 못한 실행(오류로 끝났거나 상한을 넘긴 실행)이고, 그 세션에서
      // 물러서면 사람은 고른 팀이 잠깐 떴다가 옛 팀으로 되돌아오는 것만 보고
      // 까닭을 듣지 못한다.
    }

    await store.patchProfile(
      owner.uid,
      UserProfilePatch(favoriteTeamId: teamId),
    );
    // 고쳤으니 이 실행이 이 문서에 썼다 — 변경 모드로 여기 온 실행에서는 이 한
    // 줄이 다음 선택을 곧바로 수정 경로로 보낸다(문서를 또 만들어 보지 않는다).
    _writtenDocumentUid = owner.uid;
    return true;
  }

  /// 물러선 자리에서 원본을 한 번 읽어 화면을 그 값으로 수렴시킨다.
  ///
  /// 스냅샷에 맡기지 않는 것은, **이 갈래에 뒤이어 오는 스냅샷이 없을 수
  /// 있기** 때문이다. 온보딩이 뜬 채 서버에 문서가 이미 있는 상태에 이르는
  /// 주된 길이 "캐시가 비어 있고 스냅샷이 오류로 끝났거나 상한을 넘긴 실행"
  /// 이고, 오류로 끝난 스트림은 자동 재시도도 없다. 물러서기만 하면 사람은 그
  /// 세션 내내 고른 팀의 홈을 보다가 다음 콜드 스타트에서 아무 설명 없이 옛
  /// 팀으로 돌아온다.
  ///
  /// **여기서 [_writtenDocumentUid] 를 세우지 않는다.** 세우면 줄에 서 있던 다음
  /// 선택이 수정 경로로 들어가 원본을 덮는다 — 사람은 여전히 온보딩을 보고
  /// 있었고, 두 번째 선택도 첫 번째와 똑같이 물러서야 한다. 그 대가는 두 번째
  /// 선택이 문서 읽기를 한 번 더 하는 것뿐이다. 이 자리에서 아무것도 세우지
  /// 않는 것만으로는 부족했다 — 그 사이에 도착한 스냅샷이 세우던 자리가 따로
  /// 있었고, 그래서 판정을 [select] 이 태우는 사정으로 옮겼다.
  ///
  /// 읽기 실패는 그대로 던진다 — 수렴시키지 못한 채 화면이 고른 팀에 남는
  /// 상태를 조용히 두면 사람은 자기 선택이 남았다고 믿는다. 화면 쪽
  /// `BackendError` 안내 경로가 그 던짐을 받는다
  /// (`team_select_screen.dart` 의 `_select`).
  Future<void> _convergeToServer(AuthUser owner) async {
    final profile = await ref
        .read(userDataStoreProvider)
        .readProfile(owner.uid);
    if (profile == null) {
      // 방금 "이미 있다"고 답한 문서가 읽을 때는 없다. 앱에 문서를 지우는
      // 경로가 없으니 실제로 오기 어려운 자리이지만, 수렴시킬 값이 없는 것은
      // 읽기 실패와 같으므로 같이 다룬다 — 화면이 고른 팀에 남은 채 조용히
      // 끝나지 않게 한다.
      throw const BackendUnknownError(code: 'profile-missing');
    }
    // 읽는 사이에 계정이 바뀌었으면 이 값은 지금 사람의 것이 아니다 — 그대로
    // 세우면 새 계정이 앞사람의 팀으로 홈에 들어간다(캐시까지 함께 옮겨진다).
    if (ref.read(authStateProvider).value?.uid != owner.uid) return;
    _hasProfile = true;
    state = AsyncData(profile.favoriteTeamId);
    final teamId = profile.favoriteTeamId;
    await _writeCache(teamId, owner.uid);
  }

  /// 캐시를 서버 값에 맞춘다 — 그 문서를 가진 계정의 것으로 적는다.
  ///
  /// **로스터 밖 값은 옮기지 않는다.** 사본을 읽는 쪽([SelectedTeamStore.read])이
  /// 그런 값을 거부하므로 적어 봐야 다음 콜드 스타트에 읽히지 않고, 적는 쪽이
  /// 스스로 적어 둔 "로스터 밖 id 는 프로그래밍 오류"도 거짓이 된다. 서버 값이
  /// 로스터 밖일 수 있다는 것은 이 계층이 인정하는 사실이다(파일 머리말) —
  /// 그 값을 화면에는 그대로 흘리되 사본에는 남기지 않는다.
  void _mirror(UserProfile? profile) {
    if (profile == null) return;
    final teamId = profile.favoriteTeamId;
    if (teamId != null && !kTeamIds.contains(teamId)) return;
    // 기다리지 않는 것은 이 갱신이 화면을 막을 이유가 없어서다 — 캐시는 다음
    // 콜드 스타트의 첫 프레임에만 쓰인다.
    unawaited(_writeCache(teamId, profile.uid));
  }

  /// 캐시를 [uid] 계정의 것으로 적는다.
  ///
  /// 소유 계정을 부르는 쪽이 건네는 것은, 이 값이 "누구의 선택인가"를 지금
  /// 로그인 상태가 아니라 그 선택이 난 자리에서 정해야 하기 때문이다.
  ///
  /// **실패를 밖으로 내보내지 않는다.** 이 값은 다음 콜드 스타트의 첫 프레임을
  /// 그리는 데만 쓰이므로, 적지 못한 결과는 그 한 프레임이 늦게 칠해지는
  /// 것뿐이다 — 원본은 이미 서버에 있다. 반면 이 실패를 던지면 이미 서버에
  /// 남은 선택이 실패한 것처럼 보이고, 화면 쪽 `BackendError` 처리에도 걸리지
  /// 않아 안내 없이 샌다.
  Future<void> _writeCache(String? teamId, String uid) async {
    try {
      await ref.read(cachedTeamIdProvider.notifier).write(uid, teamId);
    } on Object {
      // 위 문단 참조 — 사본을 적지 못한 것이 선택을 무르게 하지 않는다.
    }
  }
}
