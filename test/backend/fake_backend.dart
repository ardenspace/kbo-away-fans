/// 백엔드 계층의 가짜 구현 — step 1.6 의 타입 경계를 테스트가 소비하는 자리.
///
/// [FakeUserDataStore] 는 단순한 메모리 저장소가 아니라 **규칙의 대역**이다:
/// 업로드 payload 의 키가 계약 화이트리스트를 벗어나면 곧바로 던진다
/// (`firestore.rules` 의 `hasOnly` 가 하는 일). 그래서 이 fake 를 쓰는
/// 테스트는 "계약 밖 필드가 섞이면 서버가 쓰기를 통째로 거부한다"는 성질을
/// 에뮬레이터 없이 앱 쪽에서 그대로 잰다.
///
/// phase 2 이후 단계(2.4 사용자 문서, 3.2 좋아요, 4.2 도장)가 이 파일을
/// 그대로 재사용한다.
library;

import 'dart:async';

import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/auth_kakao.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart'
    show awaitServerConfirmation;

/// 서버 시각 대역 — [ServerTimestamp] 가 이 값으로 확정된다고 본다.
final DateTime kFakeServerNow = DateTime.utc(2026, 9, 1, 12);

/// 메모리 사용자 데이터 저장소.
class FakeUserDataStore implements UserDataStore {
  FakeUserDataStore({this.profileConfirmGrace});

  /// null 이 아니면 [watchProfile] 이 **실 구현과 같은 상한 장치**를 거친다
  /// ([awaitServerConfirmation]) — 서버가 그 시간 안에 아무 답도 주지 않은
  /// 실행을 재는 자리다.
  ///
  /// 기본값이 null 인 것은 이 대역이 상한 타이머를 늘 들고 있으면, "아직
  /// 답하지 않는 서버"([holdProfiles])를 세운 채 끝나는 위젯 시험이 전부
  /// `A Timer is still pending` 으로 실패하기 때문이다. 상한을 재려는 시험만
  /// 값을 준다.
  ///
  /// 술어를 `(_) => true` 로 두는 것은 이 대역이 흘리는 값이 스냅샷이 아니라
  /// 이미 해석된 [UserProfile]? 이라 출처를 물을 자리가 없어서다 — 이 대역이
  /// 흉내 내는 것은 "값이 하나도 오지 않는 구간"([holdProfiles])이고, 그
  /// 구간이 상한에서 어떻게 끝나는지가 재려는 성질이다.
  final Duration? profileConfirmGrace;

  /// uid → 사용자 문서 본문 (서버에 실제로 남은 모습).
  final Map<String, Map<String, Object?>> documents = {};

  /// uid → (도장 문서 id → 본문).
  final Map<String, Map<String, Map<String, Object?>>> stamps = {};

  /// uid → (좋아요 문서 id → 본문).
  final Map<String, Map<String, Map<String, Object?>>> likes = {};

  /// 읽기 호출 횟수 — 4.3 이 "판은 사용자 문서 하나만 읽는다"를 잴 때 쓴다.
  int profileReads = 0;

  /// 도장 조회 호출 횟수.
  int stampReads = 0;

  /// [writeStamp] 호출 횟수 — 이미 있는 도장에 대고 부른 것도 센다.
  /// 4.2 가 "이미 받은 경기에서는 쓰기도 다시 시도하지 않는다"를 잴 때 쓴다.
  int stampWrites = 0;

  /// **서버로 실제로 나간** 도장 쓰기의 문서 id — 순서대로.
  ///
  /// [stampWrites] 와 다른 것은 이미 있는 도장이 여기 쌓이지 않기 때문이다.
  /// "오프라인에서 찍은 도장이 복구 후 **한 번만** 올라간다"를 재는 자리다.
  final List<String> stampUploads = [];

  /// null 이 아니면 [writeStamp] 가 이것을 던진다 — 도장 쓰기가 실패한 실행의
  /// 대역(다음 트리거가 다시 시도하는지를 잰다).
  Object? stampWriteFailure;

