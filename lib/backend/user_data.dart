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
/// Firestore SDK 타입은 여기 없다. 어댑터(`user_data_firestore.dart`)가 SDK 의
/// 시각 타입을 [DateTime] 으로, [ServerTimestamp] 를 SDK 의 서버 시각 표시로
/// 옮긴다.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_ids.dart';
import '../content/models.dart' show PlaceCategory;
import '../design/tokens.dart';
import 'auth.dart';
import 'errors.dart';
import 'user_data_firestore.dart';

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
String boardCellIdOf({required String stadiumId, required String homeTeamId}) {
  final id = '${stadiumId}_$homeTeamId';
  if (!kBoardCellIds.contains(id)) {
    throw ArgumentError.value(id, 'cellId', '배지 판에 없는 구장×홈팀 짝');
  }
  return id;
}

/// 칸 id 의 홈팀 id — `{stadiumId}_{homeTeamId}` 의 뒷조각.
///
/// 판을 그리는 쪽이 칸의 팀 색을 찾으려면 이 되돌리기가 필요한데, 거기서
/// 문자열을 직접 가르면 id 체계를 아는 자리가 둘이 된다 (`boardCellIdOf` 와
/// 판). 체계가 바뀌면 함께 바뀌어야 하므로 짓는 쪽 옆에 둔다.
///
/// [kBoardCellIds] 밖의 값이면 [ArgumentError].
String boardCellTeamId(String cellId) {
  if (!kBoardCellIds.contains(cellId)) {
    throw ArgumentError.value(cellId, 'cellId', '배지 판에 없는 칸 id');
  }
  // 구장 id 와 팀 id 모두 밑줄을 담지 않으므로 조각은 언제나 둘이다.
  return cellId.split('_').last;
}

