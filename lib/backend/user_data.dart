/// 사용자 데이터 접근 계층 — 사용자 문서·도장·좋아요를 오가는 단일 경로.
///
/// 계약 원본은 `docs/firestore-schema.md` 이고 그 규약을 강제하는 것은
/// `firestore.rules` 다. 이 파일은 둘을 앱 쪽 타입으로 옮긴 것이며, 세 가지를
/// 타입 수준에서 못 박는다.
///
///  1) **업로드 payload 는 계약 필드만 싣는다.** 규칙이 문서마다 가질 수 있는
///     키를 `hasOnly` 로 닫아 두었으므로, 계약 밖 필드가 한 번이라도 낀 문서는
///     그 쓰기부터 통째로 거부된다. 그래서 서버로 나가는 값은 자유로운 map 이
///     아니라 아래 write 타입들의 `toData()` 결과뿐이다 — 기기의 지점을
///     가리키는 값은 이름을 무엇으로 붙이든 실릴 자리가 없다
///     (decisions.md 의 데이터 소유권 XL 결정).
///  2) **문서 id 는 결정적이다.** 도장은 `{stadiumId}_{gameId}`, 좋아요는
///     `{placeId}` — id 를 만드는 코드가 write 타입 안에 있어 호출자가 다른
///     조합을 지어낼 수 없다.
///  3) **값 공간은 기존 로스터에서 온다.** 팀·구장 id 는
///     `lib/content/content_ids.dart`, 카테고리는 `PlaceCategory`, 등급은
///     `lib/design/tokens.dart` 의 [BadgeTier] 와 그 사다리를 그대로 쓴다.
///
/// Firestore SDK 타입은 여기 없다. 어댑터(2.4)가 SDK 의 시각 타입을
/// [DateTime] 으로, [ServerTimestamp] 를 SDK 의 서버 시각 표시로 옮긴다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_ids.dart';
import '../content/models.dart' show PlaceCategory;
import '../design/tokens.dart';

// ---------------------------------------------------------------------------
// 시각
// ---------------------------------------------------------------------------

/// 문서에 실리는 시각 값.
///
/// 기기 시계는 틀릴 수 있고 도장·좋아요의 시각은 여러 기기를 가로질러
/// 비교되므로, 새로 쓰는 시각은 기본이 [ServerTimestamp] 다. 이미 확정된
/// 시각을 그대로 옮겨 적을 때만 [ExactTimestamp] 를 쓴다.
@immutable
sealed class BackendTimestamp {
  const BackendTimestamp();
}

/// "서버가 쓰는 순간의 시각" — 어댑터가 SDK 의 서버 시각 표시로 옮긴다.
final class ServerTimestamp extends BackendTimestamp {
  const ServerTimestamp();
}

/// 이미 정해진 시각.
final class ExactTimestamp extends BackendTimestamp {
  const ExactTimestamp(this.at);

  /// 문서에 그대로 실릴 시각.
  final DateTime at;
}

// ---------------------------------------------------------------------------
// 필드 이름 — 규칙의 화이트리스트와 같은 목록
// ---------------------------------------------------------------------------

/// `users/{uid}` 문서의 필드 이름.
abstract final class UserFields {
  /// 표시 이름 (UTF-16 코드 단위로 1~20 — [kNicknameMaxLength] 참조).
  static const String nickname = 'nickname';

  /// 선택 팀 — 이 필드가 원본이고 기기 저장값은 첫 렌더용 캐시다.
  static const String favoriteTeamId = 'favoriteTeamId';

  /// 프로필 색의 팀 테마 키.
  static const String profileThemeKey = 'profileThemeKey';

  /// 가입 시각.
  static const String joinedAt = 'joinedAt';

  /// 마지막 수정 시각 (선택).
  static const String updatedAt = 'updatedAt';

  /// 배지 판의 칸별 요약 map.
  static const String board = 'board';

