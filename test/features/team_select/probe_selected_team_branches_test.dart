/// 적대적 탐침 (step 2.4) — 선택 팀 상태 계층에서 **변이 주입이 살아남은** 세
/// 자리를 잰다. 셋 다 그 줄을 지워도 `flutter test` 가 전부 초록불이었다.
///
///  1) **아는 값이 하나도 없는데 서버까지 읽지 못한 실행**이 어디로 가는가.
///     캐시가 비어 있고 스냅샷이 오류로 끝난 갈래인데, 그 조합을 지나는 시험이
///     하나도 없어서 `profile.hasError` 갈래를 대기 화면으로 바꿔도 초록불이었다
///     — 그 변이는 사람을 **끝나지 않는 스피너**에 가둔다. 캐시에 값이 있는
///     실행은 기존 시험이 잡지만, 기기를 바꿔 처음 로그인한 사람은 여기 든다.
///  2) **선택이 서버 왕복을 기다리지 않는다.** 상태를 먼저 옮기는 한 줄을
///     지워도 초록불이었다 — 대역의 서버 쓰기가 곧바로 끝나 순서가 드러나지
///     않기 때문이다. 실물에서 그 줄이 없으면 통신이 느린 자리에서 팀을 눌러도
///     화면이 그대로여서 선택이 먹히지 않은 것처럼 보인다.
///  3) **늦게 끝난 캐시 읽기가 방금 적은 값을 덮지 않는다.** 그 방어를 지워도
///     초록불이었다 — 대역의 기기 저장 읽기가 언제나 먼저 끝나기 때문이다.
///     읽기가 늦게 끝나면 캐시 provider 가 "없다"로 돌아가고, 그 자리는 곧
///     스냅샷 오류에 팀을 잃는 자리다(위 1 과 같은 갈래).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/features/team_select/selected_team.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/fake_backend.dart';

Map<String, Object?> _serverDocument(String teamId) => <String, Object?>{
      UserFields.nickname: '먼저있던닉',
      UserFields.favoriteTeamId: teamId,
      UserFields.profileThemeKey: teamId,
      UserFields.joinedAt: DateTime.utc(2026, 3, 1),
      UserFields.board: const <String, Object?>{},
    };

void main() {
  const uid = 'kakao:1234567890';
  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = FakeUserDataStore();
    auth = FakeAuthService(
      signedIn: const AuthUser(uid: uid, displayName: '카카오원정러'),
    );
    addTearDown(auth.dispose);
    addTearDown(store.dispose);
  });

  ProviderContainer makeContainer({SelectedTeamStore? cache}) {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
        if (cache != null) selectedTeamStoreProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedTeamIdProvider, (_, _) {});
    return container;
  }

  test('캐시가 비어 있는데 서버까지 읽지 못하면 대기 화면에 갇히지 않는다', () async {
    // 기기를 바꿔 처음 로그인한 사람의 스냅샷이 오류로 끝났다. 더 물어볼 길이
    // 없으므로 미선택으로 **확정**해야 한다 — 로딩으로 남기면 게이트가 영영
    // 스피너를 돌리고, 그 화면에서는 다시 로그인할 길조차 없다.
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();
    expect(container.read(selectedTeamIdProvider).isLoading, isTrue);

    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();

    final state = container.read(selectedTeamIdProvider);
    expect(
      state.isLoading,
      isFalse,
      reason: '로딩으로 남으면 게이트가 끝나지 않는 대기 화면을 그린다',
    );
    expect(state.hasValue, isTrue);
    expect(state.value, isNull, reason: '아는 값이 하나도 없으므로 온보딩이 맞다');
  });

  test('선택은 서버 쓰기를 기다리지 않고 화면을 먼저 넘긴다', () async {
    // 서버 쓰기를 붙잡아 둔 채 고른다 — 통신이 느린 자리의 대역이다.
    final slow = _SlowCreateStore();
    addTearDown(slow.dispose);
    slow.holdProfiles = true;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(slow),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedTeamIdProvider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(selectedTeamIdProvider).value, isNull);

    final pending = container.read(selectedTeamIdProvider.notifier).select('kt');
    await pumpEventQueue();

    expect(
      container.read(selectedTeamIdProvider).value,
      'kt',
      reason: '서버가 답하기 전에도 화면은 고른 팀이어야 한다 — '
          '아니면 통신이 느린 자리에서 선택이 먹히지 않은 것처럼 보인다',
    );
    expect(slow.gate.isCompleted, isFalse, reason: '서버 쓰기는 아직 끝나지 않았다');

    slow.gate.complete();
    await pending;
    expect(slow.documents[uid]![UserFields.favoriteTeamId], 'kt');
  });

  test('늦게 끝난 캐시 읽기가 방금 적은 값을 덮지 않는다', () async {
    // 기기 저장 읽기가 느린 실행이다. 읽기가 끝나기 전에 팀을 고르면 캐시에는
    // 그 값이 적히는데, 늦게 끝난 읽기가 "없다"를 그 위에 덮으면 캐시를 읽는
    // provider 가 낡은 채로 남는다 — 그 다음 스냅샷 오류 한 번에 팀이 사라진다.
    final cache = _SlowReadCacheStore();
    final container = makeContainer(cache: cache);
    store.holdProfiles = true;
    await pumpEventQueue();

    await container.read(selectedTeamIdProvider.notifier).select('nc');
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'nc');

    // 이제야 기기 저장 읽기가 끝난다 — 그 시점의 저장값은 시험이 심어 두지
    // 않았으므로 "없음"이다.
    cache.readGate.complete();
    await pumpEventQueue();

    expect(
      container.read(cachedTeamIdProvider).value,
      'nc',
      reason: '늦게 끝난 읽기가 방금 적은 값을 덮었다',
    );
  });
}

/// 첫 문서 만들기를 붙잡아 두는 대역 — 서버 왕복이 끝나지 않은 구간이다.
class _SlowCreateStore extends FakeUserDataStore {
  final Completer<void> gate = Completer<void>();

  @override
  Future<bool> createProfile(String uid, NewUserProfile profile) async {
    await gate.future;
    return super.createProfile(uid, profile);
  }
}

/// 기기 저장 **읽기**가 늦게 끝나는 캐시. 쓰기는 부모 구현 그대로다.
class _SlowReadCacheStore extends SelectedTeamStore {
  _SlowReadCacheStore();

  final Completer<void> readGate = Completer<void>();

  @override
  Future<String?> read(String uid) async {
    // 읽기가 **시작된 시점**의 값을 들고 늦게 끝난다 — 실제 기기 저장 읽기가
    // 그렇게 동작한다(그 사이의 쓰기는 이 읽기의 결과에 들어오지 않는다).
    final atStart = await super.read(uid);
    await readGate.future;
    return atStart;
  }
}
