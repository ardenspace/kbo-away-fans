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
///
/// 파일 끝의 [_snapshotSourceTests] 는 **가짜 Firestore 로도 재현되지 않는**
/// 갈래를 따로 잰다 — 오프라인 지속성이 스냅샷을 로컬 캐시에서 먼저 흘리는
/// 자리다. 그 까닭은 그 함수의 문서에 적어 두었다.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';
import 'package:kbo_away_fans/content/models.dart' show PlaceCategory;
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
      .set(
        encodeBackendValues(<String, Object?>{
          UserFields.nickname: '먼저있던닉',
          UserFields.favoriteTeamId: teamId,
          UserFields.profileThemeKey: teamId,
          UserFields.joinedAt: ExactTimestamp(joinedAt),
          UserFields.board: <String, Object?>{
            'jamsil_lg': BoardCell.forCount(count: 2).toData(),
          },
        }),
      );

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

  group('좋아요 쓰기 경로 — 오프라인 큐잉의 전제', () {
    // 2.4 구현자가 남긴 사실: `runTransaction`·`update` 는 서버에 닿아야
    // 끝나므로 통신이 없는 실행에서 완료되지 않는다. 반면 평범한 `set`·
    // `delete` 는 SDK 가 로컬에 큐잉했다가 복구 후 내보낸다. 오프라인에서
    // 누른 좋아요가 복구 후 반영되려면 이 경로가 그 둘을 타지 않아야 한다.
    //
    // `fake_cloud_firestore` 는 그 큐잉 자체를 흉내 내지 못하므로(동기 대역),
    // 여기서는 `FirebaseFirestore`/`DocumentReference` 자리에 직접 스파이를
    // 끼워 "무엇이 불렸는가"를 재고, [_WriteSpyFirestore.gate] 로 "아직 서버에
    // 닿지 못한 구간"을 만들어 그 구간에서 오류 없이 기다리다가 복구되면
    // 끝난다는 것을 잰다.
    const like = LikeWrite(
      placeId: 'jamsil-noodle-house',
      stadiumId: 'jamsil',
      category: PlaceCategory.food,
    );

    test('addLike·removeLike 는 set·delete 로 가고 트랜잭션·update 를 타지 않는다', () async {
      final db = _WriteSpyFirestore();
      final store = FirestoreUserDataStore(db);

      await store.addLike('u1', like);
      await store.removeLike('u1', like.documentId);

      // update 나 runTransaction 을 타는 변이는 db 에 구현되지 않은 메서드를
      // 불러 noSuchMethod 가 던지고, guardBackend 가 그것을 감싸 던지므로 이
      // 시험이 그 자리에서 빨간불이 된다.
      expect(db.calls, [
        'set:jamsil-noodle-house',
        'delete:jamsil-noodle-house',
      ]);
    });

    test('쓰기가 아직 서버에 닿지 못해도(오프라인 큐 대역) 오류 없이 기다리다가 복구되면 끝난다', () async {
      final gate = Completer<void>();
      final db = _WriteSpyFirestore(gate: gate);
      final store = FirestoreUserDataStore(db);

      var settled = false;
      final write = store.addLike('u1', like).then((_) => settled = true);
      await pumpEventQueue();
      expect(settled, isFalse, reason: '서버 왕복 전이라 아직 끝나지 않아야 재현이 된다');

      gate.complete(); // "복구" — 큐에 있던 쓰기가 이제 나간다.
      await write;
      expect(settled, isTrue);
    });
  });

  _snapshotSourceTests();
}

/// Firestore 스파이 — 좋아요 쓰기가 실제로 어떤 메서드를 부르는지 기록한다.
///
/// [DocumentReference.update] 와 [FirebaseFirestore.runTransaction] 은 일부러
/// 구현하지 않는다 — 좋아요 경로가 그 쪽으로 새면 `noSuchMethod` 가 곧바로
/// 던져서 위 시험이 그 자리에서 드러낸다.
class _WriteSpyFirestore implements FirebaseFirestore {
  _WriteSpyFirestore({this.gate});

