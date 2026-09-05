/// Step 4.2 경계 시험 — **오프라인에서 찍는 첫 도장**.
///
/// 계약의 acceptance criterion 셋째: "오프라인에서 찍은 도장이 복구 후 한 번만
/// 올라간다."
///
/// **왜 이 파일이 따로 있는가.** 이 갈래를 재려면 Firestore 가 오프라인에서
/// 하는 일을 SDK 자리에 그대로 놓아야 하는데, 그 거동이 읽기와 쓰기에서
/// 다르다. 쓰기(`set`·`update`·배치의 `commit`)는 로컬 큐에 쌓였다가 복구
/// 뒤에 나가지만, **읽기는 캐시에 없는 문서를 물으면 스냅샷 대신 던진다**:
///
/// ```text
/// 없는 문서 get 던짐: code=unavailable / Failed to get document because the client is offline.
/// 있는 문서 get: exists=true fromCache=true
/// 오프라인에서 commit 완료? false
/// 큐에 넣은 뒤 get: exists=true fromCache=true
/// ```
///
/// (에뮬레이터 실측 — `firebase/test/helpers.mjs` 의 하네스로 띄운 8791 포트에
/// `disableNetwork()` 를 걸고 잰 네 줄이며, 이 시험을 쓰면서 다시 재현했다.)
///
/// 그래서 **첫 도장만** 그 갈래에 든다. 두 번째 판정부터는 큐에 넣은 쓰기가
/// 캐시에 이미 반영돼 있어 읽기가 답한다. 이 파일은 그 거동을 SDK 자리에 놓고
/// [FirestoreUserDataStore.writeStamp] 가 무엇을 하는지 잰다.
///
/// **짝 파일:** 같은 쓰기 경로를 온라인에서 재는 자리는
/// `test/backend/user_data_firestore_store_test.dart` 의 "도장 쓰기 경로"
/// 그룹이고, 앱 계층(판정 → 도장)은 `test/backend/stamp_write_test.dart` 다.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';