  /// true 인 동안 통신이 없다 — 도장 쓰기의 **서버 확인은** 미뤄지고(로컬
  /// 반영은 즉시다, Firestore 의 로컬 쓰기 큐가 그렇게 동작한다), **이 기기가
  /// 아직 받지 못한 문서는 보이지 않는다**([seedServerOnlyStamp]).
  ///
  /// 뒤엣것을 함께 모델하는 까닭은 이 대역의 map 이 "서버"가 아니라 **이 기기의
  /// 로컬 캐시**이기 때문이다. 오프라인에서 읽기는 캐시가 답하거나 답하지 못할
  /// 뿐 서버에 닿지 않는데, map 하나로 둘을 겸하면 오프라인 시험이 언제나
  /// 서버의 진실을 손에 쥔 채 돌아 "쓰기가 느린 온라인"을 재게 된다.
  ///
  /// [goOnline] 이 큐를 비우고 서버에만 있던 문서를 캐시로 들인다.
  bool offline = false;

  /// 서버 확인을 기다리는 쓰기들.
  final List<Completer<void>> _pendingAcks = [];

  /// 서버에는 있지만 **이 기기가 아직 받지 못한** 도장 — uid → (문서 id → 본문).
  final Map<String, Map<String, Map<String, Object?>>> _serverOnlyStamps = {};

  /// 다른 기기가 찍어 **서버에만** 있는 도장을 심는다.
  ///
  /// 오프라인인 동안 이 도장은 [readStamps] 에도 [writeStamp] 의 존재 확인에도
  /// 보이지 않는다 — 실 SDK 에서 캐시에 없는 문서를 읽으면 스냅샷이 아니라
  /// `unavailable` 이 오는 그 자리다. [goOnline] 이 캐시로 들인다.
  void seedServerOnlyStamp(String uid, StampWrite stamp) {
    _serverOnlyStamps.putIfAbsent(uid, () => {})[stamp.documentId] = _accept(
      stamp.toData(),
      StampFields.all,
    );
  }

  /// 통신이 돌아왔다 — 큐에 쌓인 쓰기의 서버 확인을 한꺼번에 내보내고,
  /// 서버에만 있던 문서를 이 기기의 캐시로 들인다.
  void goOnline() {
    offline = false;
    for (final entry in _serverOnlyStamps.entries) {
      final byId = stamps.putIfAbsent(entry.key, () => {});
      // 문서 id 가 결정적이라 같은 경기의 도장은 같은 자리로 수렴한다 —
      // 이 기기가 오프라인에서 쓴 것이 이미 있으면 덮지 않는다.
      for (final stamp in entry.value.entries) {
        byId.putIfAbsent(stamp.key, () => stamp.value);
      }
    }
    _serverOnlyStamps.clear();
    for (final ack in _pendingAcks) {
      if (!ack.isCompleted) ack.complete();
    }
    _pendingAcks.clear();
  }

  /// 좋아요 목록 조회 호출 횟수 — 3.2 가 "카드마다 읽지 않는다"를 잴 때 쓴다.
  int likeReads = 0;

  /// **문서가 실제로 만들어진** 횟수 — 2.4 의 "첫 로그인에 한 번"을 재는 자리.
  /// 이미 있는 문서에 대고 부른 [createProfile] 은 이 수를 올리지 않는다.
  int profileCreates = 0;

  /// 첫 스냅샷을 붙잡아 둔다 — true 인 동안 [watchProfile] 은 아무것도 흘리지
  /// 않는다. "서버 값을 아직 모르는 구간"(콜드 스타트의 첫 프레임)을 재는
  /// 자리이고, [releaseProfiles] 가 그 구간을 끝낸다.
  bool holdProfiles = false;

  /// null 이 아니면 [createProfile]·[patchProfile] 이 이것을 던진다 — **서버
  /// 쓰기가 실패한 실행**의 대역.
  ///
  /// 이 자리가 없으면 "원본을 먼저 쓰고 사본을 뒤에 맞춘다"는 순서를 잴 수
  /// 없다: 서버 쓰기가 언제나 성공하는 대역에서는 두 쓰기의 순서를 뒤집어도
  /// 결과가 같기 때문이다.
  Object? profileWriteFailure;

  /// null 이 아니면 [addLike]·[removeLike] 가 이것을 던진다 — 좋아요 쓰기가
  /// 실패한 실행의 대역(3.2 낙관적 반영의 롤백을 잰다).
  Object? likeWriteFailure;

  /// uid → 사용자 문서 스냅샷 스트림. 실 Firestore 처럼 **쓰기가 곧바로 자기
  /// 스냅샷으로 돌아온다** (로컬 반영이 먼저고 서버 확인이 나중인 그 동작).
  final Map<String, StreamController<UserProfile?>> _profileStreams = {};

