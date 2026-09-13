/// 적대적 탐침 (step 2.4) — 선택 팀 상태 계층에서 **변이 주입이 살아남은**
/// 자리들을 잰다. 전부 그 줄을 지워도 `flutter test` 가 초록불이었던 곳이다.
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
///
/// 두 번째 무리는 **물러서기가 스스로 열어 둔 자리**들이다.
///  4) 물러서다 발견한 문서로 "이 계정의 문서를 안다"를 세우면 줄에 서 있던
///     두 번째 선택이 수정 경로로 들어가 원본을 덮는다 — 물러서기가 막으려던
///     바로 그 해악이다.
///  5) 물러선 자리의 수렴은 길이 둘로 보이지만 하나(캐시)는 실패할 수 있고,
///     그때 화면을 옮기는 것은 남은 한 줄뿐이다.
///  6) 수렴시킬 문서가 사라진 경우, 그리고 수렴하는 사이에 계정이 바뀐 경우.
///  7) 앞 선택이 실패해도 줄에 선 다음 선택이 이어지는가 — 그 갈래는 앞
///     선택의 실패를 삼키던 동안 **닿을 수 없는 코드**였다.
///  8) 물러선 첫 선택이 수렴 읽기에 들어가 있는 사이에 **늦은 스냅샷**이
///     도착하는 실행. 판정을 실행 시점의 공유 필드로 하면 그 스냅샷이 필드를
///     세워 줄에 서 있던 둘째 선택이 물러서기를 건너뛴다 — 4 가 막은 자리를
///     끼워 넣기로 다시 여는 갈래다.
///
/// 세 번째 무리는 기기 캐시를 읽고 쓰는 규칙이다: 로스터 밖 값 걸러내기(그
/// 검사가 **사본에만** 걸린다는 것까지 — 서버 값에 같은 검사를 얹으면 나갈 길
/// 없는 되돌이가 된다), 가르는 글자가 든 uid, 같은 값 재쓰기 방지, 그리고
/// 캐시 provider 가 **적어 낸 값**에 매단 소유 계정(기기 저장 쪽은 소유자로
/// 앞사람의 값을 막는데 같은 실행 안의 기억에는 그 방어가 빠져 있었다).
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
    expect(state.isLoading, isFalse, reason: '로딩으로 남으면 게이트가 끝나지 않는 대기 화면을 그린다');
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

    final pending = container
        .read(selectedTeamIdProvider.notifier)
        .select('kt');
    await pumpEventQueue();

    expect(
      container.read(selectedTeamIdProvider).value,
      'kt',
      reason:
          '서버가 답하기 전에도 화면은 고른 팀이어야 한다 — '
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

  test('물러선 뒤의 두 번째 선택도 물러선다', () async {
    // 물러서는 보증이 무너지는 자리다. 첫 선택이 물러서면서 "이 계정의 문서를
    // 안다"를 세워 버리면, 줄에 서 있던 **두 번째** 선택은 수정 경로로 들어가
    // 원본을 덮는다 — 물러서기가 막으려던 바로 그 해악이 한 번 더 누른 사람에게
    // 그대로 일어난다. 온보딩 갈래에서는 둘째·셋째 선택도 물러서야 한다.
    // ("문서를 만들었거나 고쳐서 안다"와 "물러서다가 발견해서 안다"는 다르다.)
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();
    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();
    expect(
      container.read(selectedTeamIdProvider).value,
      isNull,
      reason: '온보딩이다',
    );

    final notifier = container.read(selectedTeamIdProvider.notifier);
    final first = notifier.select('kt');
    final second = notifier.select('kia');
    await first;
    await second;
    await pumpEventQueue();

    expect(store.profileCreates, 0);
    expect(
      store.documents[uid]![UserFields.favoriteTeamId],
      'lg',
      reason: '줄에 서 있던 두 번째 선택이 원본을 덮었다',
    );
    expect(container.read(selectedTeamIdProvider).value, 'lg');
    expect(await const SelectedTeamStore().read(uid), 'lg');
  });

  test('수렴하는 사이에 온 늦은 스냅샷이 둘째 선택의 물러서기를 지우지 않는다', () async {
    // 위 시험의 실행에 **늦은 스냅샷 하나**를 끼운 자리다. 물러선 첫 선택이
    // 수렴 읽기(서버 왕복)에 들어가 있는 사이에 상한 뒤의 진짜 답이 도착하면,
    // 그 답을 받은 자리가 "이 계정의 문서를 안다"를 세워 버린다 — 그러면 줄에
    // 서 있던 둘째 선택은 물러서기를 건너뛰고 수정 경로로 들어가 원본을 덮는다.
    // 물러설지 말지는 **그 선택이 줄에 설 때의 사정**으로 정해져야 하고, 그
    // 사이에 일어난 일이 판단을 바꾸면 안 된다.
    final gated = _GatedReadStore();
    addTearDown(gated.dispose);
    gated.documents[uid] = _serverDocument('lg');
    gated.holdProfiles = true;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(gated),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedTeamIdProvider, (_, _) {});
    await pumpEventQueue();
    gated.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();
    expect(
      container.read(selectedTeamIdProvider).value,
      isNull,
      reason: '온보딩이다',
    );

    final notifier = container.read(selectedTeamIdProvider.notifier);
    final first = notifier.select('kt');
    final second = notifier.select('kia');
    // 첫 선택이 물러서서 수렴 읽기에 들어가 멈춰 있다.
    await pumpEventQueue();

    // 그 사이에 상한 뒤의 진짜 답이 도착한다 — 화면은 서버 팀으로 수렴한다.
    gated.releaseProfiles();
    await pumpEventQueue();
    expect(container.read(selectedTeamIdProvider).value, 'lg');

    // 이제 수렴 읽기가 끝나고 줄에 서 있던 둘째 선택이 실행된다.
    gated.readGate.complete();
    await first;
    await second;
    await pumpEventQueue();

    expect(gated.profileCreates, 0);
    expect(
      gated.documents[uid]![UserFields.favoriteTeamId],
      'lg',
      reason: '늦은 스냅샷이 끼어든 실행에서 둘째 선택이 원본을 덮었다',
    );
    expect(container.read(selectedTeamIdProvider).value, 'lg');
    expect(await const SelectedTeamStore().read(uid), 'lg');
  });

  test('같은 팀을 두 번 눌러도 원본은 그대로다', () async {
    // 위와 같은 자리인데 사람이 한 번 더 누른 모양이다 — "안 먹혔나" 싶어
    // 같은 카드를 다시 누르는 것이 온보딩에서 가장 흔하다.
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();
    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();

    final notifier = container.read(selectedTeamIdProvider.notifier);
    final first = notifier.select('kt');
    final second = notifier.select('kt');
    await first;
    await second;

    expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
  });

  test('캐시를 적지 못한 실행에서도 물러선 화면이 서버 값으로 수렴한다', () async {
    // 수렴시키는 길이 둘로 보이지만 하나는 캐시를 지나간다 — 기기 저장이
    // 던지는 실행에서는 `_convergeToServer` 가 상태를 직접 옮기는 한 줄만
    // 남는다. 그 줄을 지워도 초록불이었던 것은 대역의 캐시 쓰기가 언제나
    // 성공해서다.
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    final container = makeContainer(cache: const _UnwritableCacheStore());
    await pumpEventQueue();
    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();
    expect(container.read(selectedTeamIdProvider).value, isNull);

    await container.read(selectedTeamIdProvider.notifier).select('kt');
    await pumpEventQueue();

    expect(
      container.read(selectedTeamIdProvider).value,
      'lg',
      reason: '화면이 고른 팀에 남았다 — 사람은 자기 선택이 남았다고 믿는다',
    );
  });

  test('수렴시킬 문서가 사라진 실행은 조용히 끝나지 않는다', () async {
    // "이미 있다"고 답한 문서가 읽을 때는 없다. 실제로 오기 어려운 자리이지만,
    // 수렴시킬 값이 없는 것은 읽기 실패와 같으므로 같이 다룬다 — 조용히 끝나면
    // 화면이 고른 팀에 남은 채 사람은 아무것도 듣지 못한다.
    final vanishing = _VanishedDocumentStore();
    addTearDown(vanishing.dispose);
    vanishing.holdProfiles = true;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(vanishing),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedTeamIdProvider, (_, _) {});
    await pumpEventQueue();
    vanishing.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();

    await expectLater(
      container.read(selectedTeamIdProvider.notifier).select('kt'),
      throwsA(
        isA<BackendUnknownError>().having(
          (error) => error.code,
          'code',
          'profile-missing',
        ),
      ),
    );
  });

  test('수렴하는 사이에 계정이 바뀌면 그 값은 새 사람에게 붙지 않는다', () async {
    // 물러선 자리의 읽기도 서버 왕복이라 그 사이에 계정이 바뀔 수 있다.
    // 그때 읽어 온 값을 그대로 화면과 캐시에 세우면, 새 계정이 앞사람의 팀으로
    // 홈에 들어간다.
    final gated = _GatedReadStore();
    addTearDown(gated.dispose);
    gated.documents[uid] = _serverDocument('lg');
    gated.holdProfiles = true;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(gated),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedTeamIdProvider, (_, _) {});
    await pumpEventQueue();
    gated.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();

    final pending = container
        .read(selectedTeamIdProvider.notifier)
        .select('kt');
    await pumpEventQueue();

    await auth.signOut();
    await pumpEventQueue();
    final next = await auth.signIn(AuthProviderId.google);
    await pumpEventQueue();
    expect(next.uid, isNot(uid));

    gated.readGate.complete();
    await pending;
    await pumpEventQueue();

    expect(
      container.read(selectedTeamIdProvider).value,
      isNot('lg'),
      reason: '앞 계정의 팀이 새 계정의 화면에 섰다',
    );
    expect(await const SelectedTeamStore().read(next.uid), isNull);
  });

  test('앞 선택이 실패해도 줄에 선 다음 선택이 이어진다', () async {
    // 통신이 한 번 실패했다고 그 뒤의 선택까지 통째로 버려지면, 사람은 두 번째
    // 선택이 어디로 갔는지 알 길이 없다 — 실패 안내는 첫 선택 것 하나뿐이다.
    final failing = _FailFirstWriteStore();
    addTearDown(failing.dispose);
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(failing),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedTeamIdProvider, (_, _) {});
    await pumpEventQueue();

    final notifier = container.read(selectedTeamIdProvider.notifier);
    final first = notifier.select('lg');
    final second = notifier.select('kia');

    await expectLater(first, throwsA(isA<BackendNetworkError>()));
    await second;

    expect(
      failing.documents[uid]?[UserFields.favoriteTeamId],
      'kia',
      reason: '앞 선택의 실패가 뒤 선택까지 삼켰다',
    );
  });

  test('같은 계정의 같은 값은 기기 저장에 다시 적지 않는다', () async {
    // 선택이 캐시에 적고, 곧바로 돌아온 스냅샷이 같은 값을 한 번 더 적는
    // 모양이다. 기기 저장 쓰기는 플랫폼 채널 왕복이라 값이 같으면 하지 않는다.
    final cache = _CountingCacheStore();
    final container = makeContainer(cache: cache);
    await pumpEventQueue();

    await container.read(selectedTeamIdProvider.notifier).select('lg');
    await pumpEventQueue();

    expect(cache.writes, ['$uid|lg'], reason: '같은 값을 두 번 적었다');
  });

  test('앞 계정에 적어 둔 값이 새 계정의 첫 프레임을 칠하지 않는다', () async {
    // 캐시 provider 는 기기 저장에 **적어 낸 값**도 함께 들고 있다(늦게 끝난
    // 읽기가 방금 적은 값을 덮지 않게 하는 자리). 그 기억에 소유 계정이 붙어
    // 있지 않으면, 같은 실행에서 다른 계정으로 로그인한 사람이 스냅샷을
    // 기다리는 구간에 앞사람의 팀으로 홈에 든다 — 기기 저장 쪽은 소유자를
    // 적어 막고 있는데 기억 쪽에 구멍이 남는 모양이다.
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();

    await container.read(selectedTeamIdProvider.notifier).select('lotte');
    expect(container.read(cachedTeamIdProvider).value, 'lotte');

    await auth.signOut();
    await pumpEventQueue();
    final next = await auth.signIn(AuthProviderId.google);
    await pumpEventQueue();
    expect(next.uid, isNot(uid));

    expect(
      container.read(cachedTeamIdProvider).value,
      isNull,
      reason: '앞 계정에 적어 둔 값이 새 계정의 캐시로 읽혔다',
    );
  });

  group('기기 캐시의 값을 읽는 규칙', () {
    test('로스터 밖 팀 id 는 없는 것으로 본다', () async {
      // 파일 머리말이 "로스터 검사는 사본에만 건다 — 기기 저장에서 읽은
      // 미지·오염 값은 null 로 취급한다"고 적어 둔 자리다. 사본이 없는 것으로
      // 보아도 원본이 곧 답하므로 잃는 것은 첫 프레임의 테마 하나뿐이다.
      // 서버가 준 값에는 같은 검사를 걸지 않는다(아래 시험) — 두 자리를 함께
      // 보아야 이 검사의 범위가 사본이라는 것이 드러난다.
      SharedPreferences.setMockInitialValues({
        kSelectedTeamPrefsKey: '$uid|없는팀',
      });

      expect(await const SelectedTeamStore().read(uid), isNull);

      store.holdProfiles = true;
      final container = makeContainer();
      await pumpEventQueue();
      expect(container.read(cachedTeamIdProvider).value, isNull);
    });

    test('서버가 준 로스터 밖 팀 id 는 그대로 흐르고 사본에는 남지 않는다', () async {
      // 서버 값에는 로스터 검사를 걸지 않는다 — 값 공간을 강제하는 자리는
      // `firestore.rules` 의 `favoriteTeamId in teamIds()` 이고, 앱이 여기서
      // 한 번 더 걸러 null 로 만들면 앱보다 새로운 판이 고른 팀을 든 사람이
      // 온보딩으로 내려가고, 거기서 고른 팀이 원본을 덮는다(물러서기의 수렴도
      // 같은 값을 다시 걸러 온보딩으로 되돌리므로 나갈 길이 없다). 홈은
      // 로스터 밖 id 를 테마 없는 화면으로 견딘다.
      final cache = _RecordingCacheStore();
      store.documents[uid] = <String, Object?>{
        ..._serverDocument('lg'),
        UserFields.favoriteTeamId: 'yankees',
      };
      final container = makeContainer(cache: cache);
      await pumpEventQueue();

      final state = container.read(selectedTeamIdProvider);
      expect(state.hasError, isFalse);
      expect(
        state.value,
        'yankees',
        reason: '서버 값을 걸러 온보딩으로 내려보내면 그 사람은 나갈 길이 없다',
      );
      // 사본에는 옮기지 않는다 — 읽는 쪽([SelectedTeamStore.read])이 로스터
      // 밖 값을 거부하므로 적어 봐야 다음 콜드 스타트에 읽히지 않고, 적는
      // 자리의 assert("로스터 밖 id 는 프로그래밍 오류")도 거짓이 된다.
      expect(cache.writes, isEmpty, reason: '읽는 쪽이 거부할 값을 사본에 적었다');
    });

    test('가르는 글자가 든 uid 도 제 캐시를 읽는다', () async {
      // 팀 로스터에는 이 글자가 없지만 uid 에 없다는 보장은 우리 것이 아니다 —
      // 그래서 가르는 자리를 **마지막** 것으로 잡았다. 첫 것으로 잡으면 그런
      // 계정은 자기 캐시를 영영 읽지 못하고 콜드 스타트마다 첫 프레임을 잃는다.
      const weird = 'kakao|1234567890';
      SharedPreferences.setMockInitialValues({});
      await const SelectedTeamStore().write(weird, 'lg');

      expect(await const SelectedTeamStore().read(weird), 'lg');
      expect(await const SelectedTeamStore().read('kakao'), isNull);
    });
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

/// 기기 저장에 **적지 못하는** 캐시 — 읽기는 부모 구현 그대로다.
class _UnwritableCacheStore extends SelectedTeamStore {
  const _UnwritableCacheStore();

  @override
  Future<void> write(String uid, String teamId) async {
    throw StateError('기기 저장에 적을 수 없다');
  }
}

/// 기기 저장에 **실제로 넘어간 값**을 기록하는 캐시 — 부모의 assert 를 지나지
/// 않으므로 로스터 밖 값이 넘어오는지도 잴 수 있다.
class _RecordingCacheStore extends SelectedTeamStore {
  _RecordingCacheStore();

  final List<String> writes = [];

  @override
  Future<void> write(String uid, String teamId) async {
    writes.add('$uid|$teamId');
  }
}

/// 기기 저장 쓰기를 세는 캐시.
class _CountingCacheStore extends SelectedTeamStore {
  _CountingCacheStore();

  final List<String> writes = [];

  @override
  Future<void> write(String uid, String teamId) async {
    writes.add('$uid|$teamId');
    await super.write(uid, teamId);
  }
}

/// "이미 있다"고 답하지만 읽으면 없는 저장소 — 수렴시킬 값이 사라진 실행.
class _VanishedDocumentStore extends FakeUserDataStore {
  @override
  Future<bool> createProfile(String uid, NewUserProfile profile) async => false;
}

/// 사용자 문서 **읽기**가 늦게 끝나는 저장소 — 물러선 자리의 서버 왕복이
/// 끝나기 전에 계정이 바뀌는 실행의 대역이다.
class _GatedReadStore extends FakeUserDataStore {
  final Completer<void> readGate = Completer<void>();

  @override
  Future<UserProfile?> readProfile(String uid) async {
    await readGate.future;
    return super.readProfile(uid);
  }
}

/// 첫 쓰기만 실패하는 저장소 — 통신이 한 번 끊겼다 이어진 실행의 대역이다.
class _FailFirstWriteStore extends FakeUserDataStore {
  int _creates = 0;

  @override
  Future<bool> createProfile(String uid, NewUserProfile profile) async {
    _creates++;
    if (_creates == 1) throw const BackendNetworkError(code: 'unavailable');
    return super.createProfile(uid, profile);
  }
}
