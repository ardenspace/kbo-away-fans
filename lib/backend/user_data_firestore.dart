/// 사용자 데이터 계층의 실제 구현 — Cloud Firestore 위의 [UserDataStore].
///
/// `user_data.dart` 가 계약(타입)이고 이 파일이 그 계약의 몸이다. 인증에서
/// `auth.dart`/`auth_firebase.dart` 를 나눈 것과 같은 까닭이다: 계약을 읽는
/// 사람이 SDK 사정을 함께 읽지 않아도 되고, `cloud_firestore` import 가 이 한
/// 파일에만 있으면 SDK 를 바꿀 때 볼 자리도 하나다.
///
/// 이 파일이 지는 몫은 셋이다.
///
///  1) **어댑터** — 계약의 [BackendTimestamp] 를 SDK 의 시각 표현으로,
///     SDK 의 [Timestamp] 를 [DateTime] 으로 옮긴다
///     ([encodeBackendValues]·[decodeBackendValues]). 이 옮김이 어긋나면
///     규칙(`joinedAt is timestamp`)이 쓰기를 거부하는데 그 실패는 실기기에서만
///     보이므로, 두 함수는 순수 함수로 두어 단위 테스트가 직접 잰다.
///  2) **경로** — `users/{uid}` 와 그 하위 컬렉션 둘. 문서 id 는 write 타입이
///     짓는다(`docs/firestore-schema.md` 의 결정적 id 규약).
///  3) **오류 봉투** — SDK 예외가 이 파일 밖으로 나가지 않게 모든 호출을
///     `guardBackend`/`guardBackendStream` 으로 감싼다.
///
/// 계약 위반(`toData()` 의 [ArgumentError])은 감싸지 않는다 — 그것은 서버에
/// 닿기 전에 드러나는 프로그래밍 오류이고, 도메인 오류로 옮기면 "네트워크·권한·
/// 알 수 없음" 셋 중 어느 것도 아닌 실패가 `unknown` 아래로 숨는다.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'auth_firebase.dart' show kFirebaseUnconfiguredCode;
import 'errors.dart';
import 'user_data.dart';

/// 최상위 컬렉션 — 사용자 데이터는 전부 이 아래에 산다.
const String kUsersCollection = 'users';

/// 도장 하위 컬렉션.
const String kStampsCollection = 'stamps';

/// 좋아요 하위 컬렉션.
const String kLikesCollection = 'likes';

/// Firestore 위의 사용자 데이터 구현 — 앱이 실제로 쓰는 [UserDataStore].
class FirestoreUserDataStore implements UserDataStore {
  FirestoreUserDataStore(this._db);

  static FirestoreUserDataStore? _instance;

  /// 연결된 저장소. Firebase 설정이 없는 실행에서는 [BackendUnknownError] 로
  /// 던진다 — 인증(`FirebaseAuthService.instance`)과 같은 코드이고 같은
  /// 판단이다: 조용한 no-op 저장소를 기본값으로 두면 설정을 빠뜨린 실행이
  /// "데이터가 없는 사람"처럼 멀쩡히 돌아 실수가 드러나지 않는다.
  ///
  /// `Firebase.apps` 로 재는 것은 이 getter 가 `main` 의 초기화보다 먼저 불릴
  /// 수 있기 때문이다(테스트가 그렇다). 앱을 세우는 자리는 인증 쪽
  /// `ensureInitialized` 하나이고, 여기서는 그 결과만 읽는다.
  static UserDataStore get instance {
    if (Firebase.apps.isEmpty) {
      throw const BackendUnknownError(code: kFirebaseUnconfiguredCode);
    }
    return _instance ??= FirestoreUserDataStore(FirebaseFirestore.instance);
  }

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection(kUsersCollection).doc(uid);

  UserProfile? _profileOf(
    String uid,
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    return UserProfile.fromData(uid: uid, data: decodeBackendValues(data));
  }

  @override
  Future<UserProfile?> readProfile(String uid) =>
      guardBackend(() async => _profileOf(uid, await _userDoc(uid).get()));

  @override
  Stream<UserProfile?> watchProfile(String uid) => guardBackendStream(
        _userDoc(uid).snapshots().map((snapshot) => _profileOf(uid, snapshot)),
      );

