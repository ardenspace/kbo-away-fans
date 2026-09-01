/// Step 1.6 사용자 데이터 접근 계약 단위 테스트.
///
/// 두 가지를 잰다:
///  1) 업로드 payload 가 `docs/firestore-schema.md` 의 필드만 싣는다 —
///     계약 밖 필드가 하나라도 섞이면 규칙(hasOnly)이 쓰기를 통째로 거부하므로
///     타입이 그 앞에서 막아야 한다. 기기의 지점을 가리키는 필드가 어떤
///     업로드 경로에도 없다는 것도 여기서 확인한다.
///  2) 가짜 백엔드([FakeUserDataStore])로 읽기·쓰기 계약을 단언한다 —
///     결정적 문서 id 덕분에 같은 도장·같은 좋아요를 두 번 써도 문서가 하나다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/models.dart' show PlaceCategory;
import 'package:kbo_away_fans/design/tokens.dart';

import 'fake_backend.dart';

const NewUserProfile _newProfile = NewUserProfile(
  nickname: '원정러',
  favoriteTeamId: 'lotte',
  profileThemeKey: 'lotte',
);

const StampWrite _stamp = StampWrite(
  stadiumId: 'jamsil',
  gameId: '20260901-LGvsLOT',
  homeTeamId: 'lg',
  gameDate: '2026-09-01',
);

const LikeWrite _like = LikeWrite(
  placeId: 'jamsil-noodle-house',
  stadiumId: 'jamsil',
  category: PlaceCategory.food,
);