  /// 문서가 가질 수 있는 필드 전부.
  static const Set<String> all = {
    nickname,
    favoriteTeamId,
    profileThemeKey,
    joinedAt,
    updatedAt,
    board,
  };

  /// 문서가 반드시 가져야 하는 필드.
  static const Set<String> requiredFields = {
    nickname,
    favoriteTeamId,
    profileThemeKey,
    joinedAt,
    board,
  };
}

/// `board` 의 칸 요약 map 필드 이름.
abstract final class BoardCellFields {
  /// 그 칸에 찍힌 도장 개수 (1 이상).
  static const String count = 'count';

  /// 현재 등급 — [count] 에서 파생된 값.
  static const String tier = 'tier';

  /// 그 칸의 마지막 도장 날짜 (선택).
  static const String lastStampedOn = 'lastStampedOn';

  /// 칸 요약이 가질 수 있는 필드 전부.
  static const Set<String> all = {count, tier, lastStampedOn};
}

/// `users/{uid}/stamps/{stampId}` 문서의 필드 이름.
abstract final class StampFields {
  /// 도장을 받은 구장.
  static const String stadiumId = 'stadiumId';

  /// 경기 id (schedule.json 의 그 값).
  static const String gameId = 'gameId';

  /// 그날의 홈팀 — 도장의 색과 칸을 정한다.
  static const String homeTeamId = 'homeTeamId';

  /// 경기 날짜 (KST 달력 날짜).
  static const String gameDate = 'gameDate';

  /// 도장이 찍힌 시각.
  static const String stampedAt = 'stampedAt';

  /// 문서가 가질 수 있는 필드 전부 (전부 필수).
  static const Set<String> all = {
    stadiumId,
    gameId,
    homeTeamId,
    gameDate,
    stampedAt,
  };
}

/// `users/{uid}/likes/{likeId}` 문서의 필드 이름.
abstract final class LikeFields {
  /// 장소 slug — 문서 id 와 같다.
  static const String placeId = 'placeId';

  /// 그 장소가 딸린 구장.
  static const String stadiumId = 'stadiumId';

  /// 장소의 카테고리.
  static const String category = 'category';

  /// 누른 시각.
  static const String likedAt = 'likedAt';

  /// 문서가 가질 수 있는 필드 전부 (전부 필수).
  static const Set<String> all = {placeId, stadiumId, category, likedAt};
}

// ---------------------------------------------------------------------------
// 배지 판의 칸 id
// ---------------------------------------------------------------------------

/// 배지 판 10칸의 id — `{stadiumId}_{homeTeamId}`.
///
/// 구장은 9곳인데 칸이 10개인 것은 잠실만 두 홈팀으로 갈리기 때문이고,
/// 그래서 칸이 팀 테마 10개와 1:1 이 된다. 이 짝 목록 밖의 조합(예:
/// `gocheok_lg`)은 규칙도 거부한다.
///
/// 같은 목록이 `firestore.rules` 의 `cellIds()` 와 `docs/firestore-schema.md`
/// 에도 있다 — 규칙은 콘텐츠 JSON 을 읽을 수 없어 피할 수 없는 복제이고,
/// KBO 10구단·9구장이라 거의 변하지 않는다. 셋 중 하나를 고치면 셋을 함께
/// 고친다.
const Set<String> kBoardCellIds = {
  'jamsil_lg',
  'jamsil_doosan',
  'gocheok_kiwoom',
  'munhak_ssg',
  'suwon_kt',
  'daejeon_hanwha',
  'daegu_samsung',
  'sajik_lotte',
  'changwon_nc',
  'gwangju_kia',
};

/// 구장과 그날 홈팀으로 칸 id 를 만든다. 판에 없는 짝이면 [ArgumentError].
String boardCellIdOf({
  required String stadiumId,
  required String homeTeamId,
}) {
  final id = '${stadiumId}_$homeTeamId';
  if (!kBoardCellIds.contains(id)) {
    throw ArgumentError.value(id, 'cellId', '배지 판에 없는 구장×홈팀 짝');
  }
  return id;
}