  @override
  Future<UserProfile?> readProfile(String uid) async {
    profileReads++;
    final data = documents[uid];
    if (data == null) return null;
    return UserProfile.fromData(uid: uid, data: data);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    final controller = _profileStreams.putIfAbsent(
      uid,
      () => StreamController<UserProfile?>.broadcast(),
    );
    // 구독이 붙은 뒤에 첫 스냅샷을 흘린다 (스트림은 언제나 비동기 전달이다).
    scheduleMicrotask(() => _emitProfile(uid));
    final grace = profileConfirmGrace;
    if (grace == null) return controller.stream;
    return awaitServerConfirmation(
      controller.stream,
      isConfirmed: (_) => true,
      grace: grace,
    );
  }

  /// 스냅샷 스트림에 오류를 흘린다 — **서버를 읽지 못한 실행**의 대역.
  ///
  /// 실 Firestore 에서 이 길로 오는 것은 규칙 거부·통신 실패이고, 계층 경계의
  /// `guardBackendStream` 이 도메인 오류로 옮긴 뒤다.
  ///
  /// **이 대역은 오류 뒤에도 스트림을 열어 둔다** — 실 Firestore 의 스냅샷
  /// 스트림은 오류와 함께 닫히므로 두 전제가 다르다. `awaitServerConfirmation`
  /// 은 그 둘 중 어느 쪽도 전제하지 않는 것을 계약으로 삼는다(오류를 답으로
  /// 보고 그 뒤로는 아무것도 붙잡지 않는다) — 그래서 이 대역이 값을 더
  /// 흘리든 흘리지 않든 상한 없는 구간이 생기지 않는다
  /// (decisions.md 2026-09-04 [M]).
  void emitProfileError(Object error) {
    for (final controller in _profileStreams.values) {
      if (!controller.isClosed) controller.addError(error);
    }
  }

  /// 붙잡아 둔 스냅샷을 흘려보낸다 ([holdProfiles] 를 끄고 현재 값을 낸다).
  void releaseProfiles() {
    holdProfiles = false;
    for (final uid in _profileStreams.keys.toList()) {
      _emitProfile(uid);
    }
  }

  void _emitProfile(String uid) {
    if (holdProfiles) return;
    final controller = _profileStreams[uid];
    if (controller == null || controller.isClosed) return;
    final data = documents[uid];
    controller.add(
      data == null ? null : UserProfile.fromData(uid: uid, data: data),
    );
  }

  @override
  Future<bool> createProfile(String uid, NewUserProfile profile) async {
    // 실 구현은 트랜잭션 안에서 같은 판정을 한다 — 이미 있는 문서는 **덮지
    // 않고**(재로그인이 가입 시각과 배지 판을 지우지 못하게 하는 자리) 만들지
    // 않았다는 사실을 false 로 돌려준다.
    final data = _accept(profile.toData(), UserFields.all);
    final failure = profileWriteFailure;
    if (failure != null) throw failure;
    if (documents.containsKey(uid)) return false;
    profileCreates++;
    documents[uid] = data;
    _emitProfile(uid);
    return true;
  }

  @override
  Future<void> patchProfile(String uid, UserProfilePatch patch) async {
    final failure = profileWriteFailure;
    if (failure != null) throw failure;
    final current = documents[uid];
    if (current == null) {
      throw StateError('없는 사용자 문서를 고칠 수 없다: $uid');
    }
    documents[uid] = {...current, ..._accept(patch.toData(), UserFields.all)};
    _emitProfile(uid);
  }

  /// 스냅샷 스트림 정리 — 테스트의 tearDown 에서 부른다.
  ///
  /// 오프라인 큐에 걸린 쓰기도 함께 푼다: 대역을 오프라인인 채로 두고 끝낸
  /// 시험이 영영 완료되지 않는 Future 를 남기지 않게 한다.
  Future<void> dispose() async {
    goOnline();
    for (final controller in _profileStreams.values) {
      if (!controller.isClosed) await controller.close();
    }
    _profileStreams.clear();
  }

  @override
  Future<List<StampRecord>> readStamps(String uid, {String? cellId}) async {
    stampReads++;
    final byId = stamps[uid] ?? const {};
    final records = byId.entries
        .map((entry) => StampRecord.fromData(id: entry.key, data: entry.value))
        .where((record) => cellId == null || record.cellId == cellId)
        .toList();
    records.sort((a, b) => b.gameDate.compareTo(a.gameDate));
    return records;
  }