  /// null 이 아니면 [_SpyLikeDoc.set]/[_SpyLikeDoc.delete] 가 이 완료를
  /// 기다린 뒤에야 끝난다 — "쓰기가 아직 서버에 닿지 못한 구간"의 대역이다.
  final Completer<void>? gate;

  /// 불린 순서 — `'set:<id>'` / `'delete:<id>'`.
  final List<String> calls = [];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _SpyCollection(this, collectionPath);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _SpyCollection implements CollectionReference<Map<String, dynamic>> {
  _SpyCollection(this._db, this._path);

  final _WriteSpyFirestore _db;
  final String _path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    if (_path == kUsersCollection) return _SpyUserDoc(_db);
    return _SpyLikeDoc(_db, path!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _SpyUserDoc implements DocumentReference<Map<String, dynamic>> {
  _SpyUserDoc(this._db);

  final _WriteSpyFirestore _db;

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _SpyCollection(_db, collectionPath);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _SpyLikeDoc implements DocumentReference<Map<String, dynamic>> {
  _SpyLikeDoc(this._db, this.id);

  final _WriteSpyFirestore _db;

  @override
  final String id;

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    _db.calls.add('set:$id');
    final gate = _db.gate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> delete() async {
    _db.calls.add('delete:$id');
    final gate = _db.gate;
    if (gate != null) await gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 오프라인 지속성이 켜진 실 SDK 는 스냅샷을 **로컬 캐시에서 먼저** 흘린다.
/// 기기를 바꾼 사람의 로컬 캐시에는 그 문서가 없으므로, 서버 왕복 전에
/// "문서 없음" 스냅샷이 먼저 온다 — 그것을 답으로 받으면 이미 팀을 고른
/// 사람이 온보딩을 보고, 거기서 팀을 누르면 자기 팀을 바꾸게 된다.
///
/// **그 순서 자체는 `fake_cloud_firestore` 로 재현되지 않는다.** 그 대역의
/// `snapshots()` 는 언제나 `isFromCache: false` 를 실어 보내고(4.2.0 의
/// `MockDocumentReference.snapshots` → `_getSync()` 를 인수 없이 부른다),
/// 출처가 캐시인 스냅샷은 `get(GetOptions(source: Source.cache))` 로만 얻을 수
/// 있다. 그래서 여기서는 그 읽기로 **네 조합의 실제 스냅샷**을 만들어 출처를
/// 읽는 술어([tellsProfileExistence])를 직접 돌리고, 붙잡아 두는 변환
/// ([awaitServerConfirmation])은 평범한 스트림으로 따로 돌린다. 둘을 엮은
/// `watchProfile` 의 조합은 실기기와 에뮬레이터가 재는 몫으로 남는다.
void _snapshotSourceTests() {
  group('로컬 캐시만 보고 말하는 "문서 없음"은 아직 답이 아니다', () {
    late FakeFirebaseFirestore db;

    setUp(() => db = FakeFirebaseFirestore());

    Future<DocumentSnapshot<Map<String, dynamic>>> snapshot(
      String id, {
      required bool fromCache,
    }) => db
        .collection(kUsersCollection)
        .doc(id)
        .get(fromCache ? const GetOptions(source: Source.cache) : null);

    test('출처와 존재의 네 조합', () async {
      await db.collection(kUsersCollection).doc('있는사람').set(<String, Object?>{
        UserFields.favoriteTeamId: 'lg',
      });

      // 있는 문서는 어디서 왔든 답이다 — 로컬 캐시에 있다는 것은 이 기기가
      // 전에 그 문서를 받았다는 뜻이라 이 계정 자신의 데이터다.
      expect(
        tellsProfileExistence(await snapshot('있는사람', fromCache: true)),
        isTrue,
      );
      expect(
        tellsProfileExistence(await snapshot('있는사람', fromCache: false)),
        isTrue,
      );
      // 서버가 확인해 준 "없음"은 답이다.
      expect(
        tellsProfileExistence(await snapshot('없는사람', fromCache: false)),
        isTrue,
      );
      // 로컬 캐시만 보고 말하는 "없음"은 답이 아니다 — 기기를 바꾼 사람의
      // 캐시에는 서버에 있는 문서도 없다.
      expect(
        tellsProfileExistence(await snapshot('없는사람', fromCache: true)),
        isFalse,
        reason: '이 한 조합을 답으로 받으면 이미 팀을 고른 사람이 온보딩으로 내려간다',
      );
    });
  });

  group('답이 아닌 스냅샷은 상한까지 붙잡아 둔다', () {
    test('확인된 값이 뒤이어 오면 붙잡아 둔 것은 버린다', () async {
      final source = StreamController<String>();
      addTearDown(source.close);
      final seen = <String>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
      ).listen(seen.add);
      addTearDown(subscription.cancel);

      source.add('모름');
      await pumpEventQueue();
      expect(seen, isEmpty, reason: '답이 아닌 값이 그대로 흘렀다');

      source.add('lg');
      await pumpEventQueue();
      expect(seen, ['lg']);
    });

    test('상한을 넘도록 확인이 오지 않으면 붙잡아 둔 것을 내보낸다', () async {
      final source = StreamController<String>();
      addTearDown(source.close);
      final seen = <String>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(milliseconds: 20),
      ).listen(seen.add);
      addTearDown(subscription.cancel);

      source.add('모름');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      // 영영 답하지 않는 실행이 사람을 대기 화면에 가두지 않는다.
      expect(seen, ['모름']);
    });

    test('오류는 붙잡지 않는다 — 그 자체가 답이다', () async {
      final source = StreamController<String>();
      addTearDown(source.close);
      final errors = <Object>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
      ).listen((_) {}, onError: errors.add);
      addTearDown(subscription.cancel);

      source.add('모름');
      source.addError(StateError('끊겼다'));
      await pumpEventQueue();

      expect(errors, hasLength(1));
    });

    test('오류를 받은 뒤에 온 값은 붙잡지 않고 그대로 흘린다', () async {
      // 오류도 답이므로 상한은 거기서 끝난다. 오류를 받고도 "아직 답이 없다"로
      // 남으면, 그 뒤에 온 답 아닌 값이 상한의 여러 배가 지나도 나오지 않는
      // 구간이 생긴다 — 상한 없는 기다림이고, 그것이 이 장치가 막으려던 바로
      // 그 상태다.
      final source = StreamController<String>();
      addTearDown(source.close);
      final seen = <String>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(milliseconds: 20),
      ).listen(seen.add, onError: (Object _) {});
      addTearDown(subscription.cancel);

      source.add('모름');
      source.addError(StateError('끊겼다'));
      await pumpEventQueue();

      source.add('모름');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(seen, ['모름'], reason: '오류 뒤로는 상한을 다시 세우지 않아 값이 영영 나오지 않는다');
    });

    test('오류 뒤에 스트림이 닫혀도 붙잡아 둔 값은 답이 되지 않는다', () async {
      // 실 Firestore 의 스냅샷 스트림은 오류와 함께 닫힌다. 그때 붙잡아 둔
      // 값(= 아직 확인받지 못한 "문서 없음")을 마저 내보내면, 확인받을 길이
      // 사라진 값이 답으로 승격되어 위 계층의 "서버를 읽지 못했다" 갈래를
      // "서버가 없다고 답했다"로 바꿔 놓는다.
      final source = StreamController<String>();
      final seen = <String>[];
      final errors = <Object>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
      ).listen(seen.add, onError: errors.add);
      addTearDown(subscription.cancel);

      source.add('모름');
      source.addError(StateError('끊겼다'));
      await source.close();
      await pumpEventQueue();

      expect(errors, hasLength(1));
      expect(seen, isEmpty, reason: '확인받지 못한 값이 오류 뒤에 답으로 나왔다');
    });
  });
}