// ---------------------------------------------------------------------------
// 값 검사 — 업로드 직전에 계약을 잰다
// ---------------------------------------------------------------------------

final RegExp _dayPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final RegExp _gameIdPattern = RegExp(r'^[A-Za-z0-9-]{1,64}$');
final RegExp _placeIdPattern = RegExp(r'^[a-z][a-z0-9-]{0,63}$');

/// 닉네임 길이의 위·아래 끝 — 단위는 **UTF-16 코드 단위**다.
///
/// 계약을 최종적으로 판정하는 것은 `firestore.rules` 의 `d.nickname.size()` 이고
/// 그것이 UTF-16 코드 단위를 센다 (규칙 언어에는 이 단위를 바꿀 방법이 없다).
/// 그래서 앱도, 카카오 닉네임을 잘라 보내는 `functions/kakao.js` 도 같은 단위로
/// 잰다 — decisions.md 의 "닉네임 길이의 기준 단위는 UTF-16 코드 단위" 결정.
/// Dart 의 [String.length] 가 곧 그 단위이므로 [String.runes] 로 세지 않는다.
///
/// 한글·영문은 한 글자가 1단위라 사람이 세는 20자와 같고, 이모지는 대개 2단위라
/// 10개가 한도다.
const int kNicknameMinLength = 1;
const int kNicknameMaxLength = 20;

String _checkTeamId(String value, String field) {
  if (!kTeamIds.contains(value)) {
    throw ArgumentError.value(value, field, '팀 로스터 밖의 id');
  }
  return value;
}

String _checkStadiumId(String value, String field) {
  if (!kStadiumIds.contains(value)) {
    throw ArgumentError.value(value, field, '구장 로스터 밖의 id');
  }
  return value;
}

String _checkNickname(String value) {
  // `value.length` 는 UTF-16 코드 단위 — 규칙의 `nickname.size()` 와 같은 단위다
  // ([kNicknameMaxLength] 참조).
  final length = value.length;
  if (length < kNicknameMinLength || length > kNicknameMaxLength) {
    throw ArgumentError.value(
      value,
      UserFields.nickname,
      'UTF-16 코드 단위로 $kNicknameMinLength~$kNicknameMaxLength 이어야 한다',
    );
  }
  return value;
}

String _checkDay(String value, String field) {
  if (!_dayPattern.hasMatch(value)) {
    throw ArgumentError.value(value, field, 'YYYY-MM-DD 표기여야 한다');
  }
  return value;
}

String _checkGameId(String value) {
  if (!_gameIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, StampFields.gameId, '경기 id 형식이 아니다');
  }
  return value;
}

String _checkPlaceId(String value) {
  if (!_placeIdPattern.hasMatch(value)) {
    throw ArgumentError.value(value, LikeFields.placeId, '장소 slug 형식이 아니다');
  }
  return value;
}

// ---------------------------------------------------------------------------
// 칸 요약
// ---------------------------------------------------------------------------

/// 배지 판 한 칸의 요약 — 판은 이 값들만 읽고 그린다.
///
/// 도장이 없는 칸은 `board` 에 키 자체가 없으므로 [count] 는 항상 1 이상이고,
/// [tier] 는 [count] 에서 파생된 값이라 사다리와 어긋나면 만들 수 없다
/// (규칙도 같은 사다리로 어긋난 쓰기를 거부한다).
@immutable
class BoardCell {
  BoardCell({required this.count, required this.tier, this.lastStampedOn}) {
    if (count < 1) {
      throw ArgumentError.value(count, BoardCellFields.count, '1 이상이어야 한다');
    }
    if (tier != BadgeTierTokens.tierFor(count)) {
      throw ArgumentError.value(
        tier,
        BoardCellFields.tier,
        '도장 $count개의 등급은 ${BadgeTierTokens.tierFor(count)} 다',
      );
    }
    if (lastStampedOn != null) {
      _checkDay(lastStampedOn!, BoardCellFields.lastStampedOn);
    }
  }

