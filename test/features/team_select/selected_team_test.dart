/// Step 2.4 boundary tests — 선택 팀의 원본이 Firestore 사용자 문서로 옮겨온
/// 뒤의 상태 계층.
///
/// 재는 갈래는 넷이다 (계획의 boundary test 가 괄호로 지정한 그대로).
///  1) 문서 최초 생성 1회 — 온보딩에서 팀을 고른 그 순간 문서가 만들어진다.
///  2) 재로그인 무변경 — 다시 로그인해도 가입 시각·배지 판이 그대로다.
///  3) 캐시 → 서버 수렴 — 서버를 모르는 첫 프레임은 캐시 값으로 그리고,
///     서버 값이 오면 그것으로 수렴한다.
///  4) 서버 값과 캐시 불일치 시 서버 우선 — 캐시는 원본이 아니다.
///
/// 여기에 **아는 값이 없는 구간**의 갈래 셋이 더 붙는다. 셋 다 기기를 바꿔
/// 처음 로그인한 사람(= 시작할 때 기기 저장이 비어 있는 실행)에서만 열리는
/// 자리라, 캐시를 심어 두는 시험만으로는 통째로 빠진다.
///  5) 캐시가 비어 있던 실행에서도 스냅샷 오류가 사람을 홈에 남겨 둔다 —
///     서버 값을 한 번 읽었으면 캐시가 이미 그 값이기 때문이다.
///  6) 서버를 모르고 캐시도 비었으면 "팀 없음"이 아니라 "모름"이다.
///  7) 그 구간에서 고른 팀은 이미 있는 원본을 덮지 않는다.
///
/// 마지막 무리는 **저장하지 못한 선택**이다: 서버에 남지 않은 팀은 화면에도
/// 남지 않아야 하고(변경 모드는 원본이 아는 팀으로, 온보딩은 팀 없음으로),
/// 그 되돌리기가 뒤이어 성공한 선택까지 지우지는 않아야 한다.
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

/// 서버에 이미 남아 있는 사용자 문서 — 가입 시각과 배지 판을 함께 들고 있어야
/// "재로그인이 덮지 않는다"를 잴 수 있다.
Map<String, Object?> _serverDocument(String teamId) => <String, Object?>{
      UserFields.nickname: '먼저있던닉',
      UserFields.favoriteTeamId: teamId,
      UserFields.profileThemeKey: teamId,
      UserFields.joinedAt: DateTime.utc(2026, 3, 1),
      UserFields.board: <String, Object?>{
        'jamsil_lg': BoardCell.forCount(count: 2).toData(),
      },
    };