/// 칸 id 의 구장 id — `{stadiumId}_{homeTeamId}` 의 앞조각.
///
/// [boardCellTeamId] 와 같은 이유로 여기 산다: 칸 상세가 그 칸의 도장만
/// 질의하려면 구장과 홈팀 두 값이 필요한데, 질의하는 쪽에서 문자열을 직접
/// 가르면 id 체계를 아는 자리가 늘어난다.
///
/// [kBoardCellIds] 밖의 값이면 [ArgumentError].
String boardCellStadiumId(String cellId) {
  if (!kBoardCellIds.contains(cellId)) {
    throw ArgumentError.value(cellId, 'cellId', '배지 판에 없는 칸 id');
  }
  return cellId.split('_').first;
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

/// 표시 이름이 없는 계정이 받는 기본 닉네임의 앞머리.
const String kDefaultNicknamePrefix = '원정러';

/// 첫 문서에 실을 닉네임을 정한다 — 2.4 의 기본 닉네임 갈래가 여기다.
///
/// 제공자가 준 표시 이름([AuthUser.displayName])이 씨앗이지만 **없을 수
/// 있다**: 카카오는 닉네임 동의 항목을 켜지 않은 사람에게 값을 주지 않고
/// (`functions/kakao.js` 의 정상 갈래), 구글·애플도 표시 이름이 비어 있을 수
/// 있다. 그 사람들이 닉네임 없는 문서를 받으면 규칙(`nickname.size() >= 1`)이
/// 문서 생성을 거부하므로, 이 함수가 언제나 계약 안의 값을 돌려준다.
///
/// 기본 닉네임을 uid 에서 결정적으로 짓는 것은 기기를 바꿔 다시 로그인해도
/// 같은 이름이 나오게 하려는 것이다 — 문서는 한 번만 만들어지지만, 만들어지기
/// 전에 두 기기에서 로그인하는 경우에도 이름이 갈리지 않는다. 무작위 값을 쓰면
/// 그 성질이 사라지고, 사람이 바꾸기 전까지의 이름이 실행마다 달라진다.
String seedNickname({required String uid, String? displayName}) {
  final fromProvider = _fitNickname(displayName);
  if (fromProvider != null) return fromProvider;
  return '$kDefaultNicknamePrefix${_nicknameSuffix(uid)}';
}

/// 표시 이름을 닉네임 계약(UTF-16 코드 단위 1~20)에 맞춘다. 남는 것이 없으면
/// null — 그때는 호출자가 기본 닉네임으로 간다.
String? _fitNickname(String? displayName) {
  if (displayName == null) return null;
  final trimmed = displayName.trim();
  if (trimmed.isEmpty) return null;
  final fitted = _truncateToUtf16Length(trimmed, kNicknameMaxLength);
  return fitted.isEmpty ? null : fitted;
}

/// UTF-16 코드 단위로 한도에 맞추되 깨진 글자를 남기지 않는다.
///
/// [String.substring] 을 쓰지 않는 것은 그것이 코드 단위 한가운데를 자를 수
/// 있기 때문이다 — 이모지처럼 두 단위를 차지하는 글자가 경계에 걸리면 짝 잃은
/// 서러게이트 반쪽이 남는다. 코드 포인트를 하나씩 얹으며 길이를 재고 한도를
/// 넘기는 코드 포인트는 통째로 버린다(그래서 결과는 19단위가 될 수 있다).
/// `functions/kakao.js` 의 `truncateToUtf16Length` 와 같은 규칙이다.
String _truncateToUtf16Length(String value, int maxUtf16Length) {
  var kept = value;
  if (kept.length > maxUtf16Length) {
    final buffer = StringBuffer();
    var length = 0;
    for (final rune in value.runes) {
      final glyph = String.fromCharCode(rune);
      if (length + glyph.length > maxUtf16Length) break;
      buffer.write(glyph);
      length += glyph.length;
    }
    kept = buffer.toString();
  }
  // 끝에 남은 ZWJ 는 이어 줄 뒷짝이 없다 — trim 은 이 문자를 공백으로 보지
  // 않으므로 여기서 떼어 낸다 (가족 이모지 사슬이 경계에 걸린 경우).
  while (kept.endsWith('\u200d')) {
    kept = kept.substring(0, kept.length - 1);
  }
  return kept.trimRight();
}

/// uid 에서 뽑은 네 자리 — 실행이 달라져도 같은 값이어야 하므로
/// [Object.hashCode] 를 쓰지 않는다 (문자열 해시는 실행마다 달라질 수 있다).
String _nicknameSuffix(String uid) {
  var hash = 0;
  for (final unit in uid.codeUnits) {
    hash = (hash * 31 + unit) & 0x1FFFFFFF;
  }
  return (hash % 10000).toString().padLeft(4, '0');
}

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
    UserFields.favoriteTeamId: _checkTeamId(
      favoriteTeamId,
      UserFields.favoriteTeamId,
    ),
    UserFields.profileThemeKey: _checkTeamId(
      profileThemeKey,
      UserFields.profileThemeKey,
    ),
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
        UserFields.favoriteTeamId: _checkTeamId(
          favoriteTeamId!,
          UserFields.favoriteTeamId,
        ),
      if (profileThemeKey != null)
        UserFields.profileThemeKey: _checkTeamId(
          profileThemeKey!,
          UserFields.profileThemeKey,
        ),
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
  }) => StampRecord(
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
  }) => LikeRecord(
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
  ///
  /// **null(= 문서 없음)은 확인된 답일 때만 흐른다.** 구현이 서버에 물어보는
  /// 중인 구간에는 아무것도 흘리지 않는다 — "아직 모른다"를 "문서가 없다"로
  /// 흘리면 이미 팀을 고른 사람이 온보딩 대상으로 보이고, 거기서 고른 팀이
  /// 서버의 원본을 덮는 경로가 열린다.
  ///
  /// **그 기다림에는 상한이 있고, 넘으면 값이 아니라 오류가 흐른다**
  /// (`user_data_firestore.dart` 의 `kProfileServerConfirmGrace` ·
  /// `kProfileConfirmTimeoutCode`). 오류를 흘리는 것은 실제로 일어난 일이
  /// "문서가 없다"가 아니라 "서버를 읽지 못했다"이기 때문이다 — 구독자는 그것을
  /// 문서 유무의 답으로 읽지 않는다. 상한이 지난 뒤에 진짜 답이 오면 그 값이
  /// 그대로 이어 흐른다.
  Stream<UserProfile?> watchProfile(String uid);

  /// 첫 문서를 만든다 (2.4 — 재로그인이 덮지 않는다).
  ///
  /// **실제로 만들었으면 true, 이미 있어서 아무것도 하지 않았으면 false.**
  /// 값을 돌려주는 것은 호출자가 "덮지 않았다"와 "썼다"를 구분하지 못하면
  /// 마지막 선택이 조용히 사라지기 때문이다: 첫 문서가 생기기 전에 팀을 두 번
  /// 고르면 두 호출 모두 "문서 없음"으로 판정되어 여기로 오는데, 두 번째가
  /// 아무 말 없이 끝나면 서버에는 첫 팀이 남고 뒤이어 오는 스냅샷이 화면을
  /// 옛 팀으로 되돌린다. false 를 받은 쪽은 수정 경로로 이어 간다.
  Future<bool> createProfile(String uid, NewUserProfile profile);

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
/// 기본값은 Firestore 구현이다(2.4). 설정 파일이 없는 실행에서는 그 구현이
/// 서지 못하고 `firebase-unconfigured` 로 던져 provider 가 오류 상태가 된다 —
/// 인증과 같은 판단이다(빈 대역을 기본값으로 두면 주입을 빠뜨린 화면이
/// "데이터가 없는 사람"처럼 조용히 동작한다). 테스트는 override 로 가짜
/// 구현을 주입한다.
final Provider<UserDataStore> userDataStoreProvider = Provider<UserDataStore>(
  (ref) => FirestoreUserDataStore.instance,
);

/// 지금 로그인한 사람의 사용자 문서 — 문서가 없으면 값이 null 이다.
///
/// 이 하나가 사용자 문서를 구독하는 유일한 자리다. 배지 판(4.3)·프로필·선택
/// 팀이 모두 여기서 값을 받는다 — 화면마다 따로 구독하면 같은 문서를 여러 번
/// 읽게 되고, 그 읽기 수가 무료 할당량을 갉아먹는 자리가 배지 판이다
/// (decisions.md 의 운영 비용 M 결정).
///
/// 세션 상태와 세 가지로 맞물린다.
///  - 세션을 **아직 모르는** 구간(콜드 스타트의 복원 대기)에서는 아무것도
///    흘리지 않는다. 여기서 null 을 흘리면 로그인해 둔 사람이 한 프레임 동안
///    "문서 없는 사람"(= 온보딩 대상)으로 보인다.
///  - 세션이 없으면(로그아웃) 문서도 없다 — null.
///  - 세션 스트림이 실패하면 그 오류를 그대로 물려받는다. 문서를 읽을 수 없는
///    실행을 "문서가 없는 사람"으로 바꾸지 않는다.
///
/// 자동 재시도는 끈다 — `authStateProvider` 와 같은 이유이고, 그 위에 하나가
/// 더 있다: 설정이 없는 실행에서는 저장소가 언제나 같은 오류로 던지므로
/// 재시도가 타이머만 남긴다.
final StreamProvider<UserProfile?> userProfileProvider =
    StreamProvider<UserProfile?>((ref) {
      final session = ref.watch(authStateProvider);
      if (session.hasError) {
        throw session.error!;
      }
      if (!session.hasValue) {
        return const Stream<UserProfile?>.empty();
      }
      final user = session.value;
      if (user == null) {
        return Stream<UserProfile?>.value(null);
      }
      return ref.watch(userDataStoreProvider).watchProfile(user.uid);
    }, retry: (retryCount, error) => null);

// ---------------------------------------------------------------------------
// 좋아요 — 화면이 구독·토글하는 자리
// ---------------------------------------------------------------------------

/// 지금 로그인한 사람이 누른 좋아요 장소 id 집합.
///
/// [readLikes] 를 로그인 세션당 **한 번만** 읽어 공유한다 — 장소 카드가 화면
/// 하나에 여러 장 뜨는데 카드마다 문서를 하나씩 읽거나 카드마다 좋아요
/// 컬렉션을 다시 조회하면, 목록이 늘 때마다 읽기 수가 그만큼 늘어난다(비용이
/// 이 프로젝트의 판단 기준이라는 결정과 같은 방향). [toggle] 이 성공하면
/// 서버를 다시 읽지 않고 이 집합만 고쳐 반영한다 — 실패는 이 집합을 건드리지
/// 않고 그대로 던진다([LikeButton] 이 자기 모습을 되돌리고
/// [LikeButton.onFailed] 로 알리는 자리다).
///
/// 세션이 없으면(로그아웃) 빈 집합이다 — 좋아요는 로그인한 사람의 것이라
/// 쓸 자리가 없다.
///
/// **읽기가 실패하면 이 provider 는 `AsyncError` 로 던진다 — 빈 집합으로
/// 접지 않는다(2026-09-04 [M], 3.2 의 결정을 뒤집는다: supersedes
/// 2026-09-04 liked-place-ids-fail-open).** 3.2 에서는 이 실패를 삼켜 빈
/// 집합으로 보았다 — 카드 몇 개가 잠깐 "안 눌린 것처럼" 보이는 것이
/// 추천 목록 전체를 막는 것보다 쌌기 때문이다. 그런데 3.3(좋아요 탭)에서는
/// 이 provider 의 결과가 화면의 **전부**가 된다: 빈 집합을 그대로 돌려주면
/// "좋아요를 못 읽은 사람"과 "좋아요가 하나도 없는 사람"이 같은 빈 상태를
/// 보고, 앞의 사람은 자기가 누른 것이 사라졌다고 읽는다 —
/// `userProfileProvider`·`selected_team.dart` 가 이미 지키는 "서버를 읽지
/// 못했다" 대 "서버가 없다고 답했다"의 구분과 같은 종류의 거짓이다.
///
/// 그래서 오류를 여기서 삼키는 대신 그대로 흘리고, **그 오류를 접는 자리를
/// 소비자 쪽으로 옮겼다.** 카드·상세 시트(`StadiumPlacesScreen`)는 여전히
/// `likedPlaceIdsProvider.value ?? const <String>{}` 로 읽으므로(`AsyncError`
/// 의 `.value` 는 이전 값이 없으면 null) 동작이 그대로다 — 추천 목록은
/// 여전히 좋아요 하나 때문에 막히지 않는다. 오직 좋아요 탭
/// (`LikesTabScreen`)만 `AsyncValue` 를 그대로 보고 `hasError` 로 "못
/// 읽었다"를 가려 자기 얼굴(재시도 안내)을 보여준다.
class LikedPlaceIds extends AsyncNotifier<Set<String>> {
  @override
  Future<Set<String>> build() async {
    // `authStateProvider` 를 직접 `.value` 로 읽는다 — `CachedTeamId`
    // (`selected_team.dart`) 와 같은 판단이다: 이 화면은 로그인 게이트를
    // 지나야 닿는 자리라 실사용에서는 세션이 이미 확정돼 있다. 세션을 아직
    // 모르는 구간(콜드 스타트의 복원 대기)에 이 provider 가 먼저 서면 잠깐
    // 빈 집합으로 보이지만, `ref.watch` 라서 세션이 확정되는 순간 다시
    // 지어져 그 값으로 따라간다 — `userProfileProvider` 처럼 "문서 없음"을
    // 확정된 답으로만 흘리는 것과 달리, 좋아요는 최선-노력 정보라 그 잠깐의
    // 어긋남을 감내한다.
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const {};
    // `BackendError` 를 여기서 잡지 않는다 — 위 문서화한 대로 오류는 그대로
    // 위로 던져 이 provider 를 `AsyncError` 로 만든다.
    final likes = await ref.watch(userDataStoreProvider).readLikes(user.uid);
    return {for (final like in likes) like.placeId};
  }

  /// 좋아요를 누르거나(true) 취소한다(false).
  ///
  /// 세션이 눌린 순간 사라졌으면(로그인이 끊긴 사이의 탭) 안내할 사람이 없는
  /// 실패가 아니라 진짜 실패다 — 2.4 가 같은 자리에서 세운 관례대로
  /// [BackendPermissionError] 를 던진다.
  Future<void> toggle(String placeId, LikeWrite write, bool liked) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) {
      throw const BackendPermissionError(code: 'unauthenticated');
    }
    final store = ref.read(userDataStoreProvider);
    if (liked) {
      await store.addLike(user.uid, write);
    } else {
      await store.removeLike(user.uid, placeId);
    }
    // 쓰기가 성공한 뒤에만 반영한다 — 실패하면 이 집합은 그대로 남고, 화면
    // 쪽 [LikeButton] 이 자기 모습을 되돌린다.
    //
    // **읽기를 못한 상태("못 읽었다")는 성공한 쓰기로도 지우지 않는다.**
    // `state.hasValue` 가 false 라는 것은 이 세션에서 신뢰할 수 있는 좋아요
    // 집합을 한 번도 확정하지 못했다는 뜻이다(전형적으로 [build] 의 읽기가
    // 실패해 `AsyncError` 로 굳은 상태) — 거기서 `state.value ?? const {}`
    // 로 빈 집합을 지어 쓰면, 방금 쓴 항목 하나만 담긴 `AsyncData` 가 "이
    // 사람의 좋아요는 이것뿐"이라는 완성된 얼굴로 좋아요 탭에 뜬다. 실제로는
    // 서버를 여전히 읽지 못한 상태이므로 그 오류를 그대로 지킨다 — 쓰기 자체는
    // 이미 서버에 반영됐고, 다음 성공한 읽기가 진짜 목록을 가져온다.
    if (!state.hasValue) return;
    final current = state.value ?? const <String>{};
    state = AsyncData(
      liked
          ? {...current, placeId}
          : (Set<String>.from(current)..remove(placeId)),
    );
  }
}

