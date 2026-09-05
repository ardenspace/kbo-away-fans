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
///
/// 몫이 하나 더 있다: **스냅샷의 출처를 읽는 일**([tellsProfileExistence] ·
/// [awaitServerConfirmation]). 오프라인 지속성이 켜진 SDK 는 스냅샷을 로컬
/// 캐시에서 먼저 흘리는데, 기기를 바꾼 사람의 로컬 캐시에는 그 문서가 없어서
/// 서버 왕복 전에 "문서 없음"이 먼저 온다. 그것을 답으로 올려보내면 이미 팀을
/// 고른 사람이 온보딩으로 내려간다 — SDK 사정이라 이 파일의 몫이다.
library;

import 'dart:async';

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

/// 서버가 문서 유무를 확인해 주기를 기다리는 상한.
///
/// 넘으면 그 기다림을 끝낸다 — 영영 답하지 않는 실행(비행기 모드 그대로 켠 앱)
/// 에서 사람이 대기 화면에 갇히지 않게 하는 바닥이다. 인증 쪽
/// `kAppCheckActivationTimeout` 과 같은 판단이고 같은 길이다: 사람이 보는
/// 화면을 붙잡는 기다림에는 상한이 있다.
///
/// 끝내는 방법은 그때까지 받은 것에 따라 둘이다.
///  - 붙잡아 둔 값이 있으면(로컬 캐시만 보고 말한 "문서 없음") 그것을 그대로
///    올려보낸다.
///  - **값이 하나도 없으면 [kProfileConfirmTimeoutCode] 오류를 올려보낸다.**
///    이 갈래가 온라인의 주된 모습이다 — 문서 리스너는 로컬 캐시에 문서가
///    없으면 초기 스냅샷을 아예 올리지 않으므로(SDK 의 `shouldRaiseInitialEvent`)
///    기기를 바꿔 처음 로그인한 사람에게는 붙잡을 값조차 오지 않는다.
///
/// 상한은 여기서 끝나고 사람을 그 판단에 가두지 않는다 — 뒤늦게 온 진짜 답은
/// 그대로 위로 흐르고 화면이 그 값으로 수렴한다.
const Duration kProfileServerConfirmGrace = Duration(seconds: 5);

/// 상한 안에 아무 답도 오지 않은 실행이 받는 오류의 코드.
///
/// 도메인을 네트워크로 잡은 것은 실제로 일어난 일이 그것이어서다: 서버에
/// 물었는데 시간 안에 닿지 못했다. 이 확정이 위 계층에서 뜻하는 바는 "서버를
/// 읽지 못했다"이고, 그러면 이미 서 있는 규칙 — 서버를 읽지 못하면 캐시가
/// 정하고, 캐시가 비면 온보딩 — 이 그대로 적용된다. 반대로 "문서가 없다"로
/// 확정하면 캐시에 팀이 있는 사람까지 온보딩으로 내려가고, 그 뒤를 받아 내는
/// 물러서기의 읽기도 같은 통신 사정에서 실패해 안내로 끝난다
/// (decisions.md 2026-09-04 [M]).
const String kProfileConfirmTimeoutCode = 'profile-confirm-timeout';

/// 이 스냅샷이 문서의 유무를 실제로 **답하는가**.
///
/// 있는 문서는 어디서 왔든 답이다 — 로컬 캐시에 있다는 것은 이 기기가 전에
/// 그 문서를 받았다는 뜻이라 이 계정 자신의 데이터다. 반면 로컬 캐시만 보고
/// 말하는 "없음"은 답이 아니다: 기기를 바꾼 사람의 캐시에는 서버에 있는
/// 문서도 없다.
bool tellsProfileExistence(DocumentSnapshot<Object?> snapshot) =>
    snapshot.exists || !snapshot.metadata.isFromCache;

