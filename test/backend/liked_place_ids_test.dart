/// Step 3.2 boundary tests — [LikedPlaceIds] 하나로 좋아요 상태를 읽고 바꾸는
/// 계약.
///
/// 재는 갈래:
///  1) 로그인한 사람은 좋아요 목록을 **한 번만** 읽고, 그 뒤로 다시 읽지
///     않는다(카드마다 읽지 않는다는 결정의 근거).
///  2) 토글이 성공하면 서버를 다시 읽지 않고 로컬 집합만 반영한다.
///  3) 같은 장소를 두 번 눌러도(연타) 서버 문서는 하나다.
///  4) 토글이 실패하면 집합은 그대로다 — 실패는 그대로 던져
///     [LikeButton] 이 자기 모습을 되돌리는 자리로 넘어간다.
///  5) 세션이 없으면 빈 집합이고 서버를 읽지 않는다.
///  6) 세션이 눌린 순간 사라지면 `unauthenticated` 로 던진다.
///  7) 좋아요 목록을 못 읽어도(네트워크 등) 추천 목록 전체를 막지 않고 빈
///     집합으로 본다 — 다시 읽으면 바로잡히는 정보다.
///
/// `authStateProvider` 는 세션 스트림이라 첫 값이 비동기로 온다 —
/// `container.listen` 으로 구독을 미리 세우고 [_settledLikes] 로 그 값이
/// 도착할 때까지 이벤트 큐를 비운 뒤에 읽는다(`selected_team_test.dart` 의
/// `settledTeamId` 와 같은 이유).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/models.dart' show PlaceCategory;

import 'fake_backend.dart';

const _uid = 'kakao:1234567890';

const LikeWrite _like = LikeWrite(
  placeId: 'jamsil-noodle-house',
  stadiumId: 'jamsil',
  category: PlaceCategory.food,
);

/// 좋아요 목록 읽기가 언제나 실패하는 대역 — "서버를 못 읽었다"의 대역이다.
class _FailingLikesStore extends FakeUserDataStore {
  @override
  Future<List<LikeRecord>> readLikes(String uid) async {
    likeReads++;
    throw const BackendNetworkError(code: 'unavailable');
  }
}

void main() {
  late FakeUserDataStore store;
  late FakeAuthService auth;

  setUp(() {
    store = FakeUserDataStore();
    auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
    addTearDown(auth.dispose);
    addTearDown(store.dispose);
  });

  ProviderContainer makeContainer({FakeUserDataStore? backend}) {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(backend ?? store),
      ],
    );
    addTearDown(container.dispose);
    // 구독이 없으면 provider 는 읽는 순간에야 서고, 그 사이 세션 스트림의
    // 첫 이벤트가 흐를 자리가 없다 (`selected_team_test.dart` 의
    // `makeContainer` 와 같은 이유).
    container.listen(likedPlaceIdsProvider, (_, _) {});
    return container;
  }

  /// 세션 스트림의 첫 이벤트까지 이벤트 큐를 비운 뒤 지금 값을 읽는다.
  Future<Set<String>> settledLikes(ProviderContainer container) async {
    await pumpEventQueue();
    return container.read(likedPlaceIdsProvider).value ?? const {};
  }

  test('로그인한 사람의 좋아요는 한 번만 읽고, 다시 watch 해도 또 읽지 않는다', () async {
    await store.addLike(_uid, _like);
    final container = makeContainer();

    final first = await settledLikes(container);
    expect(first, {'jamsil-noodle-house'});
    expect(store.likeReads, 1);

    // 다시 읽어도(캐시된 값) 서버는 또 불리지 않는다.
    final second = container.read(likedPlaceIdsProvider).value;
    expect(second, {'jamsil-noodle-house'});
    expect(store.likeReads, 1, reason: '카드가 여러 장이어도 읽기는 한 번이어야 한다');
  });

  test('세션이 없으면 빈 집합이고 서버를 읽지 않는다', () async {
    auth = FakeAuthService();
    addTearDown(auth.dispose);
    final container = makeContainer();

    final result = await settledLikes(container);

    expect(result, isEmpty);
    expect(store.likeReads, 0);
  });

  test('좋아요 목록을 못 읽으면 추천 목록을 막지 않고 빈 집합으로 본다', () async {
    final failing = _FailingLikesStore();
    addTearDown(failing.dispose);
    final container = makeContainer(backend: failing);

    final result = await settledLikes(container);

    expect(result, isEmpty);
    expect(failing.likeReads, 1);
  });

  test('토글로 누르면 서버에 문서가 남고, 다시 읽지 않고도 집합에 반영된다', () async {
    final container = makeContainer();
    await settledLikes(container);
    final readsBeforeToggle = store.likeReads;

    await container
        .read(likedPlaceIdsProvider.notifier)
        .toggle(_like.placeId, _like, true);

    expect(container.read(likedPlaceIdsProvider).value, {
      'jamsil-noodle-house',
    });
    expect(await store.readLikes(_uid), hasLength(1));
    expect(
      store.likeReads,
      readsBeforeToggle + 1,
      reason: '위 검증용 readLikes 1회뿐 — toggle 자체는 다시 읽지 않는다',
    );
  });

  test('같은 장소를 두 번 눌러도(연타) 서버 문서는 하나다', () async {
    final container = makeContainer();
    await settledLikes(container);
    final notifier = container.read(likedPlaceIdsProvider.notifier);

    await notifier.toggle(_like.placeId, _like, true);
    await notifier.toggle(_like.placeId, _like, true);

    expect(await store.readLikes(_uid), hasLength(1));
    expect(container.read(likedPlaceIdsProvider).value, {
      'jamsil-noodle-house',
    });
  });

  test('토글로 취소하면 집합에서 빠지고 서버 문서도 지워진다', () async {
    await store.addLike(_uid, _like);
    final container = makeContainer();
    await settledLikes(container);

    await container
        .read(likedPlaceIdsProvider.notifier)
        .toggle(_like.placeId, _like, false);

    expect(container.read(likedPlaceIdsProvider).value, isEmpty);
    expect(await store.readLikes(_uid), isEmpty);
  });

  test('쓰기가 실패하면 집합은 그대로고 실패가 그대로 던져진다', () async {
    final container = makeContainer();
    await settledLikes(container);
    store.likeWriteFailure = const BackendNetworkError(code: 'unavailable');

    await expectLater(
      container
          .read(likedPlaceIdsProvider.notifier)
          .toggle(_like.placeId, _like, true),
      throwsA(isA<BackendNetworkError>()),
    );

    expect(container.read(likedPlaceIdsProvider).value, isEmpty);
    expect(await store.readLikes(_uid), isEmpty, reason: '쓰기 자체가 실패했다');
  });

  test('세션이 눌린 순간 사라지면 unauthenticated 로 던진다', () async {
    final container = makeContainer();
    await settledLikes(container);

    await auth.signOut();
    await pumpEventQueue();

    await expectLater(
      container
          .read(likedPlaceIdsProvider.notifier)
          .toggle(_like.placeId, _like, true),
      throwsA(
        isA<BackendPermissionError>().having(
          (e) => e.code,
          'code',
          'unauthenticated',
        ),
      ),
    );
  });
}
