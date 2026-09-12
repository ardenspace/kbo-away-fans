import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';

import 'fake_backend.dart';

const _uid = 'legacy-user';

final class _LegacyPatchCase {
  const _LegacyPatchCase({
    required this.name,
    required this.patch,
    required this.expectedNickname,
    required this.expectedTeam,
    required this.expectedFamily,
    required this.expectedBrightness,
    this.storedFamily,
    this.storedBrightness,
  });

  final String name;
  final UserProfilePatch patch;
  final String expectedNickname;
  final String? expectedTeam;
  final String expectedFamily;
  final String expectedBrightness;
  final String? storedFamily;
  final String? storedBrightness;

  Map<String, Object?> seedData() => <String, Object?>{
    UserFields.nickname: '기존사용자',
    UserFields.favoriteTeamId: 'lg',
    kLegacyProfileThemeKeyField: 'lg',
    if (storedFamily != null) UserFields.defaultThemeFamily: storedFamily,
    if (storedBrightness != null)
      UserFields.brightnessPreference: storedBrightness,
    UserFields.joinedAt: DateTime.utc(2026, 3, 1),
    UserFields.board: <String, Object?>{},
  };
}

const _matrix = <_LegacyPatchCase>[
  _LegacyPatchCase(
    name: 'missing both + nickname-only',
    patch: UserProfilePatch(nickname: '바뀐닉'),
    expectedNickname: '바뀐닉',
    expectedTeam: 'lg',
    expectedFamily: 'a',
    expectedBrightness: 'auto',
  ),
  _LegacyPatchCase(
    name: 'missing both + favorite-team-only',
    patch: UserProfilePatch(favoriteTeamId: null),
    expectedNickname: '기존사용자',
    expectedTeam: null,
    expectedFamily: 'a',
    expectedBrightness: 'auto',
  ),
  _LegacyPatchCase(
    name: 'stored b/dark + nickname-only',
    patch: UserProfilePatch(nickname: '바뀐닉'),
    expectedNickname: '바뀐닉',
    expectedTeam: 'lg',
    expectedFamily: 'b',
    expectedBrightness: 'dark',
    storedFamily: 'b',
    storedBrightness: 'dark',
  ),
  _LegacyPatchCase(
    name: 'stored b/dark + favorite-team-only',
    patch: UserProfilePatch(favoriteTeamId: 'kt'),
    expectedNickname: '기존사용자',
    expectedTeam: 'kt',
    expectedFamily: 'b',
    expectedBrightness: 'dark',
    storedFamily: 'b',
    storedBrightness: 'dark',
  ),
  _LegacyPatchCase(
    name: 'stored family only + favorite-team-only',
    patch: UserProfilePatch(favoriteTeamId: null),
    expectedNickname: '기존사용자',
    expectedTeam: null,
    expectedFamily: 'b',
    expectedBrightness: 'auto',
    storedFamily: 'b',
  ),
  _LegacyPatchCase(
    name: 'stored brightness only + nickname-only',
    patch: UserProfilePatch(nickname: '바뀐닉'),
    expectedNickname: '바뀐닉',
    expectedTeam: 'lg',
    expectedFamily: 'a',
    expectedBrightness: 'dark',
    storedBrightness: 'dark',
  ),
];

void _expectResult(_LegacyPatchCase case_, Map<String, Object?> written) {
  expect(written[UserFields.nickname], case_.expectedNickname);
  expect(written[UserFields.favoriteTeamId], case_.expectedTeam);
  expect(written[UserFields.defaultThemeFamily], case_.expectedFamily);
  expect(written[UserFields.brightnessPreference], case_.expectedBrightness);
  expect(written[UserFields.joinedAt], DateTime.utc(2026, 3, 1));
  expect(written[UserFields.board], isEmpty);
  expect(written[UserFields.updatedAt], isNotNull);
  expect(written, isNot(contains(kLegacyProfileThemeKeyField)));
}

void main() {
  group('FakeUserDataStore legacy-patch matrix', () {
    for (final case_ in _matrix) {
      test(case_.name, () async {
        final store = FakeUserDataStore();
        store.documents[_uid] = case_.seedData();

        await store.patchProfile(_uid, case_.patch);

        _expectResult(case_, store.documents[_uid]!);
      });
    }
  });

  group('FirestoreUserDataStore legacy-patch matrix', () {
    for (final case_ in _matrix) {
      test(case_.name, () async {
        final db = FakeFirebaseFirestore();
        final reference = db.collection(kUsersCollection).doc(_uid);
        await reference.set(case_.seedData());
        final store = FirestoreUserDataStore(db);

        await store.patchProfile(_uid, case_.patch);

        final written = (await reference.get()).data()!;
        _expectResult(case_, decodeBackendValues(written));
      });
    }
  });
}