  /// 도장 개수에서 등급을 세워 칸 요약을 만든다.
  factory BoardCell.forCount({required int count, String? lastStampedOn}) {
    if (count < 1) {
      throw ArgumentError.value(count, BoardCellFields.count, '1 이상이어야 한다');
    }
    return BoardCell(
      count: count,
      tier: BadgeTierTokens.tierFor(count)!,
      lastStampedOn: lastStampedOn,
    );
  }

  /// 서버에 남은 칸 요약을 읽는다.
  factory BoardCell.fromData(Map<String, Object?> data) {
    final rawTier = _stringOf(data, BoardCellFields.tier);
    return BoardCell(
      count: _intOf(data, BoardCellFields.count),
      tier: BadgeTier.values.byName(rawTier),
      lastStampedOn: _optionalStringOf(data, BoardCellFields.lastStampedOn),
    );
  }

  /// 그 칸에 찍힌 도장 개수 (1 이상).
  final int count;

  /// 현재 등급.
  final BadgeTier tier;

  /// 그 칸의 마지막 도장 날짜 (없을 수 있다).
  final String? lastStampedOn;

  /// 사용자 문서의 `board.{cellId}` 자리에 실리는 모습.
  Map<String, Object?> toData() => {
        BoardCellFields.count: count,
        BoardCellFields.tier: tier.name,
        if (lastStampedOn != null) BoardCellFields.lastStampedOn: lastStampedOn,
      };

  @override
  bool operator ==(Object other) =>
      other is BoardCell &&
      other.count == count &&
      other.tier == tier &&
      other.lastStampedOn == lastStampedOn;

  @override
  int get hashCode => Object.hash(count, tier, lastStampedOn);
}

// ---------------------------------------------------------------------------
// 사용자 문서
// ---------------------------------------------------------------------------

/// 사용자 문서를 읽은 모습.
@immutable
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.nickname,
    required this.favoriteTeamId,
    required this.profileThemeKey,
    required this.joinedAt,
    required this.board,
    this.updatedAt,
  });

  /// 서버에 남은 문서를 읽는다. 시각 필드는 어댑터가 [DateTime] 으로 옮긴 뒤다.
  factory UserProfile.fromData({
    required String uid,
    required Map<String, Object?> data,
  }) {
    final rawBoard = data[UserFields.board];
    final board = <String, BoardCell>{};
    if (rawBoard is Map) {
      for (final entry in rawBoard.entries) {
        final cellId = entry.key;
        final cell = entry.value;
        if (cellId is! String || !kBoardCellIds.contains(cellId)) {
          throw ArgumentError.value(cellId, UserFields.board, '판에 없는 칸 id');
        }
        if (cell is! Map<String, Object?>) {
          throw ArgumentError.value(cell, cellId, '칸 요약이 map 이 아니다');
        }
        board[cellId] = BoardCell.fromData(cell);
      }
    }
    return UserProfile(
      uid: uid,
      nickname: _stringOf(data, UserFields.nickname),
      favoriteTeamId: _stringOf(data, UserFields.favoriteTeamId),
      profileThemeKey: _stringOf(data, UserFields.profileThemeKey),
      joinedAt: _timeOf(data, UserFields.joinedAt),
      updatedAt: _optionalTimeOf(data, UserFields.updatedAt),
      board: Map.unmodifiable(board),
    );
  }

  /// Firebase Auth uid — 문서 경로에서 온다 (본문에는 없다).
  final String uid;

  /// 표시 이름.
  final String nickname;

  /// 선택 팀 (원본).
  final String favoriteTeamId;

  /// 프로필 색의 팀 테마 키.
  final String profileThemeKey;

  /// 가입 시각.
  final DateTime joinedAt;

  /// 마지막 수정 시각.
  final DateTime? updatedAt;

  /// 칸 id → 칸 요약. 도장이 없는 칸은 키가 없다.
  final Map<String, BoardCell> board;
}