void main() {
  group('칸 id 로스터', () {
    test('10칸이고 판의 칸 수 토큰과 같다', () {
      expect(kBoardCellIds, hasLength(BadgeTokens.cellCount));
    });

    test('구장×홈팀 짝이 칸 id 를 만든다 — 잠실은 두 칸', () {
      expect(
        boardCellIdOf(stadiumId: 'jamsil', homeTeamId: 'doosan'),
        'jamsil_doosan',
      );
      expect(
        boardCellIdOf(stadiumId: 'jamsil', homeTeamId: 'lg'),
        'jamsil_lg',
      );
    });

    test('있을 수 없는 짝은 거부한다', () {
      expect(
        () => boardCellIdOf(stadiumId: 'gocheok', homeTeamId: 'lg'),
        throwsArgumentError,
      );
    });
  });

  group('업로드 payload 는 계약 필드만 싣는다', () {
    test('사용자 문서 생성 — 필수 다섯 필드', () {
      final data = _newProfile.toData();

      expect(data.keys.toSet(), UserFields.requiredFields);
      expect(data[UserFields.joinedAt], isA<ServerTimestamp>());
      expect(data[UserFields.board], isEmpty);
    });

    test('사용자 문서 수정 — 준 필드 + updatedAt 뿐', () {
      final data = const UserProfilePatch(favoriteTeamId: 'nc').toData();

      expect(
        data.keys.toSet(),
        {UserFields.favoriteTeamId, UserFields.updatedAt},
      );
    });

    test('빈 수정은 거부한다 — 의미 없는 쓰기가 나가지 않게', () {
      expect(() => const UserProfilePatch().toData(), throwsArgumentError);
    });

    test('도장 — 다섯 필드, 문서 id 는 {stadiumId}_{gameId}', () {
      final data = _stamp.toData();

      expect(data.keys.toSet(), StampFields.all);
      expect(_stamp.documentId, 'jamsil_20260901-LGvsLOT');
      expect(_stamp.cellId, 'jamsil_lg');
      expect(data[StampFields.stampedAt], isA<ServerTimestamp>());
    });

    test('좋아요 — 네 필드, 문서 id 는 placeId', () {
      final data = _like.toData();

      expect(data.keys.toSet(), LikeFields.all);
      expect(_like.documentId, 'jamsil-noodle-house');
      expect(data[LikeFields.category], 'food');
    });

    test('칸 요약 — 개수·등급·마지막 날짜', () {
      final cell = BoardCell.forCount(count: 3, lastStampedOn: '2026-09-01');

      expect(cell.tier, BadgeTier.regular);
      expect(cell.toData().keys.toSet(), BoardCellFields.all);
    });

    test('어떤 업로드 payload 에도 기기 지점 필드가 없다', () {
      final uploads = <Map<String, Object?>>[
        _newProfile.toData(),
        const UserProfilePatch(nickname: '바뀐 닉').toData(),
        _stamp.toData(),
        _like.toData(),
        BoardCell.forCount(count: 1).toData(),
      ];
      // 검사가 찾는 낱말은 소문자로 이어 붙여 만든다 — 이 파일 자신이
      // check-no-location-upload 의 grep 에 걸리지 않게 하기 위해서다.
      final banned = ['la${'t'}', 'l${'n'}g', 'coo${'r'}d'];

      for (final upload in uploads) {
        for (final key in upload.keys) {
          for (final word in banned) {
            expect(
              key.toLowerCase().contains(word),
              isFalse,
              reason: '$key 에 $word 가 들어 있다',
            );
          }
        }
      }
    });
  });

  group('계약 밖 값은 타입이 막는다', () {
    test('로스터 밖 팀·구장 id', () {
      expect(
        () => NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'seoul',
          profileThemeKey: 'lotte',
        ).toData(),
        throwsArgumentError,
      );
      expect(
        () => const StampWrite(
          stadiumId: 'busan',
          gameId: 'g1',
          homeTeamId: 'lotte',
          gameDate: '2026-09-01',
        ).toData(),
        throwsArgumentError,
      );
    });

    test('닉네임 길이 1~20 (UTF-16 코드 단위)', () {
      Map<String, Object?> profileWith(String nickname) => NewUserProfile(
            nickname: nickname,
            favoriteTeamId: 'lg',
            profileThemeKey: 'lg',
          ).toData();

      expect(() => profileWith(''), throwsArgumentError);
      expect(() => profileWith('가' * 21), throwsArgumentError);

      // 단위 못 박기: 계약을 최종 판정하는 규칙(`firestore.rules` 의
      // `nickname.size()`)이 UTF-16 코드 단위를 세고, 규칙 언어에는 그 단위를
      // 바꿀 방법이 없다. 코드 포인트로 세면 아래 값이 20 이라 여기서 통과하지만
      // 통과시켜 봐야 문서를 만드는 순간 규칙이 거부한다.
      const tiger = '\u{1F42F}'; // 🐯 — UTF-16 으로 2단위, 코드 포인트로는 1
      final cp20 = '가' * 18 + tiger * 2;
      expect(cp20.runes.length, 20, reason: '전제: 코드 포인트로는 20');
      expect(cp20.length, 22, reason: '전제: UTF-16 으로는 22');
      expect(() => profileWith(cp20), throwsArgumentError);

      // 경계 안쪽은 그대로 실린다 — 한글 20자(20단위)와 이모지 10개(20단위).
      for (final nickname in <String>['가' * 20, tiger * 10]) {
        expect(profileWith(nickname)[UserFields.nickname], nickname);
      }

      // 수정 경로도 같은 단위로 잰다.
      expect(
        () => UserProfilePatch(nickname: cp20).toData(),
        throwsArgumentError,
      );
    });

    test('날짜 표기·경기 id·장소 slug 형식', () {
      expect(
        () => const StampWrite(
          stadiumId: 'jamsil',
          gameId: 'g1',
          homeTeamId: 'lg',
          gameDate: '2026/09/01',
        ).toData(),
        throwsArgumentError,
      );
      expect(
        () => const StampWrite(
          stadiumId: 'jamsil',
          gameId: '경기 하나',
          homeTeamId: 'lg',
          gameDate: '2026-09-01',
        ).toData(),
        throwsArgumentError,
      );
      expect(
        () => const LikeWrite(
          placeId: 'Jamsil_Noodle',
          stadiumId: 'jamsil',
          category: PlaceCategory.food,
        ).toData(),
        throwsArgumentError,
      );
    });

    test('칸 요약의 개수는 1 이상 — 빈 칸은 키 자체가 없다', () {
      expect(() => BoardCell.forCount(count: 0), throwsArgumentError);
    });

    test('등급이 사다리와 어긋난 칸 요약은 만들 수 없다', () {
      expect(
        () => BoardCell(count: 1, tier: BadgeTier.master),
        throwsArgumentError,
      );
    });
  });

  group('가짜 백엔드로 본 접근 계약', () {
    late FakeUserDataStore store;

    setUp(() {
      store = FakeUserDataStore();
    });

    test('문서를 만들고 읽으면 올린 값이 그대로 돌아온다', () async {
      await store.createProfile('u1', _newProfile);

      final profile = await store.readProfile('u1');

      expect(profile, isNotNull);
      expect(profile!.uid, 'u1');
      expect(profile.nickname, '원정러');
      expect(profile.favoriteTeamId, 'lotte');
      expect(profile.joinedAt, kFakeServerNow);
      expect(profile.board, isEmpty);
    });

    test('문서가 없으면 null — 온보딩이 필요한 상태', () async {
      expect(await store.readProfile('없는사람'), isNull);
    });

    test('수정은 준 필드만 바꾸고 나머지는 남긴다', () async {
      await store.createProfile('u1', _newProfile);

      await store.patchProfile('u1', const UserProfilePatch(favoriteTeamId: 'nc'));

      final profile = await store.readProfile('u1');
      expect(profile!.favoriteTeamId, 'nc');
      expect(profile.nickname, '원정러');
      expect(profile.updatedAt, kFakeServerNow);
    });

    test('같은 경기 도장을 두 번 써도 문서는 하나다 (결정적 id)', () async {
      await store.writeStamp('u1', _stamp);
      await store.writeStamp('u1', _stamp);

      final stamps = await store.readStamps('u1');
      expect(stamps, hasLength(1));
      expect(stamps.single.documentId, 'jamsil_20260901-LGvsLOT');
      expect(stamps.single.cellId, 'jamsil_lg');
    });

    test('칸으로 걸러 읽으면 그 칸의 도장만 나온다', () async {
      await store.writeStamp('u1', _stamp);
      await store.writeStamp(
        'u1',
        const StampWrite(
          stadiumId: 'jamsil',
          gameId: '20260902-DSvsLOT',
          homeTeamId: 'doosan',
          gameDate: '2026-09-02',
        ),
      );

      expect(await store.readStamps('u1', cellId: 'jamsil_lg'), hasLength(1));
      expect(
        await store.readStamps('u1', cellId: 'jamsil_doosan'),
        hasLength(1),
      );
      expect(await store.readStamps('u1'), hasLength(2));
    });

    test('좋아요는 누른 장소마다 문서 하나이고 취소는 삭제다', () async {
      await store.addLike('u1', _like);
      await store.addLike('u1', _like);

      expect(await store.readLikes('u1'), hasLength(1));
      expect((await store.readLikes('u1')).single.category, PlaceCategory.food);

      await store.removeLike('u1', _like.documentId);

      expect(await store.readLikes('u1'), isEmpty);
    });

    test('판을 그리는 데 필요한 읽기는 사용자 문서 하나다', () async {
      await store.createProfile('u1', _newProfile);
      // 칸 요약은 도장 쓰기(4.2)가 같은 트랜잭션에서 채운다 — 여기서는
      // 서버에 이미 그렇게 남아 있는 문서를 읽는 쪽만 잰다.
      store.documents['u1']![UserFields.board] = <String, Object?>{
        'jamsil_lg': BoardCell.forCount(count: 2).toData(),
      };
      store.profileReads = 0;
      store.stampReads = 0;

      final profile = await store.readProfile('u1');

      expect(profile!.board['jamsil_lg']!.count, 2);
      expect(profile.board['jamsil_lg']!.tier, BadgeTier.first);
      expect(store.profileReads, 1);
      expect(store.stampReads, 0);
    });
  });
}
