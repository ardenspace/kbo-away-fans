/// 적대적 탐침 (step 2.4) — 세 자리를 잰다. 셋 다 **변이 주입에서 살아남은**
/// 곳이다: 그 줄을 지워도 `flutter test` 가 전부 초록불이었다.
///
///  1) **중첩 map 재귀** — `encodeBackendValues` 가 `board` 안쪽까지 내려가지
///     않으면 칸 요약에 실린 [ServerTimestamp] 가 계약 타입인 채로 서버에
///     나간다. 기존 시험("중첩된 칸 요약 안까지 옮긴다")은 안쪽에 평범한
///     숫자·문자열만 넣어 두어서 재귀를 통째로 지워도 통과했다. 4.2 의 도장
///     쓰기가 칸 요약에 시각을 실으면 그때 물린다.
///  2) **기본 닉네임의 결정적 씨앗** — "기기를 바꿔도 같은 이름"은 실행을
///     가로질러 같은 값이어야 성립하는데, 한 실행 안에서 두 번 불러 비교하는
///     시험은 `String.hashCode` 로 바꿔도 초록불이다(같은 실행 안에서는
///     그것도 같은 값을 준다). 붙박이 값으로 못 박아 알고리즘이 바뀌면
///     드러나게 한다.
///  3) **세션을 아직 모르는 구간** — `userProfileProvider` 는 그 구간에
///     아무것도 흘리지 않아야 한다(로스터의 계약). null 을 흘리도록 바꿔도
///     기존 시험은 전부 초록불이었다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';

import 'fake_backend.dart';

void main() {
  group('중첩 map 안의 계약 타입도 SDK 값으로 옮겨진다', () {
    test('board 안 칸 요약에 실린 서버 시각 표시가 남아 있지 않다', () {
      final encoded = encodeBackendValues({
        UserFields.board: <String, Object?>{
          'jamsil_lg': <String, Object?>{
            BoardCellFields.count: 1,
            'stampedAt': const ServerTimestamp(),
          },
        },
      });

      final board = encoded[UserFields.board]! as Map<String, Object?>;
      final cell = board['jamsil_lg']! as Map<String, Object?>;
      // 계약 타입이 그대로 나가면 Firestore 가 값을 직렬화하지 못한다.
      expect(cell['stampedAt'], isNot(isA<BackendTimestamp>()));
    });

    test('두 겹 아래의 이미 정해진 시각도 옮겨진다', () {
      final encoded = encodeBackendValues({
        'outer': <String, Object?>{
          'inner': <String, Object?>{
            'at': ExactTimestamp(DateTime.utc(2026, 9, 1, 12)),
          },
        },
      });

      final outer = encoded['outer']! as Map<String, Object?>;
      final inner = outer['inner']! as Map<String, Object?>;
      expect(inner['at'], isNot(isA<BackendTimestamp>()));
    });
  });

  group('기본 닉네임은 실행을 가로질러 같은 값이다', () {
    test('uid 에서 나오는 값이 붙박이다 — 알고리즘이 바뀌면 여기서 드러난다', () {
      expect(seedNickname(uid: 'kakao:1234567890'), '원정러5538');
      expect(seedNickname(uid: 'google:abcdef'), '원정러7988');
    });
  });

  group('세션을 아직 모르는 구간에는 사용자 문서를 흘리지 않는다', () {
    test('복원 전에는 값이 없고, 복원 뒤에야 문서 유무가 정해진다', () async {
      final auth = UnknownSessionAuthService();
      addTearDown(auth.dispose);
      final store = FakeUserDataStore();
      addTearDown(store.dispose);

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          userDataStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(container.dispose);
      container.listen(userProfileProvider, (_, _) {});
      await pumpEventQueue();

      // 여기서 null 이 흐르면 로그인해 둔 사람이 한 프레임 동안 "문서 없는
      // 사람"(= 온보딩 대상)으로 보인다.
      expect(container.read(userProfileProvider).hasValue, isFalse);

      auth.restore(const AuthUser(uid: 'kakao:1'));
      await pumpEventQueue();

      expect(container.read(userProfileProvider).hasValue, isTrue);
      expect(container.read(userProfileProvider).value, isNull);
    });
  });
}
