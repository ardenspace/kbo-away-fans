/// Step 2.4 — `FirestoreUserDataStore` **그 자체**를 돌린다.
///
/// 이 파일이 서기 전까지 저장소 구현은 어느 줄을 망가뜨려도 `flutter test` 가
/// 전부 초록불이었다. 실제로 살아남은 변이가 넷이다.
///
///  1) `createProfile` 트랜잭션 안의 "이미 있으면 아무것도 하지 않는다" 판정을
///     지운다 → 재로그인이 가입 시각과 배지 판을 지운다.
///  2) 그 트랜잭션을 통째로 무조건 `set` 으로 바꾼다 → 같은 결과.
///  3) `patchProfile` 의 `update` 를 `set` 으로 바꾼다 → 실물에서는 규칙의
///     `hasAll` 에 걸려 팀 변경이 통째로 실패한다.
///  4) `readProfile` 이 언제나 null 을 돌려준다 → 문서가 있는 사람이
///     온보딩으로 되돌아간다.
///
/// 넷 다 앱 쪽 대역(`fake_backend.dart` 의 [FakeUserDataStore])으로는 잡히지
/// 않는다 — 그 대역은 같은 규칙을 **따로 적어 둔 사본**이라 구현이 어긋나도
/// 사본은 멀쩡하기 때문이다. 그래서 여기서는 SDK 자리에 가짜 Firestore
/// (`fake_cloud_firestore`)를 끼워 구현 자신을 돌린다: 트랜잭션·`update` 의
/// 부분 갱신·스냅샷 스트림이 실 SDK 와 같은 의미로 도는 자리다.
///
/// 규칙(`firestore.rules`)이 이 payload 를 실제로 받아 주는지는 에뮬레이터가
/// 재는 몫이다 — `firebase/test/probe-2-4-app-payload.test.mjs`.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';
import 'package:kbo_away_fans/design/tokens.dart';

void main() {
  const uid = 'kakao:1234567890';
  final joinedAt = DateTime.utc(2026, 3, 1);

  late FakeFirebaseFirestore db;
  late UserDataStore store;

  setUp(() {
    db = FakeFirebaseFirestore();
    store = FirestoreUserDataStore(db);
  });

  Future<void> seedDocument(String teamId) => db
      .collection(kUsersCollection)
      .doc(uid)
      .set(encodeBackendValues(<String, Object?>{
        UserFields.nickname: '먼저있던닉',
        UserFields.favoriteTeamId: teamId,
        UserFields.profileThemeKey: teamId,
        UserFields.joinedAt: ExactTimestamp(joinedAt),
        UserFields.board: <String, Object?>{
          'jamsil_lg': BoardCell.forCount(count: 2).toData(),
        },
      }));

  Future<Map<String, Object?>> rawDocument() async {
    final snapshot = await db.collection(kUsersCollection).doc(uid).get();
    return decodeBackendValues(snapshot.data()!);
  }

  group('첫 문서 만들기', () {
    test('문서가 없으면 만들고, 그것을 다시 읽을 수 있다', () async {
      final created = await store.createProfile(
        uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'hanwha',
          profileThemeKey: 'hanwha',
        ),
      );

      expect(created, isTrue);
      // readProfile 이 언제나 null 을 돌려주는 변이가 여기서 빨간불이 된다.
      final profile = await store.readProfile(uid);
      expect(profile, isNotNull);
      expect(profile!.favoriteTeamId, 'hanwha');
      expect(profile.profileThemeKey, 'hanwha');
      expect(profile.nickname, '원정러');
      expect(profile.board, isEmpty);
      // 서버 시각 센티널이 실제 시각으로 확정된다.
      expect(profile.joinedAt, isA<DateTime>());
    });

    test('이미 있는 문서는 덮지 않는다 — 가입 시각과 배지 판이 남는다', () async {
      await seedDocument('lg');

      final created = await store.createProfile(
        uid,
        const NewUserProfile(
          nickname: '나중닉',
          favoriteTeamId: 'kia',
          profileThemeKey: 'kia',
        ),
      );

      // 트랜잭션의 존재 판정을 지우거나 무조건 set 으로 바꾸는 두 변이가
      // 여기서 빨간불이 된다. false 는 "만들지 않았다"는 뜻이고, 그 사실을
      // 받은 호출자가 수정 경로로 이어 간다.
      expect(created, isFalse);
      final profile = (await store.readProfile(uid))!;
      expect(profile.favoriteTeamId, 'lg');
      expect(profile.nickname, '먼저있던닉');
      expect(profile.joinedAt, joinedAt);
      expect(profile.board['jamsil_lg']!.count, 2);
      expect(profile.board['jamsil_lg']!.tier, BadgeTier.first);
    });
  });

  group('문서 고치기', () {
    test('준 필드만 바뀌고 나머지는 그대로다', () async {
      await seedDocument('lg');

      await store.patchProfile(
        uid,
        const UserProfilePatch(favoriteTeamId: 'kt', profileThemeKey: 'kt'),
      );

      // update 를 set 으로 바꾸는 변이가 여기서 빨간불이 된다 — set 은 문서를
      // 통째로 덮으므로 닉네임·가입 시각·배지 판이 사라지고, 실물에서는 그
      // 쓰기가 규칙의 hasAll 에 걸려 팀 변경 자체가 실패한다.
      final profile = (await store.readProfile(uid))!;
      expect(profile.favoriteTeamId, 'kt');
      expect(profile.profileThemeKey, 'kt');
      expect(profile.nickname, '먼저있던닉');
      expect(profile.joinedAt, joinedAt);
      expect(profile.board['jamsil_lg']!.count, 2);
      expect(profile.updatedAt, isNotNull);
    });

    test('나가는 문서에는 계약 밖 필드가 없다', () async {
      await store.createProfile(
        uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'nc',
          profileThemeKey: 'nc',
        ),
      );
      await store.patchProfile(uid, const UserProfilePatch(nickname: '바꾼닉'));

      // 규칙은 키를 hasOnly 로 닫아 두므로 계약 밖 필드가 한 번이라도 끼면
      // 그 뒤의 쓰기가 통째로 거부된다.
      expect((await rawDocument()).keys, everyElement(isIn(UserFields.all)));
    });
  });

  group('문서 구독', () {
    test('문서가 없으면 null, 만들어지면 그 값이 흐른다', () async {
      final seen = <String?>[];
      final subscription = store
          .watchProfile(uid)
          .listen((profile) => seen.add(profile?.favoriteTeamId));
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      expect(seen, [null]);

      await store.createProfile(
        uid,
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'ssg',
          profileThemeKey: 'ssg',
        ),
      );
      await pumpEventQueue();

      expect(seen.last, 'ssg');
    });
  });
}