/// 아직 답이 아닌 값을 [grace] 동안 붙잡아 둔다.
///
/// 붙잡아 두는 사이에 답인 값이 오면 그것만 내보내고 붙잡아 둔 것은 버린다.
/// 상한까지 답이 오지 않으면 마지막으로 붙잡아 둔 것을 내보낸다 — 모른다는
/// 이유로 화면을 영원히 붙잡지 않는다. 한 번 답을 받은 뒤로는 뒤엣값을 그대로
/// 흘린다(상한은 **첫 답**에만 걸린다).
///
/// **붙잡아 둘 값조차 오지 않은 실행도 상한에서 끝난다.** 그때는 내보낼 값이
/// 없으므로 [kProfileConfirmTimeoutCode] 오류를 내보낸다 — 붙잡아 둔 값을
/// 푸는 일만 하면, 값이 하나도 흐르지 않은 실행에서는 풀어 줄 것이 없어
/// 상한이 지나도 아래로 아무것도 흐르지 않는다. 그 실행이 곧 온라인에서
/// 기기를 바꿔 처음 로그인한 사람이다(아래 문단). 상한이 무는 구간과 사람이
/// 갇히는 구간을 어긋나게 두지 않는 자리다.
///
/// 상한이 지난 뒤에 온 값은 그대로 흐른다 — 확정은 갈래를 정하는 바닥이지
/// 사람을 옛 판단에 가두는 자물쇠가 아니다.
///
/// 원본이 값 없이 **닫히면** 오류를 얹지 않고 함께 닫는다: 더 기다릴 것이
/// 없다는 사실을 스트림이 이미 말했고, 거기에 상한 오류를 더하면 정상적으로
/// 끝난 구독이 실패한 구독으로 보인다.
///
/// **오류도 답이다.** 그 자체가 위 계층이 갈래를 정하는 신호이므로 붙잡지 않고
/// 그대로 흘리고, 그 뒤로는 상한을 다시 세우지 않는다(뒤엣값도 붙잡지 않는다).
/// 붙잡아 두었던 값은 오류와 함께 버린다 — 확인받을 길이 사라진 값을 답으로
/// 승격시키면 "서버를 읽지 못했다"가 "서버가 없다고 답했다"로 바뀐다. 이 변환은
/// **오류 뒤에 원본 스트림이 끝나는지 아닌지를 전제하지 않는다**: 실 Firestore 의
/// 스냅샷 스트림은 오류와 함께 닫히고 이 계층의 대역
/// (`test/backend/fake_backend.dart`)은 열어 둔 채로 값을 더 흘리는데, 어느
/// 쪽이든 상한 없는 구간이 생기지 않아야 한다
/// (decisions.md 2026-09-04 [M]).
///
/// **값을 붙잡는 구간과 값이 아예 오지 않는 구간은 다르다.** 온라인에서
/// Firestore 문서 리스너는 로컬 캐시에 그 문서가 없으면 초기 스냅샷을 아예
/// 올리지 않고 서버 확인을 기다린다(SDK 의 `shouldRaiseInitialEvent`) —
/// 붙잡을 값 자체가 오지 않는다. 그래서 여기서 값을 **붙잡는** 일이 실제로
/// 나는 것은 대체로 오프라인 갈래이고, 온라인에서 기기를 바꾼 사람은 값이
/// 하나도 오지 않는 갈래에 든다. 두 갈래 모두 상한에서 끝나며, 무는 대가는
/// 어느 쪽이든 최대 [kProfileServerConfirmGrace] 의 대기 화면이다.
Stream<T> awaitServerConfirmation<T>(
  Stream<T> source, {
  required bool Function(T value) isConfirmed,
  Duration grace = kProfileServerConfirmGrace,
}) {
  StreamSubscription<T>? subscription;
  Timer? deadline;
  var answered = false;
  var hasWithheld = false;
  late T withheld;
  late StreamController<T> controller;

  void releaseWithheld() {
    answered = true;
    if (!hasWithheld) return;
    hasWithheld = false;
    if (!controller.isClosed) controller.add(withheld);
  }

  /// 상한이 다 됐다 — 붙잡아 둔 것이 있으면 내보내고, 없으면 "서버를 읽지
  /// 못했다"로 끝낸다. 뒤엣값은 더 붙잡지 않는다.
  void closeGrace() {
    if (answered) return;
    if (hasWithheld) {
      releaseWithheld();
      return;
    }
    answered = true;
    if (!controller.isClosed) {
      controller.addError(
        const BackendNetworkError(code: kProfileConfirmTimeoutCode),
        StackTrace.current,
      );
    }
  }

  controller = StreamController<T>(
    onListen: () {
      deadline = Timer(grace, closeGrace);
      subscription = source.listen(
        (value) {
          if (answered || isConfirmed(value)) {
            answered = true;
            hasWithheld = false;
            deadline?.cancel();
            controller.add(value);
          } else {
            withheld = value;
            hasWithheld = true;
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          // 오류도 답이다 — 상한은 여기서 끝나고, 뒤이어 오는 값은 붙잡지
          // 않는다. 이 한 줄이 없으면 오류를 받고도 "아직 답이 없다"로 남아,
          // 그 뒤에 온 답 아닌 값이 상한의 몇 배가 지나도 나오지 않는다.
          answered = true;
          // 붙잡아 둔 값은 버린다. 확인받을 길이 사라졌으므로 답으로
          // 승격시키지 않는다 — 그것을 마저 내보내면 위 계층의 "서버를 읽지
          // 못했다"가 "서버가 없다고 답했다"로 바뀌고, 이미 팀을 고른 사람이
          // 온보딩으로 내려간다.
          hasWithheld = false;
          deadline?.cancel();
          controller.addError(error, stackTrace);
        },
        onDone: () {
          deadline?.cancel();
          releaseWithheld();
          controller.close();
        },
      );
    },
    onCancel: () async {
      deadline?.cancel();
      await subscription?.cancel();
    },
  );
  return controller.stream;
}

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

  /// 사용자 문서의 변화 — **로컬 캐시만 보고 말하는 "문서 없음"은 흘리지
  /// 않는다.**
  ///
  /// 오프라인 지속성이 켜진 SDK 는 구독이 붙는 순간 로컬 캐시의 스냅샷을 먼저
  /// 흘리고 서버 확인을 뒤에 붙인다. 기기를 바꾼 사람의 로컬 캐시에는 그
  /// 문서가 없으므로 서버 왕복 전에 "없음"이 먼저 오는데, 그것을 답으로
  /// 올려보내면 이미 팀을 고른 사람이 온보딩으로 내려가고 거기서 팀을 누르면
  /// 자기 팀을 바꾸게 된다. 그래서 그 한 갈래만 [kProfileServerConfirmGrace]
  /// 까지 붙잡아 둔다.
  ///
  /// **그 상한은 값이 하나도 오지 않는 실행에서도 끝난다** — 거기서는 내보낼
  /// 값이 없으므로 [kProfileConfirmTimeoutCode] 오류가 흐르고, 위 계층은 그것을
  /// "서버를 읽지 못했다"로 받아 캐시로 갈래를 정한다. 온라인에서 기기를 바꿔
  /// 처음 로그인한 사람이 바로 그 실행이다(초기 스냅샷 자체가 오지 않는다).
  @override
  Stream<UserProfile?> watchProfile(String uid) => guardBackendStream(
        awaitServerConfirmation(
          _userDoc(uid).snapshots(),
          isConfirmed: tellsProfileExistence,
        ).map((snapshot) => _profileOf(uid, snapshot)),
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

  /// 도장 문서와 칸 요약을 **한 배치**로 쓴다.
  ///
  /// **왜 `runTransaction` 이 아닌가.** Firestore 트랜잭션은 서버에 닿아야
  /// 끝나므로 오프라인에서는 완료되지 않는다 — [createProfile] 의 주석이 이미
  /// 그 제약을 적으며 "도장·좋아요처럼 구장에서 오프라인으로 쓰는 경로에는 이
  /// 방식을 쓰지 않는다"고 못 박아 두었다. 구장은 사람이 몰려 통신이 잘 끊기는
  /// 자리이고, 도장이 찍히는 순간을 놓치면 시간 창이 닫힌 뒤에는 되찾을 길이
  /// 없다. 반면 `WriteBatch` 는 서버에서 원자적이면서 오프라인에서는 로컬
  /// 쓰기 큐에 쌓였다가 복구 뒤에 한 번 올라간다.
  ///
  /// 그 대신 개수를 세는 읽기가 배치 **밖**에 있다. 트랜잭션이 막아 주던
  /// "읽고 쓰는 사이에 남이 끼어드는" 갈래가 여기서는 열려 있다. 그 갈래는
  /// 같은 계정이 두 기기로 도장을 받는 실행만이 아니라 **한 기기에서도**
  /// 선다: 도장 쓰기를 기다리는 자리가 판정의 겹침 방지 빗장
  /// (`StadiumVisitCheck._running`) 밖이라 두 `award` 가 겹칠 수 있고, 같은
  /// 칸의 두 경기가 겹쳐 들어오면 두 쓰기가 각각 `count = 0 + 1` 을 읽어 개수
  /// 하나를 잃는다. 어긋나더라도 규칙이 지키는 것은 그대로다 —
  /// `tier == tierFor(count)` 는 어느 경로로 써도 강제된다.
  ///
  /// 멱등의 자리는 **두 겹**이다. 문서 id 가 결정적이라 같은 경기의 도장은
  /// 언제나 같은 문서로 수렴하고(재시도·중복 탭·여러 기기), 그 위에 이
  /// 메서드가 "이미 있으면 아무것도 쓰지 않는다"를 얹어 칸 요약의 개수까지
  /// 붙들어 둔다. 오프라인에서 두 번 판정해도 두 번째는 로컬 캐시에 이미
  /// 있는 문서를 보고 곧바로 끝나므로, 큐에 쌓이는 배치가 하나다
  /// ([_alreadyStamped] 가 그 "두 번째"의 자리다).
  @override
  Future<StampWriteOutcome> writeStamp(String uid, StampWrite stamp) {
    // 계약 위반(ArgumentError)은 guardBackend 밖에서 드러나야 한다 —
    // 이 계층의 다른 쓰기와 같은 순서다.
    final data = encodeBackendValues(stamp.toData());
    final cellId = stamp.cellId;
    return guardBackend(() async {
      final userReference = _userDoc(uid);
      final stampReference = userReference
          .collection(kStampsCollection)
          .doc(stamp.documentId);

      if (await _alreadyStamped(stampReference)) {
        return StampWriteOutcome.alreadyStamped;
      }

      final profile = _profileOf(uid, await userReference.get());
      final cell = BoardCell.forCount(
        count: (profile?.board[cellId]?.count ?? 0) + 1,
        lastStampedOn: stamp.gameDate,
      );

      final batch = _db.batch();
      batch.set(stampReference, data);
      batch.update(userReference, encodeBackendValues(stamp.boardPatchData(cell)));
      await batch.commit();
      return StampWriteOutcome.created;
    });
  }

  /// 이 도장 문서가 **이미 있다고 말할 수 있는가** — 읽지 못한 실행은 false 다.
  ///
  /// **오프라인에서 캐시에 없는 문서를 읽으면 SDK 는 스냅샷을 주지 않고
  /// `unavailable` 로 던진다** (에뮬레이터 실측: "Failed to get document
  /// because the client is offline."). 오프라인에서 찍는 **첫** 도장이 정확히
  /// 그 갈래다 — 그 던짐을 그대로 위로 올리면 배치가 열리지도 않아 로컬 쓰기
  /// 큐에 아무것도 들어가지 않고, 복구 뒤에 올라갈 것 자체가 없다. 이 파일이
  /// 배치를 고른 까닭("도장이 찍히는 순간을 놓치면 시간 창이 닫힌 뒤에는
  /// 되찾을 길이 없다")이 그 자리에서 무너진다.
  ///
  /// 그래서 **통신 때문에 읽지 못한 것은 "없다"로 접고 쓰기를 계속한다.**
  /// 그렇게 해도 같은 경기가 두 번 쌓이지 않는 것은 세 겹 덕분이다.
  ///  1. 문서 id 가 결정적이라 도장 문서 자체는 같은 문서로 수렴한다
  ///     (decisions.md 의 `[L]` 결정 150).
  ///  2. 큐에 넣은 쓰기는 SDK 가 캐시에 곧바로 반영하므로, 같은 오프라인
  ///     구간의 **두 번째** 판정에서는 이 읽기가 답한다(실측 셋째 줄).
  ///  3. 그 앞에 `StampAward` 의 세션 사본이 같은 경기의 두 번째 쓰기를 아예
  ///     내보내지 않는다.
  ///
  /// **남는 대가**는 하나다: 이 계정이 다른 기기에서 이미 찍은 도장이 서버에만
  /// 있고 이 기기 캐시에는 없는 채로 오프라인이면, 이 기기도 배치를 하나 더
  /// 큐에 넣는다. 도장 문서는 1번 때문에 하나로 수렴하지만 칸 요약의 개수는
  /// 이 기기가 센 값으로 덮인다. 같은 경기를 두 기기에서 오프라인으로 찍어야
  /// 서는 갈래이고(도장은 그 구장에 몸이 있어야 받는다), 그 대가를 치르는
  /// 쪽이 "도장을 아예 잃는다"보다 낫다는 것이 이 선택이다.
  ///
  /// **통신이 아닌 실패는 그대로 던진다.** 규칙 거부(`permission-denied`)는
  /// "모르겠다"가 아니라 "쓸 수 없다"이고, 그것까지 없는 도장으로 접으면 쓸
  /// 수 없는 문서를 향한 배치가 조용히 큐에 쌓인다.
  Future<bool> _alreadyStamped(
    DocumentReference<Map<String, dynamic>> reference,
  ) async {
    try {
      return (await reference.get()).exists;
    } on FirebaseException catch (error) {
      if (kNetworkErrorCodes.contains(error.code)) return false;
      rethrow;
    }
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