void main() {
  const uid = 'kakao:1234567890';
  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUp(() {
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
    // 화면이 구독한 것과 같은 상태를 만든다 — 구독이 없으면 provider 는 읽는
    // 순간에야 서고, 그 사이 세션·스냅샷이 흐를 자리가 없다.
    container.listen(selectedTeamIdProvider, (_, _) {});
    return container;
  }

  Future<String?> settledTeamId(ProviderContainer container) async {
    await pumpEventQueue();
    return container.read(selectedTeamIdProvider).value;
  }

  /// 지금 계정이 읽어 낼 캐시 값.
  Future<String?> cachedTeamId() => const SelectedTeamStore().read(uid);

  /// 캐시에 팀을 심는다 — 실제 쓰기 경로를 그대로 쓰므로 저장 모양을 시험이
  /// 다시 적지 않는다. [owner] 를 주면 그 계정의 캐시가 된다.
  Future<void> seedCache(String teamId, {String? owner}) async {
    SharedPreferences.setMockInitialValues({});
    await const SelectedTeamStore().write(owner ?? uid, teamId);
  }

  test('첫 로그인: 팀을 고르면 사용자 문서가 한 번 만들어진다', () async {
    SharedPreferences.setMockInitialValues({});
    final container = makeContainer();

    // 문서가 없으니 온보딩 상태다 (선택 팀 없음).
    expect(await settledTeamId(container), isNull);

    await container.read(selectedTeamIdProvider.notifier).select('hanwha');

    expect(store.profileCreates, 1);
    final document = store.documents[uid]!;
    expect(document[UserFields.favoriteTeamId], 'hanwha');
    // 프로필 색이 선택한 팀 색으로 함께 선다.
    expect(document[UserFields.profileThemeKey], 'hanwha');
    expect(document[UserFields.nickname], '카카오원정러');
    expect(document[UserFields.joinedAt], kFakeServerNow);
    expect(document[UserFields.board], isEmpty);
    // 캐시도 따라간다 — 다음 콜드 스타트의 첫 프레임이 이 값으로 그려진다.
    expect(await cachedTeamId(), 'hanwha');
    expect(container.read(selectedTeamIdProvider).value, 'hanwha');
  });

  test('표시 이름이 없는 계정도 기본 닉네임으로 문서를 받는다', () async {
    // 카카오 닉네임 동의를 켜지 않은 사람 — functions/kakao.js 가 null 을 준다.
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService(signedIn: const AuthUser(uid: uid));
    addTearDown(auth.dispose);
    final container = makeContainer();
    await settledTeamId(container);

    await container.read(selectedTeamIdProvider.notifier).select('nc');

    final nickname = store.documents[uid]![UserFields.nickname]! as String;
    expect(nickname, seedNickname(uid: uid));
    expect(nickname.length, inInclusiveRange(kNicknameMinLength, kNicknameMaxLength));
  });

  test('재로그인은 문서를 덮지 않는다 — 가입 시각과 배지 판이 그대로다', () async {
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lg');
    final before = Map<String, Object?>.from(store.documents[uid]!);

    // 첫 로그인 세션.
    final first = makeContainer();
    expect(await settledTeamId(first), 'lg');
    first.dispose();

    // 다시 로그인한 세션.
    final second = makeContainer();
    expect(await settledTeamId(second), 'lg');

    expect(store.profileCreates, 0);
    expect(store.documents[uid], before);
  });

  test('캐시 → 서버 수렴: 첫 프레임은 캐시 값, 이후 서버 값', () async {
    await seedCache('lg');
    store.documents[uid] = _serverDocument('samsung');
    // 서버 스냅샷을 붙잡아 둔다 — 아직 서버 값을 모르는 구간.
    store.holdProfiles = true;
    final container = makeContainer();

    expect(await settledTeamId(container), 'lg');

    store.releaseProfiles();

    expect(await settledTeamId(container), 'samsung');
    // 캐시도 서버를 따라간다.
    expect(await cachedTeamId(), 'samsung');
  });

  test('서버 값과 캐시가 다르면 서버가 이긴다', () async {
    await seedCache('lg');
    store.documents[uid] = _serverDocument('kia');
    final container = makeContainer();

    expect(await settledTeamId(container), 'kia');
    expect(await cachedTeamId(), 'kia');
  });

  test('서버에 문서가 없으면 캐시가 있어도 온보딩이다', () async {
    // 같은 기기에서 다른 계정으로 처음 로그인한 경우 — 앞사람의 캐시가 남아
    // 있어도 이 계정의 원본은 없다.
    await seedCache('lg');
    final container = makeContainer();

    expect(await settledTeamId(container), isNull);
  });

  test('기기를 바꿔 로그인해도 선택 팀이 따라온다', () async {
    // 새 기기라 캐시가 비어 있다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lotte');
    final container = makeContainer();

    expect(await settledTeamId(container), 'lotte');
    expect(await cachedTeamId(), 'lotte');
  });

  test('팀을 바꾸면 서버 문서가 갱신되고 캐시도 따라간다', () async {
    await seedCache('lg');
    store.documents[uid] = _serverDocument('lg');
    final container = makeContainer();
    await settledTeamId(container);

    await container.read(selectedTeamIdProvider.notifier).select('doosan');

    final document = store.documents[uid]!;
    expect(document[UserFields.favoriteTeamId], 'doosan');
    expect(document[UserFields.profileThemeKey], 'doosan');
    expect(document[UserFields.updatedAt], kFakeServerNow);
    // 문서를 새로 만들지 않았다 — 가입 시각과 배지 판이 그대로다.
    expect(store.profileCreates, 0);
    expect(document[UserFields.joinedAt], DateTime.utc(2026, 3, 1));
    expect(document[UserFields.board], isNotEmpty);
    expect(await cachedTeamId(), 'doosan');
    expect(container.read(selectedTeamIdProvider).value, 'doosan');
  });

  test('서버 값을 아직 모르는 채로 고른 팀은 이미 있는 원본을 덮지 않는다', () async {
    // 기기를 바꿔 로그인한 사람이 스냅샷을 기다리는 구간이다. 그 구간에서
    // 온보딩이 뜨면(게이트의 상한을 넘긴 실행) 사람은 "처음 고르는 중"이라고
    // 믿고 팀을 누르는데, 서버에는 이미 그 사람이 고른 팀이 있다. 그 원본을
    // 이 선택으로 갈아 끼우면 사람은 자기가 팀을 **바꿨다는 것조차** 모른다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();

    await container.read(selectedTeamIdProvider.notifier).select('kt');

    expect(store.profileCreates, 0);
    final document = store.documents[uid]!;
    expect(
      document[UserFields.favoriteTeamId],
      'lg',
      reason: '문서를 모른 채 고른 선택이 원본을 덮었다',
    );
    expect(document[UserFields.profileThemeKey], 'lg');
    expect(document[UserFields.joinedAt], DateTime.utc(2026, 3, 1));
    // 고른 팀은 사본에도 남지 않는다 — 서버에 없는 팀이 다음 콜드 스타트의 첫
    // 프레임을 칠하면 같은 오해가 한 번 더 선다. 사본은 물러선 자리에서 읽어
    // 온 **원본의 값**으로 선다.
    expect(await cachedTeamId(), 'lg');
    // 물러선 자리에서 원본을 읽어 화면이 이미 그 값으로 수렴했다 — 이 갈래에는
    // 뒤이어 오는 스냅샷이 없을 수 있으므로 스냅샷에 맡기지 않는다.
    expect(container.read(selectedTeamIdProvider).value, 'lg');

    // 뒤이어 스냅샷이 오는 실행에서도 같은 값이다.
    store.releaseProfiles();
    expect(await settledTeamId(container), 'lg');
  });

  test('캐시가 비어 있던 실행도 스냅샷 오류에 온보딩으로 내려가지 않는다', () async {
    // 기기를 바꿔 처음 로그인한 실행이다 — 시작할 때 기기 저장이 비어 있다.
    // 서버 값을 한 번 읽고 나면 캐시에 그 값이 적히므로, 뒤이어 스냅샷이
    // 오류로 끝나도 그 사람은 홈에 남아야 한다. 캐시를 읽는 provider 가 시작
    // 시점의 값에 묶여 있으면 여기서 팀이 null 로 떨어진다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lg');
    final container = makeContainer();
    expect(await settledTeamId(container), 'lg');
    expect(await cachedTeamId(), 'lg');

    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();

    final state = container.read(selectedTeamIdProvider);
    expect(
      state.hasError,
      isFalse,
      reason: '오류로 읽히면 게이트가 이 사람을 온보딩으로 되돌린다',
    );
    expect(
      state.value,
      'lg',
      reason: '기기 저장에는 lg 가 적혀 있는데 그것을 읽는 provider 가 옛 값을 들고 있다',
    );
  });

  test('서버를 아직 모르고 캐시도 비었으면 "팀 없음"이 아니라 로딩이다', () async {
    // 기기를 바꿔 로그인한 사람의 첫 왕복 구간이다. 캐시 읽기는 몇 ms 만에
    // 끝나고 첫 스냅샷은 네트워크 왕복이라, 캐시의 부재를 답으로 쓰면 이미
    // 팀을 고른 사람이 그 구간 내내 온보딩을 본다. 모르는 것은 모른다고
    // 말해야 게이트가 대기 화면에 머무른다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lotte');
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();

    final waiting = container.read(selectedTeamIdProvider);
    expect(waiting.isLoading, isTrue);
    expect(waiting.hasValue, isFalse, reason: '"팀 없음"으로 확정되면 온보딩이 뜬다');

    store.releaseProfiles();

    expect(await settledTeamId(container), 'lotte');
  });

  test('서버 쓰기가 실패한 실행은 캐시에 새 팀을 남기지 않는다', () async {
    // 순서가 "사본 → 원본"으로 뒤집히면 서버에 닿지 못한 팀이 기기 저장에
    // 남고, 다음 콜드 스타트의 첫 프레임이 서버에 없는 팀으로 칠해진다.
    await seedCache('lg');
    store.documents[uid] = _serverDocument('lg');
    final container = makeContainer();
    expect(await settledTeamId(container), 'lg');

    store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
    await expectLater(
      container.read(selectedTeamIdProvider.notifier).select('doosan'),
      throwsA(isA<BackendNetworkError>()),
    );

    expect(
      await cachedTeamId(),
      'lg',
      reason: '서버에 닿지 못한 선택이 사본에 남았다 — 원본보다 사본을 먼저 적었다',
    );
  });

  test('같은 실행에서 계정이 바뀌면 같은 팀을 골라도 캐시 소유자가 바뀐다', () async {
    // 앞사람 A 가 lotte 를 캐시에 남긴 채 로그아웃하고, B 가 같은 실행에서
    // 같은 팀을 고른 경우다. 캐시에 마지막으로 적은 값을 팀 id 로만 기억하면
    // "이미 적었다"로 판정해 건너뛰고, 캐시의 소유자가 A 인 채 남는다.
    SharedPreferences.setMockInitialValues({});
    final container = makeContainer();
    await settledTeamId(container);

    await container.read(selectedTeamIdProvider.notifier).select('lotte');
    expect(await const SelectedTeamStore().read(uid), 'lotte');

    await auth.signOut();
    await pumpEventQueue();
    final second = await auth.signIn(AuthProviderId.kakao);
    await pumpEventQueue();
    expect(second.uid, isNot(uid));

    await container.read(selectedTeamIdProvider.notifier).select('lotte');

    expect(
      await const SelectedTeamStore().read(second.uid),
      'lotte',
      reason: '캐시의 소유자가 앞 계정인 채 남았다',
    );
    expect(await const SelectedTeamStore().read(uid), isNull);
  });

  test('첫 문서가 생기기 전에 두 번 고르면 마지막 선택이 서버에 남는다', () async {
    // 앞 선택의 서버 쓰기가 아직 끝나기 전에 한 번 더 고른 경우다 — 통신이
    // 느린 자리에서 실제로 일어나는 모양이고(`select` 가 서버를 기다리지 않고
    // 화면을 먼저 넘기는 까닭이 그것이다), 두 선택 모두 "문서 없음"으로
    // 판정되어 createProfile 로 간다. 두 번째 호출이 조용히 아무것도 하지
    // 않으면 서버에는 첫 팀이 남고, 뒤이어 오는 스냅샷이 화면을 옛 팀으로
    // 되돌린다 — 오류는 어디에도 뜨지 않는다.
    SharedPreferences.setMockInitialValues({});
    store.holdProfiles = true;
    final container = makeContainer();
    expect(await settledTeamId(container), isNull);

    final notifier = container.read(selectedTeamIdProvider.notifier);
    final first = notifier.select('lg');
    final second = notifier.select('kia');
    await first;
    await second;

    final document = store.documents[uid]!;
    expect(document[UserFields.favoriteTeamId], 'kia');
    expect(document[UserFields.profileThemeKey], 'kia');
    // 문서는 여전히 한 번만 만들어졌다 — 가입 시각이 두 번 서지 않는다.
    expect(store.profileCreates, 1);

    // 스냅샷이 와도 화면이 옛 팀으로 되돌아가지 않는다.
    store.releaseProfiles();
    expect(await settledTeamId(container), 'kia');
    expect(await cachedTeamId(), 'kia');
  });

  test('서버 스냅샷이 오류로 끝나도 캐시 값으로 홈에 머무른다', () async {
    // 결정: 서버를 읽지 못한 사람을 온보딩으로 되돌리지 않는다. 이미 팀을 고른
    // 사람이 통신 문제로 팀 선택을 다시 하게 되고, 그것이 캐시를 남긴 이유와
    // 정면으로 어긋나기 때문이다. 캐시가 계정에 매여 있으므로(위 시험) 이
    // 갈래에서 남의 팀이 뜰 위험은 없다.
    await seedCache('lg');
    store.holdProfiles = true;
    final container = makeContainer();
    expect(await settledTeamId(container), 'lg');

    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();

    final state = container.read(selectedTeamIdProvider);
    expect(
      state.hasError,
      isFalse,
      reason: '오류로 읽히면 게이트가 이 사람을 온보딩으로 되돌린다',
    );
    expect(state.value, 'lg');
  });

  test('앞사람의 캐시는 새 계정의 스냅샷 대기 구간에도 붙지 않는다', () async {
    // 같은 기기를 넘겨받은 새 계정 — 서버에는 이 계정의 문서가 없고, 캐시에는
    // 앞사람의 팀이 남아 있다. "서버 문서가 없으면 미선택" 한 줄은 **서버를
    // 알게 된 뒤**에야 서므로, 그 앞 구간(스냅샷 대기)을 그리는 캐시가 계정에
    // 매여 있지 않으면 새 계정이 앞사람 팀으로 홈에 들어간다.
    await seedCache('lotte', owner: 'kakao:9999999999');
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();

    expect(container.read(selectedTeamIdProvider).value, isNot('lotte'));

    store.releaseProfiles();

    expect(await settledTeamId(container), isNull);
  });

  test('소유자를 적지 않은 옛 판의 캐시는 읽지 않는다', () async {
    // 앱을 올리기 전 판이 남긴 값 — 누구 것인지 알 수 없으므로 없는 것으로
    // 본다 (앞사람의 팀일 수 있다).
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lotte'});
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();

    expect(container.read(selectedTeamIdProvider).value, isNot('lotte'));

    store.releaseProfiles();

    expect(await settledTeamId(container), isNull);
  });

  test('캐시 쓰기가 실패해도 선택은 서버에 남고 예외가 새지 않는다', () async {
    // 기기 저장이 던지는 실행 — 원본은 서버이므로 그것이 먼저 서야 하고,
    // 사본을 적지 못한 것이 선택 자체를 무르게 만들어서는 안 된다. 화면 쪽
    // `TeamSelectScreen._select` 는 `BackendError` 만 잡으므로, 여기서 다른
    // 예외가 새면 안내도 없이 그대로 터진다.
    SharedPreferences.setMockInitialValues({});
    final container = makeContainer(cache: const _FailingCacheStore());
    expect(await settledTeamId(container), isNull);

    await container.read(selectedTeamIdProvider.notifier).select('lg');

    expect(store.profileCreates, 1);
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
    expect(container.read(selectedTeamIdProvider).value, 'lg');
  });

  test('줄에 선 선택은 그 사이에 바뀐 계정의 문서에 실리지 않는다', () async {
    // 앞선 선택의 서버 쓰기가 끝나기 전에 한 번 더 고르면 뒤엣것은 줄에 선다.
    // 그 사이에 계정이 바뀌면(로그아웃 → 다른 계정 로그인) 줄에 선 선택이
    // 실행될 때의 계정은 **고른 사람이 아니다.** 그것을 그대로 쓰면 새 계정의
    // 첫 문서가 앞사람의 선택으로 만들어지고, "재로그인이 덮지 않는다"는
    // 보장 때문에 새 계정은 그 잘못된 문서를 그대로 안고 간다.
    SharedPreferences.setMockInitialValues({});
    final slow = _GatedCreateStore();
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

    final notifier = container.read(selectedTeamIdProvider.notifier);
    final first = notifier.select('lg');
    final second = notifier.select('kia');
    await pumpEventQueue();

    await auth.signOut();
    await pumpEventQueue();
    final next = await auth.signIn(AuthProviderId.google);
    await pumpEventQueue();
    expect(next.uid, isNot(uid));

    slow.gate.complete();
    await first;
    await second;
    await pumpEventQueue();

    expect(slow.documents[uid]![UserFields.favoriteTeamId], 'lg');
    expect(
      slow.documents[next.uid],
      isNull,
      reason: '앞 계정의 선택이 새 계정의 첫 문서를 만들었다',
    );
    expect(slow.profileCreates, 1);
    expect(await const SelectedTeamStore().read(next.uid), isNull);
    expect(
      container.read(selectedTeamIdProvider).value,
      isNot('kia'),
      reason: '새 계정의 화면에 앞 계정의 선택이 남았다',
    );
  });

  test('물러선 선택은 서버 값을 읽어 화면을 그 값으로 수렴시킨다', () async {
    // 온보딩이 뜬 채 서버에 문서가 이미 있는 상태에 이르는 주된 길은 "캐시가
    // 비어 있고 스냅샷이 오류로 끝난 실행"이고, 그 갈래에는 **뒤이어 오는
    // 스냅샷이 없다.** 물러서기만 하고 아무 일도 하지 않으면 사람은 그 세션
    // 내내 고른 팀의 홈을 보다가 다음 콜드 스타트에서 아무 설명 없이 옛 팀으로
    // 돌아온다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    final container = makeContainer();
    await pumpEventQueue();

    store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();
    expect(container.read(selectedTeamIdProvider).value, isNull, reason: '온보딩이다');

    await container.read(selectedTeamIdProvider.notifier).select('kt');
    await pumpEventQueue();

    expect(store.profileCreates, 0);
    expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
    expect(
      container.read(selectedTeamIdProvider).value,
      'lg',
      reason: '물러선 자리에서 아무 일도 일어나지 않아 화면이 고른 팀에 남았다',
    );
    // 사본도 그 서버 값으로 선다 — 다음 콜드 스타트의 첫 프레임이 원본과
    // 같은 팀으로 그려진다.
    expect(await cachedTeamId(), 'lg');
  });

  test('수렴시킬 값을 읽지도 못하면 선택은 오류로 드러난다', () async {
    // 물러섰는데 서버 읽기까지 실패하면 화면은 고른 팀에 남는다. 그 상태를
    // 조용히 두면 사람은 자기 선택이 남았다고 믿는다 — 화면 쪽 `BackendError`
    // 안내 경로에 걸리도록 던진다.
    SharedPreferences.setMockInitialValues({});
    final unreadable = _UnreadableProfileStore();
    addTearDown(unreadable.dispose);
    unreadable.documents[uid] = _serverDocument('lg');
    unreadable.holdProfiles = true;
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(unreadable),
      ],
    );
    addTearDown(container.dispose);
    container.listen(selectedTeamIdProvider, (_, _) {});
    await pumpEventQueue();
    unreadable.emitProfileError(const BackendNetworkError(code: 'unavailable'));
    await pumpEventQueue();

    await expectLater(
      container.read(selectedTeamIdProvider.notifier).select('kt'),
      throwsA(isA<BackendError>()),
    );

    expect(unreadable.profileCreates, 0);
    expect(unreadable.documents[uid]![UserFields.favoriteTeamId], 'lg');
    expect(await cachedTeamId(), isNull);
  });

  group('서버가 상한 안에 아무 답도 주지 않은 실행', () {
    // 온라인에서 문서 리스너는 로컬 캐시에 문서가 없으면 초기 스냅샷을 아예
    // 올리지 않는다(SDK 의 `shouldRaiseInitialEvent`). 기기를 바꿔 처음
    // 로그인한 사람이 정확히 그 실행이라, **값이 하나도 오지 않는 구간**이
    // 이 단계의 주 대상 시나리오와 겹친다. 상한은 그 구간을 끝내야 한다.
    const grace = Duration(milliseconds: 50);
    late FakeUserDataStore graced;

    setUp(() {
      graced = FakeUserDataStore(profileConfirmGrace: grace);
      addTearDown(graced.dispose);
    });

    ProviderContainer container() {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          userDataStoreProvider.overrideWithValue(graced),
        ],
      );
      addTearDown(container.dispose);
      container.listen(selectedTeamIdProvider, (_, _) {});
      return container;
    }

    /// 상한이 넉넉히 지날 만큼 기다린다.
    Future<void> passGrace() async {
      await Future<void>.delayed(grace * 4);
      await pumpEventQueue();
    }

    test('캐시도 비어 있으면 대기 화면이 상한에서 끝나고 온보딩이 뜬다', () async {
      SharedPreferences.setMockInitialValues({});
      graced.documents[uid] = _serverDocument('lotte');
      graced.holdProfiles = true;
      final c = container();
      await pumpEventQueue();
      expect(c.read(selectedTeamIdProvider).isLoading, isTrue, reason: '아직 상한 안이다');

      await passGrace();

      final state = c.read(selectedTeamIdProvider);
      expect(
        state.isLoading,
        isFalse,
        reason: '상한이 지났는데도 로딩이면 게이트가 끝나지 않는 대기 화면을 그린다',
      );
      expect(state.hasValue, isTrue);
      expect(state.value, isNull);
    });

    test('상한이 지난 뒤에 온 답으로 화면이 수렴한다', () async {
      // 상한은 갈래를 정하는 바닥이지 사람을 옛 판단에 가두는 자물쇠가 아니다.
      SharedPreferences.setMockInitialValues({});
      graced.documents[uid] = _serverDocument('lotte');
      graced.holdProfiles = true;
      final c = container();
      await passGrace();
      expect(c.read(selectedTeamIdProvider).value, isNull);

      graced.releaseProfiles();

      expect(await settledTeamId(c), 'lotte');
      expect(await cachedTeamId(), 'lotte');
    });

    test('캐시에 값이 있으면 상한을 넘겨도 홈에 머무른다', () async {
      // "답이 없다"를 **문서 없음**으로 확정하면 이미 팀을 고른 사람이 통신이
      // 느렸다는 이유만으로 온보딩에 서고, 거기서 팀을 누르면 물러서기가
      // 받아 내야 한다 — 오프라인에서는 그 읽기도 실패해 안내로 끝난다.
      // **서버를 읽지 못했다**로 확정하면 이 계층에 이미 서 있는 규칙(서버를
      // 읽지 못하면 캐시가 정한다)이 그대로 적용된다
      // (decisions.md 2026-09-04 [M]).
      await seedCache('lg');
      graced.documents[uid] = _serverDocument('lg');
      graced.holdProfiles = true;
      final c = container();
      await passGrace();

      final state = c.read(selectedTeamIdProvider);
      expect(state.hasValue, isTrue);
      expect(
        state.value,
        'lg',
        reason: '상한이 이 사람을 온보딩으로 내려보냈다 — 캐시를 남긴 이유와 어긋난다',
      );
    });
  });

  group('팀 변경 모드의 선택은 물러서지 않는다', () {
    test('스냅샷이 오류로 끝난 세션에서도 바꾼 팀이 원본에 남는다', () async {
      // 물러서기는 **온보딩** 갈래의 장치다. 변경 모드에서 고른 팀까지 물러서면
      // 사람은 "응원 팀 바꾸기"에서 팀을 골랐는데 화면이 잠깐 바뀌었다가 옛
      // 팀으로 되돌아오고, 안내도 없어 까닭을 알 길이 없다.
      await seedCache('lg');
      store.documents[uid] = _serverDocument('lg');
      store.holdProfiles = true;
      final container = makeContainer();
      expect(await settledTeamId(container), 'lg');

      // 스냅샷이 오류로 끝난다 — 이 세션은 사용자 문서를 끝내 보지 못한다.
      store.emitProfileError(const BackendNetworkError(code: 'unavailable'));
      await pumpEventQueue();
      expect(container.read(selectedTeamIdProvider).value, 'lg');

      await container
          .read(selectedTeamIdProvider.notifier)
          .select('kt', isChange: true);
      await pumpEventQueue();

      final document = store.documents[uid]!;
      expect(document[UserFields.favoriteTeamId], 'kt');
      expect(document[UserFields.profileThemeKey], 'kt');
      expect(store.profileCreates, 0);
      expect(document[UserFields.joinedAt], DateTime.utc(2026, 3, 1));
      expect(await cachedTeamId(), 'kt');
      expect(container.read(selectedTeamIdProvider).value, 'kt');
    });

    test('문서가 아직 없는 계정의 변경도 첫 문서를 만든다', () async {
      // 캐시가 홈을 그린 채 서버에는 이 계정의 문서가 없는 실행이다 — 변경
      // 모드가 곧바로 수정으로 가면 없는 문서를 고치려다 실패한다.
      await seedCache('lg');
      store.holdProfiles = true;
      final container = makeContainer();
      expect(await settledTeamId(container), 'lg');

      await container
          .read(selectedTeamIdProvider.notifier)
          .select('kt', isChange: true);

      expect(store.profileCreates, 1);
      expect(store.documents[uid]![UserFields.favoriteTeamId], 'kt');
      expect(await cachedTeamId(), 'kt');
    });
  });

  group('저장하지 못한 선택은 화면에도 남지 않는다', () {
    // 실패 안내(`TeamSelectScreen.saveFailureNotice`)는 뜨지만, 실패를 이미
    // 아는 자리에서 화면을 아는 값으로 되돌리지 않으면 고른 팀이 그 세션 내내
    // 남는다 — 다음 콜드 스타트에서 옛 팀이 아무 설명 없이 돌아온다. 되돌릴
    // 값을 아는 갈래(변경 모드)와 없는 갈래(온보딩)가 다르다.
    test('변경 모드의 실패는 화면을 원본이 아는 팀으로 되돌린다', () async {
      await seedCache('lg');
      store.documents[uid] = _serverDocument('lg');
      final container = makeContainer();
      expect(await settledTeamId(container), 'lg');

      store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
      await expectLater(
        container
            .read(selectedTeamIdProvider.notifier)
            .select('doosan', isChange: true),
        throwsA(isA<BackendNetworkError>()),
      );
      await pumpEventQueue();

      expect(
        container.read(selectedTeamIdProvider).value,
        'lg',
        reason: '서버에 닿지 못한 팀이 화면에 남았다',
      );
      expect(store.documents[uid]![UserFields.favoriteTeamId], 'lg');
      expect(await cachedTeamId(), 'lg');
    });

    test('온보딩의 실패는 화면을 팀 없음으로 되돌린다', () async {
      // 되돌릴 값이 없는 갈래다 — 아무 팀도 없던 자리로 돌아가야 사람이 다시
      // 고를 수 있다.
      SharedPreferences.setMockInitialValues({});
      final container = makeContainer();
      expect(await settledTeamId(container), isNull);

      store.profileWriteFailure = const BackendNetworkError(code: 'unavailable');
      await expectLater(
        container.read(selectedTeamIdProvider.notifier).select('kt'),
        throwsA(isA<BackendNetworkError>()),
      );
      await pumpEventQueue();

      expect(
        container.read(selectedTeamIdProvider).value,
        isNull,
        reason: '문서도 사본도 없는데 화면만 고른 팀에 남았다',
      );
      expect(store.documents, isEmpty);
      expect(await cachedTeamId(), isNull);
    });

    test('뒤 선택이 이미 옮긴 화면은 앞 선택의 실패가 되돌리지 않는다', () async {
      // 줄에 선 두 선택 중 앞엣것만 실패한 실행이다. 되돌리기가 지금 화면을
      // 보지 않으면, 성공한 뒤 선택의 팀이 앞 선택의 실패에 밀려 사라진다.
      // 스냅샷도 사본도 이 실행에서 화면을 다시 그리지 않게 막아 둔다 — 둘 중
      // 하나라도 움직이면 build 가 다시 돌아 되돌리기가 남긴 자국을 덮어,
      // 이 시험이 재려는 갈래를 지나치게 된다.
      SharedPreferences.setMockInitialValues({});
      final failing = _FailFirstCreateStore();
      addTearDown(failing.dispose);
      failing.holdProfiles = true;
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          userDataStoreProvider.overrideWithValue(failing),
          selectedTeamStoreProvider.overrideWithValue(const _FailingCacheStore()),
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
      await pumpEventQueue();

      expect(
        container.read(selectedTeamIdProvider).value,
        'kia',
        reason: '성공한 뒤 선택의 팀이 앞 선택의 실패에 밀려 사라졌다',
      );
      expect(failing.documents[uid]![UserFields.favoriteTeamId], 'kia');
    });
  });

  test('로그인하지 않은 실행의 선택은 권한 오류로 드러난다', () async {
    SharedPreferences.setMockInitialValues({});
    auth = FakeAuthService();
    addTearDown(auth.dispose);
    final container = makeContainer();
    await settledTeamId(container);

    await expectLater(
      container.read(selectedTeamIdProvider.notifier).select('lg'),
      throwsA(isA<BackendPermissionError>()),
    );
    expect(store.documents, isEmpty);
  });
}

