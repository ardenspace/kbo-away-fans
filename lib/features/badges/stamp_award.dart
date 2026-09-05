/// 판정 결과를 도장으로 옮기는 자리 (step 4.2).
///
/// **왜 이 계층인가.** 판정은 `lib/location/` 이 하고 쓰기는 `lib/backend/`
/// 가 하는데, 두 계층은 서로를 모른다 — `lib/location/` 이 `lib/backend/` 를
/// import 하지 않는 것은 좌표가 서버로 나갈 길을 아예 만들지 않으려는 방어다
/// (`.wellbegun/decisions.md` 2026-09-04 `[L]`). 그래서 둘을 잇는 자리는
/// 부르는 쪽인 feature 이고, 후보를 짓는 자리
/// (`stadium_visit.dart` 의 [buildStadiumVisitCandidates])와 같은 폴더다.
///
/// 이 파일이 아는 것 하나가 다른 어느 계층에도 없다: **"이 경기의 도장은 이미
/// 있다."** 판정만 하는 `lib/location/` 은 그것을 알 수 없고, 도장을 쓰는
/// `lib/backend/` 는 판정을 트리거하지 않는다. 그래서 "이미 받은 경기에서
/// 판정(과 측위)이 다시 돌지 않게 하는 자리"가 여기다
/// (`.wellbegun/decisions.md` 2026-09-04 `[S]`: 포그라운드 복귀마다 GPS 를
/// 다시 켜는 것을 4.2 로 넘긴 그 줄).
///
/// **좌표는 여기까지 오지 않는다.** 이 파일이 받는 것은 판정 결과
/// ([StadiumVisitResult]) 뿐이고 그 타입에는 좌표를 둘 자리가 없다 — 도장
/// payload([StampWrite]) 도 마찬가지다. 이 파일이 하는 일은 결과의 구장·경기
/// id 에 **일정 문서에서 찾은 홈팀·날짜**를 붙여 백엔드로 넘기는 것뿐이다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../backend/auth.dart';
import '../../backend/errors.dart';
import '../../backend/user_data.dart';
import '../../content/models.dart';
import '../../location/visit_check.dart';

/// 이번 실행에서 **도장이 있다고 아는** 경기들 — 값은 도장 문서 id
/// (`{stadiumId}_{gameId}`).
///
/// 서버가 원본이고 이것은 그 앎의 세션 사본이다. 사본을 두는 까닭은 판정이
/// 앱을 열 때마다 도는데(첫 프레임 · 포그라운드 복귀) 이미 받은 경기에서
/// 다시 도는 것이 곧 GPS 를 다시 켜는 일이기 때문이다. 서버에 매번 물어
/// 확인하면 그 물음 자체가 읽기 비용이므로, 이 세션에서 확인한 사실만 들고
/// 있다가 다음 콜드 스타트에 다시 확인한다.
final NotifierProvider<StampAward, Set<String>> stampAwardProvider =
    NotifierProvider<StampAward, Set<String>>(StampAward.new);