/// [LikedPlaceIds] 의 주입 지점 — 장소 카드·상세 시트가 좋아요 상태를 읽고
/// 바꾸는 유일한 자리다.
///
/// 자동 재시도는 끈다 — `authStateProvider`·`userProfileProvider` 와 같은
/// 판단이되 까닭은 하나 더 있다: 좋아요 탭(3.3)은 이 provider 가 오류로
/// 굳으면 사람이 누르는 재시도 버튼을 이미 보여준다
/// (`LikesTabScreen.loadFailureTitle` 의 `onRetry`). 자동 재시도가 그 뒤에서
/// 계속 다시 세우면, 사람이 재시도 버튼을 누르지도 않았는데 요청이 최대
/// 11회(riverpod 기본 재시도의 최초 시도 1 + 재시도 10)까지 나가고 그 마지막
/// 대기가 6.4초라, 화면의 실패 얼굴과 뒤에서 도는 요청이 서로 어긋난다.
/// 다시 세우는 시점을 사람의 행동(재시도 버튼)에 맞춘다.
final AsyncNotifierProvider<LikedPlaceIds, Set<String>> likedPlaceIdsProvider =
    AsyncNotifierProvider<LikedPlaceIds, Set<String>>(
      LikedPlaceIds.new,
      retry: (retryCount, error) => null,
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