/// 첫 문서 만들기를 붙잡아 두는 대역 — 서버 왕복이 끝나지 않은 구간이다.
/// 그 사이에 다음 선택이 줄에 서고, 계정도 바뀔 수 있다.
class _GatedCreateStore extends FakeUserDataStore {
  final Completer<void> gate = Completer<void>();

  @override
  Future<bool> createProfile(String uid, NewUserProfile profile) async {
    await gate.future;
    return super.createProfile(uid, profile);
  }
}

/// 첫 쓰기만 실패하는 저장소 — 통신이 한 번 끊겼다 이어진 실행의 대역이다.
class _FailFirstCreateStore extends FakeUserDataStore {
  int _creates = 0;

  @override
  Future<bool> createProfile(String uid, NewUserProfile profile) async {
    _creates++;
    if (_creates == 1) throw const BackendNetworkError(code: 'unavailable');
    return super.createProfile(uid, profile);
  }
}

/// 사용자 문서를 **읽지 못하는** 저장소 — 물러선 자리에서 수렴시킬 값을
/// 가져오지도 못하는 실행의 대역이다. 쓰기는 부모 구현 그대로다.
class _UnreadableProfileStore extends FakeUserDataStore {
  @override
  Future<UserProfile?> readProfile(String uid) async {
    throw const BackendNetworkError(code: 'unavailable');
  }
}

/// 기기 저장이 언제나 실패하는 캐시 — 저장 공간이 꽉 찼거나 플랫폼 채널이
/// 죽은 실행의 대역이다. 읽기는 부모 구현 그대로다.
class _FailingCacheStore extends SelectedTeamStore {
  const _FailingCacheStore();

  @override
  Future<void> write(String uid, String teamId) async {
    throw StateError('기기 저장에 적을 수 없다');
  }
}