  /// 도장 문서와 칸 요약을 **한 원자 단위로** 쓴다 — 실 구현과 같은 순서다
  /// (이미 있으면 아무것도 쓰지 않고, 없으면 둘을 함께 쓴다).
  ///
  /// [offline] 이 켜져 있으면 로컬 반영은 즉시 하고 **서버 확인만** 미룬다 —
  /// Firestore 의 로컬 쓰기 큐가 하는 일이 그것이다. 그래서 이 대역에서도
  /// "오프라인에서 찍은 도장이 판정한 사람에게 곧바로 보이고, 복구 뒤에 한 번
  /// 올라간다"를 그대로 잰다.
  ///
  /// **존재 확인이 보는 것은 이 기기의 캐시다** — 오프라인이면 서버에만 있는
  /// 도장([seedServerOnlyStamp])이 여기 보이지 않고, 실 구현도 같다(캐시에
  /// 없는 문서의 읽기는 던지고, `FirestoreUserDataStore` 는 그것을 "없다"로
  /// 접어 쓰기를 계속한다). 그 갈래에서 두 기기가 같은 경기를 각각 큐에 넣어도
  /// 문서 id 가 결정적이라 도장은 하나로 수렴한다.
  @override
  Future<StampWriteOutcome> writeStamp(String uid, StampWrite stamp) async {
    stampWrites++;
    final data = _accept(stamp.toData(), StampFields.all);
    final failure = stampWriteFailure;
    if (failure != null) throw failure;

    final byId = stamps.putIfAbsent(uid, () => {});
    if (byId.containsKey(stamp.documentId)) {
      return StampWriteOutcome.alreadyStamped;
    }

    final document = documents[uid];
    if (document == null) {
      // 실 구현의 배치는 없는 문서에 update 를 걸 수 없어 Firestore 의
      // `not-found` 로 실패하고, 계층 경계의 `guardBackend` 가 그것을 도메인
      // 오류로 옮긴다 — 온보딩을 마치기 전에는 도장을 쓸 자리가 없다.
      // 이 대역도 같은 어휘로 실패해야 부르는 쪽(4.2 의 도장 쓰기)이 실제와
      // 같은 갈래를 지난다.
      throw const BackendUnknownError(code: 'not-found');
    }

    final board = Map<String, Object?>.from(
      (document[UserFields.board] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
    final cellId = stamp.cellId;
    final previous = board[cellId];
    final cell = BoardCell.forCount(
      count: previous == null
          ? 1
          : BoardCell.fromData(
                  (previous as Map).cast<String, Object?>(),
                ).count +
                1,
      lastStampedOn: stamp.gameDate,
    );

    byId[stamp.documentId] = data;
    board[cellId] = cell.toData();
    documents[uid] = {
      ...document,
      ..._acceptBoardPatch(stamp.boardPatchData(cell), board),
    };
    stampUploads.add(stamp.documentId);
    _emitProfile(uid);

    if (offline) {
      final ack = Completer<void>();
      _pendingAcks.add(ack);
      await ack.future;
    }
    return StampWriteOutcome.created;
  }

  /// 칸 요약 갱신 payload 를 규칙처럼 받아 든다 — 점 경로(`board.{cellId}`)와
  /// `updatedAt` 둘만 허용하고, 점 경로는 이미 합쳐 둔 [board] 로 편다.
  Map<String, Object?> _acceptBoardPatch(
    Map<String, Object?> patch,
    Map<String, Object?> board,
  ) {
    final result = <String, Object?>{UserFields.board: board};
    for (final entry in patch.entries) {
      if (entry.key.startsWith('${UserFields.board}.')) continue;
      if (entry.key == UserFields.updatedAt) {
        result[UserFields.updatedAt] = entry.value is ServerTimestamp
            ? kFakeServerNow
            : entry.value;
        continue;
      }
      throw ArgumentError.value(
        entry.key,
        'boardPatchData',
        '계약 밖 필드 — 규칙이 쓰기를 통째로 거부한다',
      );
    }
    return result;
  }

  @override
  Future<List<LikeRecord>> readLikes(String uid) async {
    likeReads++;
    final byId = likes[uid] ?? const {};
    return byId.entries
        .map((entry) => LikeRecord.fromData(id: entry.key, data: entry.value))
        .toList();
  }

  @override
  Future<void> addLike(String uid, LikeWrite like) async {
    final data = _accept(like.toData(), LikeFields.all);
    final failure = likeWriteFailure;
    if (failure != null) throw failure;
    final byId = likes.putIfAbsent(uid, () => {});
    byId[like.documentId] = data;
  }

  @override
  Future<void> removeLike(String uid, String placeId) async {
    final failure = likeWriteFailure;
    if (failure != null) throw failure;
    likes[uid]?.remove(placeId);
  }

  /// 규칙의 `hasOnly` 대역 + 서버 시각 확정.
  Map<String, Object?> _accept(
    Map<String, Object?> data,
    Set<String> allowedFields,
  ) {
    final extras = data.keys.where((key) => !allowedFields.contains(key));
    if (extras.isNotEmpty) {
      throw ArgumentError.value(
        extras.join(', '),
        'data',
        '계약 밖 필드 — 규칙이 쓰기를 통째로 거부한다',
      );
    }
    return data.map(
      (key, value) =>
          MapEntry(key, value is ServerTimestamp ? kFakeServerNow : value),
    );
  }
}

/// [FakeAuthService.signIn] 이 제공자별로 세우는 uid.
///
/// 따로 내놓는 것은 캐시가 계정에 매여 있기 때문이다(2.4) — "로그인하면 홈이
/// 뜬다"를 재는 시험은 그 계정의 캐시를 심어야 하고, uid 를 문자열로 다시
/// 적으면 이 대역의 규칙이 바뀌는 날 시험이 조용히 어긋난다.
String fakeUidOf(AuthProviderId provider) => '${provider.name}-uid';

/// 메모리 인증 서비스 — 로그인 상태를 테스트가 직접 조종한다.
class FakeAuthService implements AuthService {
  FakeAuthService({AuthUser? signedIn}) : _current = signedIn;

  final _changes = StreamController<AuthUser?>.broadcast();
  AuthUser? _current;

  /// 로그인 호출 기록 (제공자별 호출 순서).
  final List<AuthProviderId> signInCalls = [];

  /// 다음 [signIn] 이 던질 오류 — null 이면 성공한다.
  Object? failure;

  @override
  AuthUser? get currentUser => _current;

  /// 구독하는 순간 지금 아는 상태를 한 번 흘린다 — [AuthService.authStateChanges]
  /// 의 계약이다. 이 fake 는 "아직 모름" 구간이 없다(테스트가 상태를 직접
  /// 정해 주므로 언제나 안다). 그 구간을 재는 대역은 [UnknownSessionAuthService].
  @override
  Stream<AuthUser?> authStateChanges() async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) async {
    signInCalls.add(provider);
    final error = failure;
    if (error != null) throw error;
    final user = AuthUser(
      uid: fakeUidOf(provider),
      displayName: '${provider.name} 사용자',
      // 카카오는 실 구현에서도 이메일을 주지 않는다(`AuthUser` 문서 참조) —
      // 이 대역이 그 갈래까지 흉내 내야 3.4 의 "이메일 없는 계정" 화면을
      // `signIn` 경로로도 재현할 수 있다.
      email: provider == AuthProviderId.kakao
          ? null
          : '${provider.name}@example.com',
    );
    _current = user;
    if (!_changes.isClosed) _changes.add(user);
    return user;
  }

  /// `signOut` 호출 횟수 — 3.4 가 로그아웃 버튼이 실제로 이 경로를 부르는지
  /// 잰다.
  int signOutCalls = 0;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _current = null;
    if (!_changes.isClosed) _changes.add(null);
  }

