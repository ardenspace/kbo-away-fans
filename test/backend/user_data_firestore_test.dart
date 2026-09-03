/// Step 2.4 — 계약 타입과 Firestore SDK 타입 사이의 **어댑터**를 잰다.
///
/// `user_data.dart` 는 SDK 를 모르는 채로 계약을 들고 있고([ServerTimestamp]·
/// [ExactTimestamp]), 문서를 실제로 오가는 값으로 옮기는 자리는
/// `user_data_firestore.dart` 하나다. 그 한 자리가 어긋나면 서버에는
/// **문자열도 시각도 아닌 값**이 실려 규칙(`joinedAt is timestamp`)이 쓰기를
/// 거부하는데, 그 실패는 에뮬레이터나 실기기에서만 보인다.
///
/// 저장소 자체(`FirestoreUserDataStore`)는 여기서 돌리지 않는다 — 그것은
/// 플랫폼 채널을 타므로 규칙 테스트(`firebase/test/`)와 실기기가 재는 자리다.
/// 어댑터는 순수 함수라 여기서 그대로 잴 수 있다.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';
import 'package:kbo_away_fans/design/tokens.dart';

void main() {
  group('올려 보내는 값 (encode)', () {
    test('서버 시각 표시는 SDK 의 서버 시각 센티널이 된다', () {
      final data = encodeBackendValues(
        const NewUserProfile(
          nickname: '원정러',
          favoriteTeamId: 'lg',
          profileThemeKey: 'lg',
        ).toData(),
      );

      expect(data[UserFields.joinedAt], isA<FieldValue>());
      expect(data[UserFields.nickname], '원정러');
      expect(data[UserFields.board], isEmpty);
    });

    test('이미 정해진 시각은 SDK 의 Timestamp 로 간다', () {
      final at = DateTime.utc(2026, 9, 1, 12);

      final data = encodeBackendValues({'at': ExactTimestamp(at)});

      expect(data['at'], isA<Timestamp>());
      expect((data['at']! as Timestamp).toDate().toUtc(), at);
    });

    test('중첩된 칸 요약 안까지 옮긴다', () {
      final data = encodeBackendValues({
        UserFields.board: {
          'jamsil_lg': BoardCell.forCount(count: 2).toData(),
        },
      });

      final board = data[UserFields.board]! as Map<String, Object?>;
      final cell = board['jamsil_lg']! as Map<String, Object?>;
      expect(cell[BoardCellFields.count], 2);
      expect(cell[BoardCellFields.tier], BadgeTier.first.name);
    });
  });

  group('읽어 오는 값 (decode)', () {
    test('SDK 의 Timestamp 는 UTC DateTime 이 된다', () {
      final at = DateTime.utc(2026, 9, 1, 12);

      final data = decodeBackendValues({'at': Timestamp.fromDate(at)});

      // UTC 로 못 박는 것은 DateTime 의 같음이 isUtc 까지 비교하기 때문이다 —
      // 기기의 시간대에 따라 같은 순간이 다른 값으로 읽히면 안 된다.
      expect(data['at'], at);
      expect((data['at']! as DateTime).isUtc, isTrue);
    });

    test('읽은 문서가 그대로 UserProfile 이 된다', () {
      final joinedAt = DateTime.utc(2026, 9, 1, 12);
      final raw = <String, dynamic>{
        UserFields.nickname: '원정러',
        UserFields.favoriteTeamId: 'hanwha',
        UserFields.profileThemeKey: 'hanwha',
        UserFields.joinedAt: Timestamp.fromDate(joinedAt),
        UserFields.board: <String, dynamic>{
          'daejeon_hanwha': <String, dynamic>{
            BoardCellFields.count: 3,
            BoardCellFields.tier: 'regular',
            BoardCellFields.lastStampedOn: '2026-09-01',
          },
        },
      };

      final profile = UserProfile.fromData(
        uid: 'u1',
        data: decodeBackendValues(raw),
      );

      expect(profile.favoriteTeamId, 'hanwha');
      expect(profile.joinedAt, joinedAt);
      expect(profile.updatedAt, isNull);
      expect(profile.board['daejeon_hanwha']!.tier, BadgeTier.regular);
    });
  });
}