void main() {
  const uid = 'kakao:1234567890';
  const stamp = StampWrite(
    stadiumId: 'jamsil',
    gameId: 'g-jamsil-1',
    homeTeamId: 'lg',
    gameDate: '2026-08-25',
  );

  Map<String, dynamic> userData({Map<String, dynamic>? board}) =>
      <String, dynamic>{
        UserFields.nickname: '원정러',
        UserFields.favoriteTeamId: 'lg',
        UserFields.profileThemeKey: 'lg',
        UserFields.joinedAt: Timestamp.fromDate(DateTime.utc(2026, 3, 1)),
        UserFields.board: board ?? <String, dynamic>{},
      };

  test('오프라인에서 찍는 첫 도장이 배치로 큐에 들어간다', () async {
    final db = _OfflineSpyFirestore(userData: userData());
    final store = FirestoreUserDataStore(db);

    expect(
      (await store.writeStamp(uid, stamp)).outcome,
      StampWriteOutcome.created,
    );

    expect(db.calls, [
      // 존재 확인은 던졌지만(캐시에 없는 문서) 거기서 끝나지 않았다.
      'get:jamsil_g-jamsil-1',
      // 사용자 문서는 캐시가 답한다 — 개수를 셀 수 있다.
      'get:$uid',
      'batch',
      'batch.set:jamsil_g-jamsil-1',
      'batch.update:$uid',
      'batch.commit',
    ]);
  });

  test('오프라인에서 센 개수는 캐시의 사용자 문서를 따른다', () async {
    final db = _OfflineSpyFirestore(
      userData: userData(
        board: <String, dynamic>{
          'jamsil_lg': <String, dynamic>{
            BoardCellFields.count: 2,
            BoardCellFields.tier: 'first',
            BoardCellFields.lastStampedOn: '2026-08-01',
          },
        },
      ),
    );
    final store = FirestoreUserDataStore(db);

    await store.writeStamp(uid, stamp);

    final cell = BoardCell.fromData(
      (db.boardPatch!['board.jamsil_lg']! as Map).cast<String, Object?>(),
    );
    expect(cell.count, 3, reason: '캐시에 있던 2개에 하나가 얹힌다');
    expect(cell.lastStampedOn, '2026-08-25');
  });

  test('오프라인에서 같은 경기를 다시 쓰면 캐시가 답해 아무것도 쓰지 않는다', () async {
    // 첫 쓰기를 큐에 넣은 **뒤**의 모습 — SDK 는 큐에 든 쓰기를 캐시에 이미
    // 반영해 두므로 여기서부터는 읽기가 던지지 않는다.
    final db = _OfflineSpyFirestore(
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

  test('읽기가 통신이 아닌 이유로 실패하면 도장을 쓰지 않고 그대로 던진다', () async {
    // 규칙 거부는 "모르겠다"가 아니라 "쓸 수 없다"이다 — 이것까지 없는 도장으로
    // 접으면, 남의 문서를 향한 쓰기가 조용히 큐에 쌓인다.
    final db = _OfflineSpyFirestore(
      userData: userData(),
      readFailureCode: 'permission-denied',
    );
    final store = FirestoreUserDataStore(db);

    await expectLater(
      store.writeStamp(uid, stamp),
      throwsA(isA<BackendPermissionError>()),
    );
    expect(db.calls, ['get:jamsil_g-jamsil-1']);
  });

  test('사용자 문서마저 캐시에 없으면 도장을 쓰지 못하고 네트워크 오류로 끝난다', () async {
    // 이 갈래는 남긴다 — 개수를 셀 근거가 없으면 요약을 지어낼 수 없다.
    // 도장은 다음 트리거가 다시 시도한다(`StampAward` 가 기억을 되돌린다).
    final db = _OfflineSpyFirestore(userData: null);
    final store = FirestoreUserDataStore(db);

    await expectLater(
      store.writeStamp(uid, stamp),
      throwsA(isA<BackendNetworkError>()),
    );
    expect(
      db.calls.where((call) => call.startsWith('batch')),
      isEmpty,
      reason: '개수를 모르는 채로 요약을 쓰지 않는다',
    );
  });
}

/// 오프라인 Firestore 의 실제 거동 — **있는 문서는 캐시가 답하고, 없는 문서는
/// 던진다.**
///
/// [readFailureCode] 로 던지는 코드를 바꿀 수 있다 — 통신이 아닌 실패(규칙
/// 거부)가 같은 자리를 지날 때 무엇이 달라지는지를 재기 위해서다.
class _OfflineSpyFirestore implements FirebaseFirestore {
  _OfflineSpyFirestore({
    required this.userData,
    this.stampData,
    this.readFailureCode = 'unavailable',
  });

  /// `users/{uid}` 문서 — null 이면 이 기기 캐시에 없다.
  final Map<String, dynamic>? userData;

  /// 도장 문서 — null 이면 이 기기 캐시에 없다(= 읽기가 던지는 갈래).
  final Map<String, dynamic>? stampData;

  /// 캐시에 없는 문서를 읽었을 때 SDK 가 던지는 코드.
  final String readFailureCode;

  final List<String> calls = [];

  /// 배치가 사용자 문서에 얹은 칸 요약 payload.
  Map<String, Object?>? boardPatch;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _SpyCollection(this, path);

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

  final _OfflineSpyFirestore _db;
  final String _path;

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _path == kUsersCollection
      ? _SpyUserDoc(_db, path!)
      : _SpyDoc(_db, path!, _db.stampData);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
class _SpyUserDoc extends _SpyDoc {
  _SpyUserDoc(_OfflineSpyFirestore db, String id) : super(db, id, db.userData);

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _SpyCollection(db, path);
}

// ignore: subtype_of_sealed_class
class _SpyDoc implements DocumentReference<Map<String, dynamic>> {
  _SpyDoc(this.db, this.id, this._data);

  final _OfflineSpyFirestore db;
  final Map<String, dynamic>? _data;

  @override
  final String id;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    db.calls.add('get:$id');
    if (_data == null) {
      // 오프라인 + 캐시에 없는 문서 = SDK 가 스냅샷 대신 던지는 자리.
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: db.readFailureCode,
        message: 'Failed to get document because the client is offline.',
      );
    }
    return _SpySnapshot(_data);
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

  final _OfflineSpyFirestore _db;

  @override
  void set<T>(DocumentReference<T> document, T data, [SetOptions? options]) =>
      _db.calls.add('batch.set:${document.id}');

  @override
  void update<T>(DocumentReference<T> document, T data) {
    _db.calls.add('batch.update:${document.id}');
    _db.boardPatch = (data as Map).cast<String, Object?>();
  }

  @override
  Future<void> commit() async => _db.calls.add('batch.commit');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