/// 도장을 쓰고, 이번 실행에서 이미 받은 경기를 기억한다.
class StampAward extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// 이 경기의 도장이 이번 실행에서 이미 확인되었는가.
  bool knowsStampFor({required String stadiumId, required String gameId}) {
    final documentId = _documentIdOf(stadiumId: stadiumId, gameId: gameId);
    return documentId != null && state.contains(documentId);
  }

  /// 도장 문서 id — **계약 밖 값이면 null.**
  ///
  /// [stampDocumentIdOf] 는 구장 로스터와 `gameId` 의 모양을 [ArgumentError] 로
  /// 막는데(짝인 `boardCellIdOf` 와 같은 세기다), 이 파일이 그것을 묻는 값은
  /// 콘텐츠 문서에서 온다 — 일정 계약은 `gameId` 를 `nonEmptyString` 으로만
  /// 적으므로 도장 계약을 어기는 값이 흘러들 수 있다. 그런 경기는 도장이
  /// 만들어질 수 없으니 "아직 못 받은 경기"로 두고 조용히 지난다: 후보를 짓는
  /// 자리가 구장 문서에 없는 구장을 건너뛰는 것과 같은 판단이고, 여기서
  /// 던지면 리그 어딘가의 잘못된 한 줄이 그날의 판정을 통째로 멈춘다.
  String? _documentIdOf({required String stadiumId, required String gameId}) {
    try {
      return stampDocumentIdOf(stadiumId: stadiumId, gameId: gameId);
    } on ArgumentError {
      return null;
    }
  }

  /// 지금 다시 판정해도 **새 도장이 나올 수 없는가** — 참이면 측위를 건너뛴다.
  ///
  /// **왜 "후보가 전부 도장을 받았는가"가 아닌가.** 후보는 리그 전체의 그날
  /// 경기이고 사람은 그중 한 구장에서만 도장을 받는다. 배포되는 일정에는
  /// 경기가 하나뿐인 날이 아예 없으므로(`content-pipeline/data/schedule.json`:
  /// 168경기, 날짜당 2~5경기), 그 물음으로 세운 게이트는 실전에서 한 번도
  /// 닫히지 않는다 — 2026-09-04 `[S]` 가 이 단계로 넘긴 낭비("경기가 있는 날에는
  /// 앱을 다시 켤 때마다 GPS 를 켜고 이미 도장을 받은 뒤에도 계속 돈다")가
  /// 그대로 남는다.
  ///
  /// 그래서 **도장이 말해 주는 사실**로 좁힌다: 창이 지금을 덮는 경기의 도장을
  /// 받았다면 그 사람은 그 구장에 있다. 그 구장에서 지금 더 받을 도장이 없으면
  /// 좌표를 다시 읽어도 나올 답은 이미 받은 도장뿐이다 — [judgeStadiumVisit] 도
  /// 같은 창으로 답을 고르므로, 이 게이트가 닫히는 구간은 판정이 새것을 내놓을
  /// 수 없는 구간과 같다.
  ///
  /// 재는 것이 [candidatesToJudge] 가 아니라 **[visitWindowCovers] 인 후보**인
  /// 것은 도장이 붙는 범위가 시간 창이기 때문이다. 오늘 경기지만 창이 아직
  /// 열리지 않은 후보는 지금 도장이 되지 않으므로 게이트의 근거도 되지 못한다.
  ///
  /// **남는 대가** 하나를 적어 둔다: 1차전의 창이 아직 열려 있는 동안 다른
  /// 구장으로 옮겨 간 사람은 그 창이 닫힐 때까지 판정을 받지 못한다. 몸이
  /// 어디에 있는지는 측위 없이 알 수 없고, 이 게이트가 아끼려는 것이 바로 그
  /// 측위다. 낮 경기(창이 시작 5시간 뒤 닫힌다)와 저녁 경기의 창은 뒤끝이
  /// 어긋나므로 두 구장을 도는 사람의 둘째 도장은 늦어질 뿐 사라지지 않는다.
  ///
  /// 창을 덮는 도장이 하나도 없으면 false 다 — 경기가 없는 날에도 판정이 돌아야
  /// [StadiumVisitReason.noGameToday] 가 남고, 4.5("못 받는 날")가 그 이유를
  /// 신호로 쓴다. 여기서 조용히 건너뛰면 그 갈래가 영영 서지 않는다.
  bool judgingAddsNothing(
    List<StadiumVisitCandidate> candidates,
    DateTime now,
  ) {
    final inWindow = [
      for (final candidate in candidates)
        if (visitWindowCovers(candidate, now)) candidate,
    ];
    final visited = {
      for (final candidate in inWindow)
        if (knowsStampFor(
          stadiumId: candidate.stadiumId,
          gameId: candidate.gameId,
        ))
          candidate.stadiumId,
    };
    if (visited.isEmpty) return false;
    return inWindow.every(
      (candidate) =>
          !visited.contains(candidate.stadiumId) ||
          knowsStampFor(
            stadiumId: candidate.stadiumId,
            gameId: candidate.gameId,
          ),
    );
  }

  /// 방문 판정 하나를 도장으로 옮긴다.
  ///
  /// 아무것도 하지 않고 끝나는 갈래가 넷이다. 넷 다 **조용히** 끝나는 것은
  /// 이 자리에 사람이 보고 있는 화면이 없기 때문이다(앱을 여는 순간 배경에서
  /// 도는 판정이다):
  ///  - 방문이 아닌 판정 — 쓸 것이 없다.
  ///  - 이번 실행에서 이미 받은 경기 — 두 번째 쓰기를 아예 내보내지 않는다.
  ///  - 로그인한 계정이 없는 실행 — 도장을 쓸 자리가 없다(트리거가 로그인
  ///    게이트 안쪽이라 실사용에서는 서지 않는다).
  ///  - 일정에서 그 경기를 못 찾았거나, 구장×홈팀 짝이 판의 10칸 밖이거나,
  ///    `gameId` 가 도장 계약의 모양이 아닌 실행([_documentIdOf]) — 후보를 짓는
  ///    자리가 구장 문서에 없는 구장을 조용히 건너뛰는 것과 같은 판단이다
  ///    (두 콘텐츠 문서가 어긋난 실행에서 던지지 않는다).
  ///
  /// **낙관적으로 먼저 기억한다.** 쓰기가 서버에 닿기 전에 기억해 두는 것은
  /// 오프라인 갈래 때문이다 — 구장에서 통신이 끊기면 서버 확인이 복구 뒤에나
  /// 오는데, 그 사이의 포그라운드 복귀마다 GPS 를 다시 켜면 이 단계가 고치려던
  /// 바로 그 낭비가 남는다. 쓰기가 **실패하면** 그 기억을 도로 지워 다음
  /// 트리거가 다시 판정하게 한다.
  Future<void> award({
    required StadiumVisitResult result,
    required ScheduleDocument schedule,
  }) async {
    final stadiumId = result.stadiumId;
    final gameId = result.gameId;
    if (!result.isVisit || stadiumId == null || gameId == null) return;

    final documentId = _documentIdOf(stadiumId: stadiumId, gameId: gameId);
    if (documentId == null || state.contains(documentId)) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final stamp = _stampFor(
      stadiumId: stadiumId,
      gameId: gameId,
      schedule: schedule,
    );
    if (stamp == null) return;

    state = {...state, documentId};
    try {
      await ref.read(userDataStoreProvider).writeStamp(user.uid, stamp);
    } on BackendError {
      // 못 썼으면 아는 척하지 않는다 — 다음 트리거가 다시 판정하고 다시 쓴다.
      state = {...state}..remove(documentId);
    }
  }

  /// 판정 결과에 일정 문서의 홈팀·날짜를 붙여 도장 payload 를 짓는다.
  ///
  /// 홈팀을 일정에서 다시 찾는 것은 판정 결과가 그것을 들고 오지 않기
  /// 때문이다 — 후보 타입([StadiumVisitCandidate])에 팀 id 가 아예 없는 것이
  /// "홈·원정을 구분하지 않는다"는 계약을 타입에 박아 둔 자리다
  /// (decisions.md 2026-09-04 [S]). 잠실이 그날 홈팀에 따라 두 칸으로 갈리는
  /// 것도 이 한 줄이 정한다.
  ///
  /// **`gameDate` 도 여기서 미리 막는다.** `stadiumId`·`homeTeamId`·`gameId`
  /// 는 [_documentIdOf] 와 [kBoardCellIds] 검사가 이미 도장 계약의 모양으로
  /// 걸러 두었지만, 일정 문서의 `date` 는 콘텐츠 계약이 `YYYY-MM-DD` 정규식
  /// (`Game.fromJson`)으로 지켜 줄 뿐 이 계층 스스로는 재지 않았다 — 그
  /// `ArgumentError` 는 [StampWrite.toData] 안에 있어 [guardBackend] 밖이고
  /// [award] 는 [BackendError] 만 잡으므로, 안전이 콘텐츠 파서 하나에
  /// 걸려 있었다. `_documentIdOf` 와 같은 자리 — `toData()` 를 미리 불러
  /// 계약을 확인하고, 어긋나면 리그 어딘가의 잘못된 한 줄이 그날의 판정을
  /// 통째로 멈추지 않도록 조용히 지난다.
  StampWrite? _stampFor({
    required String stadiumId,
    required String gameId,
    required ScheduleDocument schedule,
  }) {
    for (final game in schedule.games) {
      if (game.id != gameId) continue;
      if (!kBoardCellIds.contains('${stadiumId}_${game.homeTeamId}')) {
        return null;
      }
      final stamp = StampWrite(
        stadiumId: stadiumId,
        gameId: gameId,
        homeTeamId: game.homeTeamId,
        gameDate: game.date,
      );
      try {
        stamp.toData();
      } on ArgumentError {
        return null;
      }
      return stamp;
    }
    return null;
  }
}