/// 첫 로그인 뒤 만들어지는 사용자 문서 — 온보딩이 끝난 시점의 값.
///
/// 빈 문서는 만들지 않는다. 판은 도장이 없는 상태에서 빈 map 으로 시작한다.
@immutable
class NewUserProfile {
  const NewUserProfile({
    required this.nickname,
    required this.favoriteTeamId,
    required this.profileThemeKey,
  });

  /// 표시 이름 (UTF-16 코드 단위로 1~20 — [kNicknameMaxLength] 참조).
  final String nickname;

  /// 선택 팀.
  final String favoriteTeamId;

  /// 프로필 색의 팀 테마 키 — 보통 [favoriteTeamId] 와 같다.
  final String profileThemeKey;

  /// 문서 생성 payload. 계약을 어기면 여기서 [ArgumentError] 로 막힌다.
  Map<String, Object?> toData() => {
        UserFields.nickname: _checkNickname(nickname),
        UserFields.favoriteTeamId:
            _checkTeamId(favoriteTeamId, UserFields.favoriteTeamId),
        UserFields.profileThemeKey:
            _checkTeamId(profileThemeKey, UserFields.profileThemeKey),
        UserFields.joinedAt: const ServerTimestamp(),
        UserFields.board: const <String, Object?>{},
      };
}

/// 사용자 문서의 부분 수정 — 준 필드와 `updatedAt` 만 나간다.
///
/// 칸 요약(`board`)은 여기 없다. 판은 도장 쓰기와 같은 트랜잭션에서만
/// 갱신되어야 하고(4.2), 판 전체를 통째로 다시 쓰는 경로를 열어 두면 두 기기가
/// 동시에 쓸 때 서로의 칸을 덮는다 — map 으로 둔 이유가 그것이다.
@immutable
class UserProfilePatch {
  const UserProfilePatch({
    this.nickname,
    this.favoriteTeamId,
    this.profileThemeKey,
  });

  /// 바꿀 표시 이름.
  final String? nickname;

  /// 바꿀 선택 팀.
  final String? favoriteTeamId;

  /// 바꿀 프로필 색 테마 키.
  final String? profileThemeKey;

  /// 수정 payload. 바꿀 것이 하나도 없으면 [ArgumentError].
  Map<String, Object?> toData() {
    final data = <String, Object?>{
      if (nickname != null) UserFields.nickname: _checkNickname(nickname!),
      if (favoriteTeamId != null)
        UserFields.favoriteTeamId:
            _checkTeamId(favoriteTeamId!, UserFields.favoriteTeamId),
      if (profileThemeKey != null)
        UserFields.profileThemeKey:
            _checkTeamId(profileThemeKey!, UserFields.profileThemeKey),
    };
    if (data.isEmpty) {
      throw ArgumentError('바꿀 필드가 없는 수정 — 쓰기를 내보내지 않는다');
    }
    return {...data, UserFields.updatedAt: const ServerTimestamp()};
  }
}

// ---------------------------------------------------------------------------
// 도장
// ---------------------------------------------------------------------------

/// 도장을 읽은 모습.
@immutable
class StampRecord {
  const StampRecord({
    required this.documentId,
    required this.stadiumId,
    required this.gameId,
    required this.homeTeamId,
    required this.gameDate,
    required this.stampedAt,
  });

  /// 서버에 남은 도장 문서를 읽는다.
  factory StampRecord.fromData({
    required String id,
    required Map<String, Object?> data,
  }) =>
      StampRecord(
        documentId: id,
        stadiumId: _stringOf(data, StampFields.stadiumId),
        gameId: _stringOf(data, StampFields.gameId),
        homeTeamId: _stringOf(data, StampFields.homeTeamId),
        gameDate: _stringOf(data, StampFields.gameDate),
        stampedAt: _timeOf(data, StampFields.stampedAt),
      );

  /// `{stadiumId}_{gameId}`.
  final String documentId;