  /// 세션 스트림에 오류를 흘린다 — 게이트가 스트림 실패를 어떻게 받는지
  /// 재는 자리(2.1). 실 구현에서는 SDK 예외가 이 길로 온다.
  /// 스트림은 열린 채라, 같은 구독으로 뒤이어 값이 더 온다.
  void emitError(Object error) {
    if (!_changes.isClosed) _changes.addError(error);
  }

  /// 세션이 **오류와 함께 끝난다** — 스트림이 닫히므로 같은 구독으로는 값이
  /// 더 오지 않는다. 실 SDK 에서 흔한 모양이고(권한을 잃은 스냅샷 스트림이
  /// 그렇게 끝난다), [emitError] 가 전제하는 "오류 뒤에도 같은 구독이 산다"를
  /// 뺀 자리를 재려고 둔다 — 다시 로그인해서 빠져나오는 경로가 실제로 서
  /// 있는지는 이 대역으로만 드러난다.
  Future<void> dropSession([Object? error]) async {
    _current = null;
    if (_changes.isClosed) return;
    _changes.addError(error ?? StateError('세션 스트림이 끊겼다'));
    await _changes.close();
  }

  /// 스트림 정리 — 테스트의 tearDown 에서 부른다.
  Future<void> dispose() async {
    if (!_changes.isClosed) await _changes.close();
  }
}

