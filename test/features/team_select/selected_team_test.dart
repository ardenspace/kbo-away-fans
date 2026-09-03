/// Step 2.4 boundary tests — 선택 팀의 원본이 Firestore 사용자 문서로 옮겨온
/// 뒤의 상태 계층.
///
/// 재는 갈래는 넷이다 (계획의 boundary test 가 괄호로 지정한 그대로).
///  1) 문서 최초 생성 1회 — 온보딩에서 팀을 고른 그 순간 문서가 만들어진다.
///  2) 재로그인 무변경 — 다시 로그인해도 가입 시각·배지 판이 그대로다.
///  3) 캐시 → 서버 수렴 — 서버를 모르는 첫 프레임은 캐시 값으로 그리고,
///     서버 값이 오면 그것으로 수렴한다.
///  4) 서버 값과 캐시 불일치 시 서버 우선 — 캐시는 원본이 아니다.
library;

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

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
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

  test('서버 값을 아직 모르는 채로 고른 팀도 문서를 덮지 않는다', () async {
    // 스냅샷이 늦는 사이 온보딩 화면이 떴다가 선택이 일어난 경우 — 이미 있는
    // 문서를 만들려 들면 가입 시각이 지워진다. 저장소가 그 앞에서 막는다.
    SharedPreferences.setMockInitialValues({});
    store.documents[uid] = _serverDocument('lg');
    store.holdProfiles = true;
    final container = makeContainer();
    expect(await settledTeamId(container), isNull);

    await container.read(selectedTeamIdProvider.notifier).select('kt');

    expect(store.profileCreates, 0);
    final document = store.documents[uid]!;
    expect(document[UserFields.favoriteTeamId], 'kt');
    expect(document[UserFields.joinedAt], DateTime.utc(2026, 3, 1));
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

    expect(await settledTeamId(container), isNull);

    store.releaseProfiles();

    expect(await settledTeamId(container), isNull);
  });

  test('소유자를 적지 않은 옛 판의 캐시는 읽지 않는다', () async {
    // 앱을 올리기 전 판이 남긴 값 — 누구 것인지 알 수 없으므로 없는 것으로
    // 본다 (앞사람의 팀일 수 있다).
    SharedPreferences.setMockInitialValues({kSelectedTeamPrefsKey: 'lotte'});
    store.holdProfiles = true;
    final container = makeContainer();

    expect(await settledTeamId(container), isNull);
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
