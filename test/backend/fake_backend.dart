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
import 'package:kbo_away_fans/backend/user_data.dart';

/// 서버 시각 대역 — [ServerTimestamp] 가 이 값으로 확정된다고 본다.
final DateTime kFakeServerNow = DateTime.utc(2026, 9, 1, 12);

/// 메모리 사용자 데이터 저장소.
class FakeUserDataStore implements UserDataStore {
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

  @override
  Future<UserProfile?> readProfile(String uid) async {
    profileReads++;
    final data = documents[uid];
    if (data == null) return null;
    return UserProfile.fromData(uid: uid, data: data);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) async* {
    yield await readProfile(uid);
  }

  @override
  Future<void> createProfile(String uid, NewUserProfile profile) async {
    if (documents.containsKey(uid)) {
      throw StateError('이미 있는 사용자 문서를 다시 만들 수 없다: $uid');
    }
    documents[uid] = _accept(profile.toData(), UserFields.all);
  }

  @override
  Future<void> patchProfile(String uid, UserProfilePatch patch) async {
    final current = documents[uid];
    if (current == null) {
      throw StateError('없는 사용자 문서를 고칠 수 없다: $uid');
    }
    documents[uid] = {...current, ..._accept(patch.toData(), UserFields.all)};
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

  @override
  Future<void> writeStamp(String uid, StampWrite stamp) async {
    final byId = stamps.putIfAbsent(uid, () => {});
    byId[stamp.documentId] = _accept(stamp.toData(), StampFields.all);
  }

  @override
  Future<List<LikeRecord>> readLikes(String uid) async {
    final byId = likes[uid] ?? const {};
    return byId.entries
        .map((entry) => LikeRecord.fromData(id: entry.key, data: entry.value))
        .toList();
  }

  @override
  Future<void> addLike(String uid, LikeWrite like) async {
    final byId = likes.putIfAbsent(uid, () => {});
    byId[like.documentId] = _accept(like.toData(), LikeFields.all);
  }

  @override
  Future<void> removeLike(String uid, String placeId) async {
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
      (key, value) => MapEntry(
        key,
        value is ServerTimestamp ? kFakeServerNow : value,
      ),
    );
  }
}

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
      uid: '${provider.name}-uid',
      displayName: '${provider.name} 사용자',
    );
    _current = user;
    if (!_changes.isClosed) _changes.add(user);
    return user;
  }

  @override
  Future<void> signOut() async {
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
    final user = AuthUser(uid: '${provider.name}-uid');
    restore(user);
    return user;
  }

  @override
  Future<void> signOut() async => restore(null);

  Future<void> dispose() async {
    if (!_changes.isClosed) await _changes.close();
  }
}