  /// 첫 문서를 만든다 — **이미 있으면 아무것도 하지 않고 false 를 돌려준다.**
  ///
  /// 돌려주는 값은 계약이 정한 그대로다(`user_data.dart`): 아무것도 하지
  /// 않았다는 사실을 호출자가 알아야 마지막 선택이 조용히 사라지지 않는다.
  ///
  /// 트랜잭션으로 "있는지 보고 없으면 쓴다"를 한 걸음으로 묶는 것은, 재로그인이
  /// 가입 시각과 배지 판을 지우는 일이 이 한 줄에 걸려 있기 때문이다. `set` 은
  /// 문서를 통째로 덮으므로, 존재 확인과 쓰기가 갈라져 있으면 두 기기가 거의
  /// 동시에 첫 로그인을 마쳤을 때 뒤엣것이 앞엣것을 지운다.
  ///
  /// 트랜잭션은 서버에 닿아야 끝난다(오프라인에서 완료되지 않는다). 첫 문서를
  /// 만드는 시점은 로그인 직후라 이미 통신이 필요한 자리이므로 그 제약을
  /// 받아들인다 — 도장·좋아요처럼 구장에서 오프라인으로 쓰는 경로에는 이
  /// 방식을 쓰지 않는다.
  @override
  Future<bool> createProfile(String uid, NewUserProfile profile) {
    final data = encodeBackendValues(profile.toData());
    return guardBackend(
      () => _db.runTransaction<bool>((transaction) async {
        final reference = _userDoc(uid);
        final snapshot = await transaction.get(reference);
        if (snapshot.exists) return false;
        transaction.set(reference, data);
        return true;
      }),
    );
  }

  @override
  Future<void> patchProfile(String uid, UserProfilePatch patch) {
    final data = encodeBackendValues(patch.toData());
    return guardBackend(() => _userDoc(uid).update(data));
  }

  @override
  Future<List<StampRecord>> readStamps(String uid, {String? cellId}) {
    // 칸 상세는 그 칸의 도장만 최신순으로 읽는다 — 복합 인덱스
    // (stadiumId, homeTeamId, gameDate ↓) 가 firestore.indexes.json 에 있다.
    Query<Map<String, dynamic>> query =
        _userDoc(uid).collection(kStampsCollection);
    if (cellId != null) {
      query = query
          .where(StampFields.stadiumId, isEqualTo: boardCellStadiumId(cellId))
          .where(StampFields.homeTeamId, isEqualTo: boardCellTeamId(cellId));
    }
    return guardBackend(() async {
      final snapshot =
          await query.orderBy(StampFields.gameDate, descending: true).get();
      return [
        for (final document in snapshot.docs)
          StampRecord.fromData(
            id: document.id,
            data: decodeBackendValues(document.data()),
          ),
      ];
    });
  }

  @override
  Future<void> writeStamp(String uid, StampWrite stamp) {
    final data = encodeBackendValues(stamp.toData());
    return guardBackend(
      () => _userDoc(uid)
          .collection(kStampsCollection)
          .doc(stamp.documentId)
          .set(data),
    );
  }

  @override
  Future<List<LikeRecord>> readLikes(String uid) => guardBackend(() async {
        final snapshot = await _userDoc(uid)
            .collection(kLikesCollection)
            .orderBy(LikeFields.likedAt, descending: true)
            .get();
        return [
          for (final document in snapshot.docs)
            LikeRecord.fromData(
              id: document.id,
              data: decodeBackendValues(document.data()),
            ),
        ];
      });

  @override
  Future<void> addLike(String uid, LikeWrite like) {
    final data = encodeBackendValues(like.toData());
    return guardBackend(
      () => _userDoc(uid)
          .collection(kLikesCollection)
          .doc(like.documentId)
          .set(data),
    );
  }

  @override
  Future<void> removeLike(String uid, String placeId) => guardBackend(
        () => _userDoc(uid).collection(kLikesCollection).doc(placeId).delete(),
      );
}

// ---------------------------------------------------------------------------
// 어댑터 — 계약 타입 ↔ SDK 타입
// ---------------------------------------------------------------------------

/// 올려 보낼 값으로 옮긴다 — [ServerTimestamp] 는 SDK 의 서버 시각 센티널로,
/// [ExactTimestamp] 는 [Timestamp] 로. 나머지 값은 그대로 둔다.
///
/// 중첩된 map 까지 내려가는 것은 사용자 문서의 `board` 때문이다 — 칸 요약이
/// map 안의 map 이라 얕게 옮기면 그 안의 값이 계약 타입인 채로 나간다.
Map<String, Object?> encodeBackendValues(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _encodeValue(value)));

Object? _encodeValue(Object? value) => switch (value) {
      ServerTimestamp() => FieldValue.serverTimestamp(),
      ExactTimestamp(:final at) => Timestamp.fromDate(at),
      Map<String, Object?>() => encodeBackendValues(value),
      _ => value,
    };

/// 읽어 온 문서를 계약이 아는 값으로 옮긴다 — [Timestamp] 는 **UTC**
/// [DateTime] 으로.
///
/// UTC 로 못 박는 것은 [DateTime] 의 같음이 `isUtc` 까지 비교하기 때문이다.
/// 기기의 시간대에 따라 같은 순간이 다른 값으로 읽히면, 시각을 비교하는 쪽이
/// 기기마다 다르게 동작한다.
Map<String, Object?> decodeBackendValues(Map<String, Object?> data) =>
    data.map((key, value) => MapEntry(key, _decodeValue(value)));

Object? _decodeValue(Object? value) => switch (value) {
      Timestamp() => value.toDate().toUtc(),
      Map<String, Object?>() => decodeBackendValues(value),
      _ => value,
    };