  /// 도장을 받은 구장.
  final String stadiumId;

  /// 경기 id.
  final String gameId;

  /// 그날의 홈팀.
  final String homeTeamId;

  /// 경기 날짜.
  final String gameDate;

  /// 도장이 찍힌 시각.
  final DateTime stampedAt;

  /// 이 도장이 채우는 배지 판의 칸.
  String get cellId =>
      boardCellIdOf(stadiumId: stadiumId, homeTeamId: homeTeamId);
}

/// 도장 쓰기 payload.
///
/// 구장 근처 판정은 기기에서 끝나고 **결과만** 올라간다 — 어느 구장, 어느
/// 경기, 어느 홈팀, 어느 날짜. 판정에 쓰인 기기의 지점 값은 이 타입에 실릴
/// 자리가 없다 (decisions.md 의 데이터 소유권 XL 결정).
@immutable
class StampWrite {
  const StampWrite({
    required this.stadiumId,
    required this.gameId,
    required this.homeTeamId,
    required this.gameDate,
  });

  /// 도장을 받은 구장.
  final String stadiumId;

  /// 경기 id.
  final String gameId;

  /// 그날의 홈팀.
  final String homeTeamId;

  /// 경기 날짜 (KST 달력 날짜).
  final String gameDate;

  /// 문서 id — `{stadiumId}_{gameId}`. 같은 경기에 두 번 써도 같은 문서다.
  String get documentId => '${stadiumId}_$gameId';

  /// 이 도장이 채우는 배지 판의 칸.
  String get cellId =>
      boardCellIdOf(stadiumId: stadiumId, homeTeamId: homeTeamId);

  /// 쓰기 payload. 계약을 어기면 여기서 [ArgumentError] 로 막힌다.
  Map<String, Object?> toData() {
    _checkStadiumId(stadiumId, StampFields.stadiumId);
    _checkTeamId(homeTeamId, StampFields.homeTeamId);
    boardCellIdOf(stadiumId: stadiumId, homeTeamId: homeTeamId);
    return {
      StampFields.stadiumId: stadiumId,
      StampFields.gameId: _checkGameId(gameId),
      StampFields.homeTeamId: homeTeamId,
      StampFields.gameDate: _checkDay(gameDate, StampFields.gameDate),
      StampFields.stampedAt: const ServerTimestamp(),
    };
  }
}

// ---------------------------------------------------------------------------
// 좋아요
// ---------------------------------------------------------------------------

/// 좋아요를 읽은 모습.
@immutable
class LikeRecord {
  const LikeRecord({
    required this.placeId,
    required this.stadiumId,
    required this.category,
    required this.likedAt,
  });

  /// 서버에 남은 좋아요 문서를 읽는다.
  factory LikeRecord.fromData({
    required String id,
    required Map<String, Object?> data,
  }) =>
      LikeRecord(
        placeId: _stringOf(data, LikeFields.placeId),
        stadiumId: _stringOf(data, LikeFields.stadiumId),
        category: PlaceCategory.parse(
          _stringOf(data, LikeFields.category),
          'like($id)',
        ),
        likedAt: _timeOf(data, LikeFields.likedAt),
      );

  /// 장소 slug — 문서 id 와 같다.
  final String placeId;

  /// 그 장소가 딸린 구장.
  final String stadiumId;

  /// 장소의 카테고리.
  final PlaceCategory category;

  /// 누른 시각.
  final DateTime likedAt;
}

/// 좋아요 쓰기 payload — 취소는 쓰기가 아니라 문서 삭제다.
@immutable
class LikeWrite {
  const LikeWrite({
    required this.placeId,
    required this.stadiumId,
    required this.category,
  });

  /// 장소 slug.
  final String placeId;

  /// 그 장소가 딸린 구장 — 좋아요 목록을 구장으로 묶어 보여 주기 위해 함께 둔다.
  final String stadiumId;

