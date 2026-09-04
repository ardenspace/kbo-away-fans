/// 통합 검증 탐침 — 3.2 의 `LikedPlaceIds.toggle` 과 3.3 이 세운 "못 읽었다 ≠
/// 하나도 없다" 구분이 만나는 이음매.
///
/// 3.3 은 읽기 실패를 삼키지 않고 `AsyncError` 로 흘려 좋아요 탭이 재시도
/// 안내를 띄우게 했다. 그런데 3.2 의 [LikedPlaceIds.toggle] 은 성공한 쓰기
/// 뒤에 `state = AsyncData(...)` 로 상태를 통째로 갈아 끼우면서 그 오류를
/// 지운다 — 그것도 `state.value ?? const <String>{}` 로 **빈 집합에서 다시
/// 시작한** 값으로. 추천 탭은 오류를 빈 집합으로 접어 하트를 그리므로
/// (3.2 가 지키기로 한 fail-open) 거기서 하트를 한 번만 눌러도 이 일이
/// 일어난다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/models.dart' show PlaceCategory;

import 'fake_backend.dart';

const _uid = 'kakao:1234567890';

/// 읽기만 실패하는 대역 — 쓰기는 그대로 서버에 남는다.
class _FailingReadStore extends FakeUserDataStore {
  @override
  Future<List<LikeRecord>> readLikes(String uid) async {
    likeReads++;
    throw const BackendNetworkError(code: 'unavailable');
  }
}

void main() {
  test('읽기에 실패한 뒤 하트를 한 번 누르면 "못 읽었다"가 지워지지 않는다', () async {
    final store = _FailingReadStore();
    final auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
    addTearDown(auth.dispose);
    addTearDown(store.dispose);

    // 서버에는 이미 두 개가 있다 — 다만 읽기가 실패해 앱이 그것을 모른다.
    store.likes[_uid] = {
      'already-liked-1': const <String, Object?>{},
      'already-liked-2': const <String, Object?>{},
    };

    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        userDataStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);
    container.listen(likedPlaceIdsProvider, (_, _) {});
    await pumpEventQueue();

    // 3.3 의 계약: 읽기 실패는 오류로 드러난다.
    expect(container.read(likedPlaceIdsProvider).hasError, isTrue);

    // 추천 탭에서 하트를 한 번 누른다(그 화면은 오류를 빈 집합으로 접어
    // 하트를 그리므로 실제로 누를 수 있다).
    await container
        .read(likedPlaceIdsProvider.notifier)
        .toggle(
          'newly-liked',
          const LikeWrite(
            placeId: 'newly-liked',
            stadiumId: 'jamsil',
            category: PlaceCategory.food,
          ),
          true,
        );

    final after = container.read(likedPlaceIdsProvider);
    expect(
      after.hasError,
      isTrue,
      reason: '서버 목록을 여전히 읽지 못했으므로 좋아요 탭은 "못 읽었다"를 유지해야 한다 — '
          '지금은 AsyncData 로 바뀌어 "이 사람의 좋아요는 하나뿐"이라는 거짓 목록이 된다',
    );
    expect(
      after.value,
      isNot({'newly-liked'}),
      reason: '서버에는 세 개가 있는데 화면이 하나만 아는 상태로 굳는다',
    );
  });
}