/// 세션을 **아직 모르는** 인증 서비스 — 콜드 스타트의 복원 대기 구간 대역.
///
/// 실 Firebase Auth 는 앱이 뜬 직후 잠깐 이 상태다: 네이티브가 영속 세션을
/// 복원해 첫 인증 이벤트를 보내기 전이라 로그인해 둔 사람인지 아닌지를 모른다.
/// 그 구간에서 이 서비스는 **아무 값도 흘리지 않는다** — 계약이 그렇고, 그래야
/// 게이트가 확정되지 않은 로그아웃을 화면에 띄우지 않는다.
///
/// [restore] 가 그 구간을 끝낸다 (인수가 null 이면 실제로 로그아웃 상태였다는
/// 뜻이다).
class UnknownSessionAuthService implements AuthService {
  final StreamController<AuthUser?> _changes =
      StreamController<AuthUser?>.broadcast();

  bool _known = false;
  AuthUser? _current;

  @override
  AuthUser? get currentUser => _current;

  @override
  Stream<AuthUser?> authStateChanges() async* {
    if (_known) yield _current;
    yield* _changes.stream;
  }

  /// 복원이 끝났다 — 이 시점부터 세션 상태를 안다.
  void restore(AuthUser? user) {
    _known = true;
    _current = user;
    if (!_changes.isClosed) _changes.add(user);
  }

  @override
  Future<AuthUser> signIn(AuthProviderId provider) async {
    final user = AuthUser(uid: fakeUidOf(provider));
    restore(user);
    return user;
  }

  @override
  Future<void> signOut() async => restore(null);

  Future<void> dispose() async {
    if (!_changes.isClosed) await _changes.close();
  }
}

/// 카카오의 두 걸음 대역 — SDK 로그인과 커스텀 토큰 교환.
///
/// 실 구현([KakaoSdkAuthGateway])만이 플랫폼 채널과 네트워크를 타는 부분이라,
/// 이 대역을 끼우면 카카오 경로의 나머지 — 교환 결과를 Firebase 세션으로
/// 옮기고, 실패를 도메인 오류로 옮기고, 닉네임을 세션에 심는 자리 — 가
/// `FirebaseAuthService` **그 자체**에서 검증된다.
///
/// 실패는 실 구현과 **같은 어휘로** 흉내 낸다 — 그 어휘가 두 걸음에서 다르다
/// ([KakaoAuthGateway] 의 문서 참조):
///
///  - [loginFailure] 에는 도메인 오류를 넣는다. 실 구현이 카카오 SDK 예외를
///    게이트웨이 안에서 옮기기 때문이다(카카오의 어휘를 공통 표가 모른다).
///  - [exchangeFailure] 에는 날것의 `FirebaseException` 을 넣는다. 실 구현의
///    `exchange` 가 callable 실패를 그대로 던지고, 그것을 도메인으로 옮기는
///    자리는 계층 경계의 `guardBackend` 이기 때문이다 — 도메인 오류만 넣으면
///    그 공통 표(`unavailable`→네트워크, `unauthenticated`→권한)를 지나는
///    경로가 시험에서 통째로 빠진다.
class FakeKakaoAuthGateway extends KakaoAuthGateway {
  FakeKakaoAuthGateway({
    this.accessToken = 'kakao-access-token',
    this.customToken = const KakaoCustomToken(
      customToken: 'custom-token',
      uid: 'kakao:1234567890',
      nickname: '원정러',
    ),
  });

  /// [obtainAccessToken] 이 돌려줄 액세스 토큰.
  String accessToken;

  /// [exchange] 가 돌려줄 교환 결과.
  KakaoCustomToken customToken;

  /// null 이 아니면 [obtainAccessToken] 이 이것을 던진다.
  Object? loginFailure;

  /// null 이 아니면 [exchange] 가 이것을 던진다.
  Object? exchangeFailure;

  /// 카카오 SDK 로그인 호출 횟수.
  int loginCalls = 0;

  /// 교환에 실제로 실려 간 액세스 토큰들 — 순서대로.
  final List<String> exchangedTokens = [];

  @override
  Future<String> obtainAccessToken() async {
    loginCalls++;
    final error = loginFailure;
    if (error != null) throw error;
    return accessToken;
  }

  @override
  Future<KakaoCustomToken> exchange(String accessToken) async {
    exchangedTokens.add(accessToken);
    final error = exchangeFailure;
    if (error != null) throw error;
    return customToken;
  }
}