  /// 장소의 카테고리 — 같은 이유로 함께 둔다.
  final PlaceCategory category;

  /// 문서 id — 장소 slug. 같은 장소를 두 번 눌러도 문서는 하나다.
  String get documentId => placeId;

  /// 쓰기 payload. 계약을 어기면 여기서 [ArgumentError] 로 막힌다.
  Map<String, Object?> toData() => {
        LikeFields.placeId: _checkPlaceId(placeId),
        LikeFields.stadiumId: _checkStadiumId(stadiumId, LikeFields.stadiumId),
        LikeFields.category: category.contractValue,
        LikeFields.likedAt: const ServerTimestamp(),
      };
}

// ---------------------------------------------------------------------------
// 접근 경계
// ---------------------------------------------------------------------------

/// 사용자 데이터 경계 — 사용자 문서·도장·좋아요 읽기/쓰기의 단일 경로.
///
/// 구현은 실패를 `guardBackend` 로 감싸 도메인 오류만 던진다. 도장 쓰기는
/// 문서와 칸 요약을 같은 트랜잭션에서 갱신한다 (4.2).
abstract class UserDataStore {
  /// 사용자 문서. 없으면 null (= 온보딩이 끝나지 않은 계정).
  Future<UserProfile?> readProfile(String uid);

  /// 사용자 문서의 변화 — 배지 판과 프로필이 이 하나만 구독한다.
  Stream<UserProfile?> watchProfile(String uid);

  /// 첫 문서를 만든다 (2.4 — 재로그인이 덮지 않는다).
  Future<void> createProfile(String uid, NewUserProfile profile);

  /// 문서의 일부를 고친다.
  Future<void> patchProfile(String uid, UserProfilePatch patch);

  /// 도장 목록. [cellId] 를 주면 그 칸의 도장만 (= 칸 상세).
  Future<List<StampRecord>> readStamps(String uid, {String? cellId});

  /// 도장을 쓴다. 문서 id 가 결정적이라 같은 경기의 재시도는 멱등하다.
  Future<void> writeStamp(String uid, StampWrite stamp);

  /// 좋아요 목록.
  Future<List<LikeRecord>> readLikes(String uid);

  /// 좋아요를 누른다.
  Future<void> addLike(String uid, LikeWrite like);

  /// 좋아요를 취소한다 (문서 삭제).
  Future<void> removeLike(String uid, String placeId);
}

/// 화면이 소비하는 사용자 데이터 저장소 주입 지점.
///
/// 기본 구현은 아직 없다 — Firestore 연결은 2.4 가 붙이고, 그때까지는
/// override 로 주입한다 (빈 대역을 기본값으로 두면 주입을 빠뜨린 화면이
/// "데이터가 없는 사람"처럼 조용히 동작한다).
final Provider<UserDataStore> userDataStoreProvider = Provider<UserDataStore>(
  (ref) => throw UnimplementedError(
    'UserDataStore 구현은 step 2.4 에서 붙인다 — 그전에는 override 로 주입한다',
  ),
);

// ---------------------------------------------------------------------------
// 읽기 도우미
// ---------------------------------------------------------------------------

String _stringOf(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value is! String) {
    throw ArgumentError.value(value, field, '문자열 필드가 아니다');
  }
  return value;
}

String? _optionalStringOf(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value == null) return null;
  if (value is! String) {
    throw ArgumentError.value(value, field, '문자열 필드가 아니다');
  }
  return value;
}

int _intOf(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value is! int) {
    throw ArgumentError.value(value, field, '정수 필드가 아니다');
  }
  return value;
}

DateTime _timeOf(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value is! DateTime) {
    throw ArgumentError.value(value, field, '시각 필드가 아니다');
  }
  return value;
}

DateTime? _optionalTimeOf(Map<String, Object?> data, String field) {
  final value = data[field];
  if (value == null) return null;
  if (value is! DateTime) {
    throw ArgumentError.value(value, field, '시각 필드가 아니다');
  }
  return value;
}
