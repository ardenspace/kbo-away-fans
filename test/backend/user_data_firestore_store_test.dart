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
          UserFields.defaultThemeFamily: 'b',
          UserFields.brightnessPreference: 'dark',
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
          defaultThemeFamily: DefaultThemeFamily.b,
          brightnessPreference: BrightnessPreference.light,
        ),
      );

      expect(created, isTrue);
      // readProfile 이 언제나 null 을 돌려주는 변이가 여기서 빨간불이 된다.
      final profile = await store.readProfile(uid);
      expect(profile, isNotNull);
      expect(profile!.favoriteTeamId, 'hanwha');
      expect(profile.defaultThemeFamily, DefaultThemeFamily.b);
      expect(profile.brightnessPreference, BrightnessPreference.light);
      expect(profile.nickname, '원정러');
      expect(profile.board, isEmpty);
      // 서버 시각 센티널이 실제 시각으로 확정된다.
      expect(profile.joinedAt, isA<DateTime>());
    });

    test('사이클 3 이전 문서는 팀 없음과 A/auto로 호환해 읽는다', () async {
      await db
          .collection(kUsersCollection)
          .doc(uid)
          .set(
            encodeBackendValues(<String, Object?>{
              UserFields.nickname: '기존사용자',
              UserFields.joinedAt: ExactTimestamp(joinedAt),
              UserFields.board: <String, Object?>{},
            }),
          );

      final profile = (await store.readProfile(uid))!;
      expect(profile.favoriteTeamId, isNull);
      expect(profile.defaultThemeFamily, DefaultThemeFamily.a);
      expect(profile.brightnessPreference, BrightnessPreference.auto);
    });

    test('이미 있는 문서는 덮지 않는다 — 가입 시각과 배지 판이 남는다', () async {
      await seedDocument('lg');

      final created = await store.createProfile(
        uid,
        const NewUserProfile(nickname: '나중닉', favoriteTeamId: 'kia'),
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
        const UserProfilePatch(
          favoriteTeamId: 'kt',
          defaultThemeFamily: DefaultThemeFamily.a,
          brightnessPreference: BrightnessPreference.auto,
        ),
      );

      // update 를 set 으로 바꾸는 변이가 여기서 빨간불이 된다 — set 은 문서를
      // 통째로 덮으므로 닉네임·가입 시각·배지 판이 사라지고, 실물에서는 그
      // 쓰기가 규칙의 hasAll 에 걸려 팀 변경 자체가 실패한다.
      final profile = (await store.readProfile(uid))!;
      expect(profile.favoriteTeamId, 'kt');
      expect(profile.defaultThemeFamily, DefaultThemeFamily.a);
      expect(profile.brightnessPreference, BrightnessPreference.auto);
      expect(profile.nickname, '먼저있던닉');
      expect(profile.joinedAt, joinedAt);
      expect(profile.board['jamsil_lg']!.count, 2);
      expect(profile.updatedAt, isNotNull);
    });

    test('응원팀을 null로 바꿀 수 있다', () async {
      await seedDocument('lg');

      await store.patchProfile(
        uid,
        const UserProfilePatch(favoriteTeamId: null),
      );

      expect((await store.readProfile(uid))!.favoriteTeamId, isNull);
    });

    test('나가는 문서에는 계약 밖 필드가 없다', () async {
      await store.createProfile(
        uid,
        const NewUserProfile(nickname: '원정러', favoriteTeamId: 'nc'),
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
        const NewUserProfile(nickname: '원정러', favoriteTeamId: 'ssg'),
      );
      await pumpEventQueue();

      expect(seen.last, 'ssg');
    });
  });

  group('도장 쓰기 — 문서와 칸 요약이 한 배치로 간다 (4.2)', () {
    const stamp = StampWrite(
      stadiumId: 'jamsil',
      gameId: 'g-jamsil-1',
      homeTeamId: 'lg',
      gameDate: '2026-08-25',
    );

    Future<Map<String, Object?>?> rawStamp(String id) async {
      final snapshot = await db
          .collection(kUsersCollection)
          .doc(uid)
          .collection(kStampsCollection)
          .doc(id)
          .get();
      final data = snapshot.data();
      return data == null ? null : decodeBackendValues(data);
    }

    test('새 도장은 문서와 그 칸의 요약을 함께 남긴다', () async {
      await seedDocument('lg'); // jamsil_lg 는 이미 2개다

      final receipt = await store.writeStamp(uid, stamp);
      expect(receipt.outcome, StampWriteOutcome.created);
      // 이 대역(`fake_cloud_firestore`)은 실 SDK 와 달리 커밋을 로컬에 곧바로
      // 반영하지 않는다 — 무엇이 **남았는지**를 재려면 서버 확인까지 기다린다.
      await receipt.serverConfirmed;

      final written = await rawStamp('jamsil_g-jamsil-1');
      expect(written, isNotNull);
      expect(written!.keys.toSet(), StampFields.all);
      expect(written[StampFields.homeTeamId], 'lg');

      final board =
          (await rawDocument())[UserFields.board]! as Map<String, Object?>;
      final cell = BoardCell.fromData(
        (board['jamsil_lg']! as Map).cast<String, Object?>(),
      );
      expect(cell.count, 3, reason: '있던 2개에 하나가 얹힌다');
      expect(cell.tier, BadgeTier.regular);
      expect(cell.lastStampedOn, '2026-08-25');
    });

    test('같은 경기를 다시 써도 개수가 오르지 않는다', () async {
      await seedDocument('lg');
      await (await store.writeStamp(uid, stamp)).serverConfirmed;

      expect(
        (await store.writeStamp(uid, stamp)).outcome,
        StampWriteOutcome.alreadyStamped,
      );

      final board =
          (await rawDocument())[UserFields.board]! as Map<String, Object?>;
      expect(
        BoardCell.fromData(
          (board['jamsil_lg']! as Map).cast<String, Object?>(),
        ).count,
        3,
      );
    });

    test('도장이 없던 칸은 첫 도장에서 count 1 로 생긴다', () async {
      await seedDocument('lg');

      await (await store.writeStamp(
        uid,
        const StampWrite(
          stadiumId: 'sajik',
          gameId: 'g-sajik-1',
          homeTeamId: 'lotte',
          gameDate: '2026-08-26',
        ),
      )).serverConfirmed;

      final board =
          (await rawDocument())[UserFields.board]! as Map<String, Object?>;
      expect(board.keys, unorderedEquals(<String>['jamsil_lg', 'sajik_lotte']));
      expect(
        BoardCell.fromData(
          (board['sajik_lotte']! as Map).cast<String, Object?>(),
        ).count,
        1,
      );
    });
  });

  group('도장 쓰기 경로 — 오프라인 큐잉의 전제 (4.2)', () {
    // 이 단계가 `runTransaction` 을 **의도적으로 피한** 자리다: 트랜잭션은
    // 서버에 닿아야 끝나므로 통신이 없는 구장에서는 완료되지 않는다. 그
    // 선택은 `fake_cloud_firestore` 로는 지켜지지 않는다 — 그 대역은
    // 트랜잭션도 멀쩡히 돌려주므로, 구현을 트랜잭션으로 되돌려도 위 그룹이
    // 전부 초록불이다. 그래서 여기서는 스파이를 끼워 **무엇이 불렸는지**를
    // 재고(`runTransaction` 은 스파이에 없어서 곧바로 던진다), 아직 서버에
    // 닿지 못한 구간에서 오류 없이 기다리다 복구되면 끝난다는 것을 잰다.
    const stamp = StampWrite(
      stadiumId: 'jamsil',
      gameId: 'g-jamsil-1',
      homeTeamId: 'lg',
      gameDate: '2026-08-25',
    );

    Map<String, dynamic> userData() => <String, dynamic>{
      UserFields.nickname: '원정러',
      UserFields.favoriteTeamId: 'lg',
      UserFields.defaultThemeFamily: 'a',
      UserFields.brightnessPreference: 'auto',
      UserFields.joinedAt: Timestamp.fromDate(joinedAt),
      UserFields.board: <String, dynamic>{},
    };

    test('도장 쓰기는 배치로 가고 트랜잭션을 타지 않는다', () async {
      final db = _WriteSpyFirestore(userData: userData());
      final store = FirestoreUserDataStore(db);

      await store.writeStamp(uid, stamp);

      expect(db.calls, [
        'get:jamsil_g-jamsil-1',
        'get:$uid',
        'batch',
        'batch.set:jamsil_g-jamsil-1',
        'batch.update:$uid',
        'batch.commit',
      ]);
    });

    test('이미 있는 도장이면 사용자 문서를 읽지도, 배치를 열지도 않는다', () async {
      final db = _WriteSpyFirestore(
        userData: userData(),
        stampData: <String, dynamic>{StampFields.stadiumId: 'jamsil'},
      );
      final store = FirestoreUserDataStore(db);

      expect(
        (await store.writeStamp(uid, stamp)).outcome,
        StampWriteOutcome.alreadyStamped,
      );
      expect(db.calls, ['get:jamsil_g-jamsil-1']);
    });

    test('쓰기는 배치를 큐에 넣은 순간 끝나고 서버 확인만 복구를 기다린다', () async {
      // 이 두 순간을 Future 하나로 겸하던 자리가 phase 4 통합 검증의 REJECT
      // 사유였다 — 오프라인 구장에서 도장은 확정됐는데 연출(4.4)이 통신
      // 복구까지 뜨지 않았다. 이제 `writeStamp` 는 앞엣것에서 끝나고 뒤엣것은
      // `serverConfirmed` 가 나른다.
      final gate = Completer<void>();
      final db = _WriteSpyFirestore(userData: userData(), gate: gate);
      final store = FirestoreUserDataStore(db);

      final receipt = await store.writeStamp(uid, stamp);

      expect(receipt.outcome, StampWriteOutcome.created);
      expect(
        db.calls,
        contains('batch.commit'),
        reason: '존재 확인이 오프라인에서 던져도 배치는 큐에 들어가야 한다',
      );

      var confirmed = false;
      unawaited(receipt.serverConfirmed.then((_) => confirmed = true));
      await pumpEventQueue();
      expect(confirmed, isFalse, reason: '서버 왕복 전이라 확인은 아직 오지 않는다');

      gate.complete(); // "복구" — 큐에 있던 배치가 이제 나간다.
      await receipt.serverConfirmed;
      expect(confirmed, isTrue);
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

/// Firestore 스파이 — 좋아요·도장 쓰기가 실제로 어떤 메서드를 부르는지
/// 기록한다.
///
/// [DocumentReference.update] 와 [FirebaseFirestore.runTransaction] 은 일부러
/// 구현하지 않는다 — 두 쓰기 경로가 그 쪽으로 새면 `noSuchMethod` 가 곧바로
/// 던져서 위 시험이 그 자리에서 드러낸다. 그 둘이 오프라인에서 완료되지 않는
/// 호출이라, "구장에서 오프라인으로 쓰는 경로"의 계약이 곧 이 미구현이다.
///
/// 읽기는 [userData]·[stampData] 로 시험이 정한다 — 도장 쓰기가 개수를 세러
/// 두 문서를 먼저 읽기 때문이다.
class _WriteSpyFirestore implements FirebaseFirestore {
  _WriteSpyFirestore({this.gate, this.userData, this.stampData});

  /// null 이 아니면 **통신이 아직 없다** — 쓰기(좋아요의 `set`·`delete`, 도장
  /// 배치의 `commit`)는 이 완료를 기다린 뒤에야 끝나고, **읽기는 캐시에 없는
  /// 문서에서 곧바로 `unavailable` 로 던진다.**
  ///
  /// 뒤엣것이 없으면 이 대역이 재는 것은 오프라인이 아니라 "쓰기가 느린
  /// 온라인"이다 — 실 SDK 는 오프라인에서 캐시에 없는 문서를 읽으면 스냅샷
  /// 대신 던지고(에뮬레이터 실측), 오프라인에서 찍는 첫 도장이 정확히 그
  /// 갈래다. 그 갈래만 따로 재는 자리는 `stamp_write_offline_test.dart` 다.
  final Completer<void>? gate;

  /// `users/{uid}` 문서의 내용 (null 이면 문서 없음).
  final Map<String, dynamic>? userData;

  /// 도장 문서의 내용 (null 이면 아직 없는 도장).
  final Map<String, dynamic>? stampData;

  /// 불린 순서 — `'get:<id>'` / `'set:<id>'` / `'delete:<id>'` /
  /// `'batch'` / `'batch.set:<id>'` / `'batch.update:<id>'` / `'batch.commit'`.
  final List<String> calls = [];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _SpyCollection(this, collectionPath);

  @override
  WriteBatch batch() {
    calls.add('batch');
    return _SpyBatch(this);
  }

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
    if (_path == kUsersCollection) return _SpyUserDoc(_db, path!);
    if (_path == kStampsCollection) return _SpyDoc(_db, path!, _db.stampData);
    return _SpyDoc(_db, path!, null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _SpyUserDoc extends _SpyDoc {
  _SpyUserDoc(_WriteSpyFirestore db, String id) : super(db, id, db.userData);

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) =>
      _SpyCollection(db, collectionPath);
}

// ignore: subtype_of_sealed_class
class _SpyDoc implements DocumentReference<Map<String, dynamic>> {
  _SpyDoc(this.db, this.id, this._data);

  final _WriteSpyFirestore db;
  final Map<String, dynamic>? _data;

  @override
  final String id;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    db.calls.add('get:$id');
    final gate = db.gate;
    if (gate != null && !gate.isCompleted && _data == null) {
      // 오프라인 + 캐시에 없는 문서 — 실 SDK 가 스냅샷 대신 던지는 자리.
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
        message: 'Failed to get document because the client is offline.',
      );
    }
    return _SpySnapshot(_data);
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    db.calls.add('set:$id');
    final gate = db.gate;
    if (gate != null) await gate.future;
  }

  @override
  Future<void> delete() async {
    db.calls.add('delete:$id');
    final gate = db.gate;
    if (gate != null) await gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _SpySnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  _SpySnapshot(this._data);

  final Map<String, dynamic>? _data;

  @override
  bool get exists => _data != null;

  @override
  Map<String, dynamic>? data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyBatch implements WriteBatch {
  _SpyBatch(this._db);

  final _WriteSpyFirestore _db;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _db.calls.add('batch.set:${document.id}');

  @override
  void update<T>(DocumentReference<T> document, T data) =>
      _db.calls.add('batch.update:${document.id}');

  @override
  Future<void> commit() async {
    _db.calls.add('batch.commit');
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
