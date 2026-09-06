/// 구장 방문 판정을 앱에 잇는 자리 (step 4.1) — 콘텐츠 문서를 판정 후보로
/// 옮기고, 앱이 열려 있는 동안 판정을 한 번 돌린다.
///
/// **왜 이 계층인가.** 판정 자체와 좌표는 `lib/location/visit_check.dart` 에
/// 있고 그 계층은 콘텐츠 문서의 모양도, 백엔드도 알지 않는다
/// (`lib/location/CLAUDE.md`: 두 계층을 잇는 자리는 부르는 쪽인 feature 다).
/// 그래서 "일정과 구장 좌표를 읽어 후보를 짓는 일"과 "언제 판정할 것인가"가
/// 여기 있고, 4.2 는 이 파일이 내놓는 결과([stadiumVisitProvider])를 보고
/// 도장을 쓴다. 이 파일은 좌표를 만지지 않는다 — 구장 좌표는
/// [buildStadiumVisitCandidates] 가 후보로 옮기는 순간 판정 계층의 것이 되고,
/// **기기의** 좌표는 이 계층에 값으로 오지 않는다.
///
/// 다만 "값으로 오지 않는다"가 "알아낼 수 없다"는 뜻은 아니다. 후보를 짓는
/// 쪽이 이 계층이므로, 여기서 지어 낸 후보로 판정을 반복해 부르면 기기 좌표가
/// 좁혀진다(`lib/location/visit_check.dart` 첫 문단의 "하지 않는 약속",
/// `.wellbegun/decisions.md` 2026-09-04 `[L]`). 이 파일이 실제로 짓는 후보는
/// 콘텐츠 문서의 구장 아홉 곳뿐이고, 그 사실을 바꾸는 변경은 리뷰에서 보인다.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../content/content_loader.dart';
import '../../content/content_providers.dart';
import '../../content/kst.dart';
import '../../content/models.dart';
import '../../location/location.dart' show locationPermissionStatusProvider;
import '../../location/visit_check.dart';
import '../home/next_away_game.dart' show clockProvider;
import 'stamp_award.dart';
import 'stamp_reveal.dart' show stampCelebrationProvider;

/// 일정·구장 문서를 판정 후보 목록으로 옮긴다.
///
/// - **팀으로 거르지 않는다.** 계약이 "홈·원정을 구분하지 않는다 — 그 구장에
///   있었는지만 본다"이므로, 응원 팀이 뛰지 않는 경기도 후보다.
/// - **취소된 경기는 후보가 아니다.** `canceled`·`rain_canceled` 는 그날 그
///   구장에서 경기가 열리지 않았다는 뜻이라 `[L]` 결정의 첫 조건("그 구장에
///   그날 경기가 있고")을 만족하지 않는다. 우천 취소로 헛걸음한 날은 4.5
///   ("못 받는 날")의 몫이지 도장이 아니다.
/// - **끝난 경기(`finished`)는 후보로 남는다.** 경기가 끝난 뒤 구장에서 앱을
///   여는 사람이 있고, 시간 창의 뒤쪽([kVisitWindowAfterStart])이 바로 그
///   사람을 위한 구간이다.
/// - 구장 문서에 없는 `stadiumId` 는 조용히 건너뛴다 — 좌표를 모르면 반경을
///   잴 수 없다. 두 문서가 어긋난 실행에서 판정이 던지지 않게 한다.
List<StadiumVisitCandidate> buildStadiumVisitCandidates({
  required ScheduleDocument schedule,
  required StadiumsDocument stadiums,
}) {
  final candidates = <StadiumVisitCandidate>[];
  for (final game in schedule.games) {
    final open = switch (game.status) {
      GameStatus.scheduled || GameStatus.finished => true,
      GameStatus.canceled || GameStatus.rainCanceled => false,
    };
    if (!open) continue;
    final stadium = stadiums.byId(game.stadiumId);
    if (stadium == null) continue;
    candidates.add(
      StadiumVisitCandidate(
        gameId: game.id,
        stadiumId: game.stadiumId,
        startsAt: gameStartsAt(game),
        lat: stadium.lat,
        lng: stadium.lng,
      ),
    );
  }
  return candidates;
}

/// 가장 최근 판정의 결과 — 아직 한 번도 돌지 않았으면 null.
///
/// 방문이 아닌 결과도 **이유와 함께** 남는다(계약: "위치 권한이 없으면
/// 판정을 시도하지 않고 이유가 남는다"). 4.2 는 이 값이
/// [StadiumVisitResult.isVisit] 일 때만 도장을 쓴다.
final stadiumVisitProvider =
    NotifierProvider<StadiumVisitCheck, StadiumVisitResult?>(
      StadiumVisitCheck.new,
    );

/// 마지막 판정 **시도**가 남긴 기록 — 언제 돌았고, 판정까지 갔는가.
///
/// [stadiumVisitProvider] 하나로는 "지금 어디에 있는가"에 답할 수 없다. 그
/// 값은 마지막으로 **판정이 난** 결과일 뿐, 그 뒤로 트리거가 몇 번 더 돌았고
/// 그 실행들이 측위를 건너뛰었는지는 말해 주지 않는다. 5.2 가 그 값을 "현재
/// 위치"로 읽으면서 그 틈이 드러났다 — 도장을 받고 나면
/// [StampAward.judgingAddsNothing] 게이트가 시간 창이 닫힐 때까지 판정을
/// 건너뛰므로, 구장을 떠나 집에 온 사람의 홈 상단이 몇 시간 동안 그 구장을
/// 계속 가리켰다(phase 5 통합 검증의 REJECT 사유).
///
/// **답은 측위를 다시 켜는 쪽이 아니다** — 그것은 4.2 의 절제를 되돌리는
/// 것이다(decisions.md 2026-09-04 `[S]`). 앱이 모르면 모른다고 말하면 된다.
/// 그러려면 판정 결과와 함께 **그 답이 언제 난 것인지**가 필요하고, 이
/// 기록이 그 자리다. 이 값은 좌표가 아니라 **시각과 참·거짓 하나**다.
///
/// 두 물음을 두 자리로 가른다 — [judged] 는 "**이** 실행이 판정했는가",
/// [judgedAt] 은 "손에 든 판정이 **언제** 난 것인가". 앞엣것은 판정 안의
/// 권한을 지금으로 읽어도 되는지를 5.2 가 가르는 데 쓰고(round 3), 뒤엣것은
/// 구장 이름의 나이를 재는 데 쓴다(round 1·2). 한 값에 겹쳐 두었을 때는
/// 건너뛴 실행 하나가 나이를 통째로 지워 버렸다([judgedAt] 문서 참조).
///
/// **이 타입은 판정 계층의 값이 화면 계층으로 나가는 통로다.** phase 5 가 그
/// 통로를 처음 열었고, 처음에는 못이 하나도 없었다 — 여기에 `this.lat`·
/// `this.lng` 를 더해도 `flutter analyze` 가 무지적이고 훅 4종이 전부 exit 0
/// 이었다(phase 5 통합 검증 round 2 의 실측. `check-no-location-upload.sh` 의
/// 선언 검사 범위가 `lib/location`·`lib/content/kst.dart`·`lib/backend` 뿐이라
/// `lib/features/` 는 그 시야 밖이다). 지금은 **값을 두는 자리 집합 자체**가
/// `test/features/badges/visit_check_test.dart` 에 못 박혀 있다 —
/// `StadiumVisitResult`·`StadiumVisitCandidate` 를 재는 그 파수꾼들과 같은
/// 방식이고, 같은 세기의 약속이다("실수로는 지나갈 수 없다"). 여기 값 자리를
/// 하나라도 더하거나 이름을 바꾸면 그 시험이 빨간불이다.
class StadiumVisitRun {
  const StadiumVisitRun({required this.judged, required this.judgedAt});

  /// **이** 실행이 판정까지 갔는가. 거짓이면 그 실행은 게이트에서(또는
  /// 콘텐츠를 못 얻어) 일찍 끝났고, [stadiumVisitProvider] 의 값은 그
  /// **이전** 실행의 답이다 — 그 답 안의 "권한이 있었다"까지 함께 옛
  /// 것이라, 5.2 는 그때 권한을 다시 묻는다(phase 5 통합 검증 round 3).
  final bool judged;

  /// 손에 든 판정([stadiumVisitProvider] 의 값)이 **난 시각** — 한 번도
  /// 판정된 적이 없으면 null.
  ///
  /// **건너뛴 실행을 지나도 이 값은 그대로 남는다.** 이 자리가 갈려 있지
  /// 않던 동안에는 "이 실행이 판정했는가"와 "손에 든 판정이 언제 난
  /// 것인가"가 한 값에 겹쳐 있었고, 그래서 도장을 받은 사람이 구장에 **그대로
  /// 선 채** 앱을 한 번 오가기만 해도 나이가 잴 수 없는 것이 되어 구장 이름이
  /// 곧바로 일반 문구로 내려갔다(실측: 도장 5분 뒤 복귀에 구장명 1 → 0).
  /// 그러면 [kCurrentLocationFreshness] 가 실제로 쓰이는 구간이 "도장을 못
  /// 받은 갈래"로 좁아진다 — 나이를 재라고 둔 잣대가 정작 구장에 선 사람
  /// 에게는 한 번도 쓰이지 않는 셈이다(계약 밖 발견 F1). 두 물음을 두
  /// 자리로 가른다.
  final DateTime? judgedAt;

  @override
  String toString() => 'StadiumVisitRun(judged: $judged, judgedAt: $judgedAt)';
}

/// 마지막 판정 시도의 기록 — 아직 한 번도 시도하지 않았으면 null.
///
/// [stadiumVisitProvider] 와 짝으로 [StadiumVisitCheck.run] 이 함께 남긴다.
/// 두 값을 한 provider 에 담지 않은 것은 판정 결과를 읽는 자리(4.5 의
/// `VisitStatusNotice`·5.2 의 홈 상단)가 이미 여럿이라 그 타입을 바꾸면
/// 판정과 무관한 자리까지 함께 흔들리기 때문이다.
final stadiumVisitRunProvider =
    NotifierProvider<StadiumVisitRunLog, StadiumVisitRun?>(
      StadiumVisitRunLog.new,
    );

/// [stadiumVisitRunProvider] 의 쓰기 자리 — [StadiumVisitCheck.run] 만 쓴다.
class StadiumVisitRunLog extends Notifier<StadiumVisitRun?> {
  @override
  StadiumVisitRun? build() => null;

  void record(StadiumVisitRun run) => state = run;
}

/// 판정을 한 번 돌리는 자리.
class StadiumVisitCheck extends Notifier<StadiumVisitResult?> {
  @override
  StadiumVisitResult? build() => null;

  /// 이미 도는 판정이 있는가 — 겹쳐 도는 것을 막는다.
  ///
  /// 트리거가 둘(첫 프레임·포그라운드 복귀)이라 짧은 간격으로 두 번 불릴 수
  /// 있는데, 그때 OS 에 측위를 두 번 요청할 이유가 없다.
  bool _running = false;

  /// 판정을 한 번 돌리고 결과를 [state] 에 남긴 뒤, 방문이면 도장을 쓴다.
  ///
  /// **어떻게 끝났든 [stadiumVisitRunProvider] 에 기록을 남긴다** — 판정이
  /// 돌았는지(`judged`)와 그 실행이 본 시각. 상태를 그대로 두고 일찍 반환하는
  /// 두 갈래(콘텐츠를 못 얻음·재판정 게이트)가 있는 한, 결과값만으로는 그것이
  /// **지금**의 답인지 알 수 없기 때문이다.
  ///
  /// **콘텐츠를 읽지 못한 실행에서는 판정하지 않고 상태를 그대로 둔다.**
  /// 일정을 모르면 "그날 경기가 없다"와 "일정을 못 읽었다"를 구분할 수 없고,
  /// 후자를 전자로 적으면 4.2 가 도장을 놓친 이유를 잘못 알게 된다.
  ///
  /// **다시 판정해도 새 도장이 나올 수 없으면 판정 자체를 건너뛴다** (4.2,
  /// decisions.md 2026-09-04 `[S]`). 트리거가 포그라운드 복귀마다 도는데,
  /// 도장을 이미 받은 뒤에도 계속 돌면 경기가 있는 날 앱을 켤 때마다 GPS 가
  /// 켜진다. 그 앎을 가진 계층이 [StampAward] 다 — 판정만 하는
  /// `lib/location/` 은 백엔드를 모른다. 무엇을 근거로 닫히는지는
  /// [StampAward.judgingAddsNothing] 이 적는다(리그 전체가 아니라 **도장이
  /// 말해 주는 그 구장**을 본다).
  ///
  /// **도장 쓰기는 [_running] 밖에서 기다린다.** 이 빗장이 막으려는 것은
  /// 겹쳐 도는 **측위**이지 쓰기가 아니다 — 쓰기의 기다림을 빗장 안에 두면
  /// 그 기다림이 길어지는 만큼 다음 판정이 통째로 막힌다. 겹쳐 부른 도장
  /// 쓰기는 [StampAward] 가 자기 앎으로 막는다. (그 기다림은 이제 짧다 —
  /// [UserDataStore.writeStamp] 가 쓰기의 **로컬 확정**에서 끝나고 서버 확인은
  /// [StampWriteReceipt.serverConfirmed] 로 따로 흐르기 때문이다. 그래도 빗장
  /// 밖에 두는 것은 위 까닭이 기다림의 길이와 무관하게 서기 때문이다.)
  Future<void> run() async {
    if (_running) return;
    _running = true;
    ScheduleDocument? schedule;
    StadiumVisitResult? result;
    // 손에 든 판정이 난 시각 — 이 실행이 판정하면 그때의 "지금"으로 바뀌고,
    // 판정까지 가지 못하면 **이전 값 그대로** 남는다(그래야 게이트에 막힌
    // 실행 하나가 구장 이름의 나이를 통째로 지우지 않는다).
    DateTime? judgedAt = ref.read(stadiumVisitRunProvider)?.judgedAt;
    try {
      schedule = await _document(scheduleProvider);
      final stadiums = await _document(stadiumsProvider);
      if (schedule == null || stadiums == null) return;

      final candidates = buildStadiumVisitCandidates(
        schedule: schedule,
        stadiums: stadiums,
      );
      final now = ref.read(clockProvider)();
      final award = ref.read(stampAwardProvider.notifier);
      if (award.judgingAddsNothing(candidates, now)) return;

      result = await ref
          .read(stadiumVisitCheckerProvider)
          .check(candidates: candidates, now: now);
      state = result;
      judgedAt = now;
    } finally {
      _running = false;
      // **일찍 반환한 실행도 기록을 남긴다.** 이 자리가 (A) 를 닫는 못이다 —
      // 게이트가 닫혀 판정을 건너뛴 실행 뒤에는 `judged: false` 가 남고, 그
      // 값을 읽는 5.2 는 손에 든 판정이 "지금"이 아님을 알게 된다(구장
      // 이름을 쓰지 않고, 그 안의 권한도 다시 묻는다). 판정 결과([state])는
      // 건드리지 않으므로 4.5 의 안내와 4.3 의 판은 그대로다.
      //
      // **그러면서 [StadiumVisitRun.judgedAt] 은 그대로 이어 준다** — 건너뛴
      // 실행은 판정을 낡게 만들지 않는다. 그 실행이 나이까지 지우면 구장에
      // 그대로 선 사람이 앱을 한 번 오간 것만으로 구장 이름을 잃는다(F1).
      //
      // 버려진 뒤인지를 먼저 묻는 것은 아래 연출 큐와 같은 까닭이다 — 콘텐츠
      // 로드·측위를 기다리는 사이에 이 provider 가 버려질 수 있다.
      if (ref.mounted) {
        ref
            .read(stadiumVisitRunProvider.notifier)
            .record(
              StadiumVisitRun(judged: result != null, judgedAt: judgedAt),
            );
      }
    }

    // 여기 닿았다는 것은 위 try 가 `return` 없이 끝났다는 뜻이라 둘 다 값이
    // 있다 (분석기가 그것을 알아 null 검사를 지우게 한다).
    final awarded = await ref
        .read(stampAwardProvider.notifier)
        .award(result: result, schedule: schedule);
    // 이번에 실제로 찍힌 도장만 연출 큐에 올린다(4.4) — award 가 null 을
    // 돌려주는 나머지 갈래(방문이 아님·이미 받음·계정 없음 등)는 보여줄
    // 것이 없는 실행이다.
    //
    // **여기가 "도장이 찍히는 순간"이다.** [StampAward.award] 는 쓰기가
    // 로컬에 확정된 순간 돌아오므로(4.2 가 `WriteBatch` 를 고르며 정한 그
    // 순간이다), 통신이 끊긴 구장에서도 이 줄이 그 자리에서 선다. 서버의
    // 뒤늦은 답을 기다리던 옛 배선이 phase 4 통합 검증의 REJECT 사유였다.
    //
    // **버려진 뒤인지를 먼저 묻는다.** 이 자리는 콘텐츠 로드·측위·쓰기를
    // 차례로 기다린 **뒤**라, 그 사이에 이 provider 가 버려지면 버려진 `Ref`
    // 로 다른 provider 를 읽는 셈이 되어 리버팟이 던진다. 그 실행에서는
    // 연출을 조용히 거른다: 큐를 받을 화면이 이미 없고, 도장은 이 줄과
    // 무관하게 벌써 확정되어 있다.
    //
    // **이 가드를 지금 붙잡아 두는 시험은 없다.** 옛 배선에서는 오프라인의
    // 긴 기다림이 그 창을 넓게 벌려 `test/backend/stamp_write_test.dart` 의
    // "오프라인에서 아직 서버 확인이 안 온 도장이 다음 판정을 막지 않는다"가
    // 던짐을 잡았는데, 기다림이 짧아진 지금은 그 시험에서 창이 닫혔다(실측:
    // `ref.mounted` 를 지워도 저장소 전체가 초록불이다). 같은 성질을 실제로
    // 재는 자리는 이제 [StampAward] 쪽 짝뿐이다("버려진 뒤에 온 서버의 거부는
    // 조용히 지난다") — 서버 확인은 여전히 길게 늦고, 그 콜백의 가드는 그
    // 시험이 지운 순간 빨간불이 된다.
    if (awarded != null && ref.mounted) {
      ref.read(stampCelebrationProvider.notifier).show(awarded);
    }
  }

  /// 콘텐츠 문서 하나를 "값 아니면 null" 로 — 로드가 끝나기를 기다린 뒤
  /// [contentDataOf] 의 같은 규칙으로 편다(판정용으로 규칙을 따로 만들지
  /// 않는다).
  Future<T?> _document<T>(FutureProvider<ContentResult<T>> provider) async {
    try {
      await ref.read(provider.future);
    } catch (_) {
      // 로드 실패는 아래 contentDataOf 가 null 로 편다 — 이 계층이 콘텐츠
      // 오류를 따로 해석하지 않는다.
    }
    return contentDataOf(ref.read(provider));
  }
}

/// 판정을 트리거하는 자리 — [child] 를 그대로 그리고 생명주기만 지켜본다.
///
/// **왜 여기서 트리거하는가** (`plan.md` step 4.1 의 discretion "판정을
/// 트리거하는 시점"). `[L]` 결정이 백그라운드 위치를 거절하면서 남긴 것이
/// "사용자가 구장에서 앱을 열어야 하는데, 그 행동이 오히려 도장 획득 순간을
/// 만든다"였다. 그러면 판정은 **앱을 여는 것 자체**에 걸려야 하고, 배지 탭을
/// 찾아 들어가는 동작에 걸려서는 안 된다 — 구장에서 앱을 연 사람은 보통 홈을
/// 본다. 그래서 로그인·온보딩을 지난 사람이 닿는 골격
/// (`MainTabsRoot`)에 이 위젯을 둘러 두 시점에 돌린다:
///
/// - **첫 프레임** — 콜드 스타트로 앱을 연 실행.
/// - **포그라운드 복귀(`resumed`)** — 앱을 켜 둔 채 구장에 도착했거나,
///   경기 시작을 기다리다 화면을 다시 켠 실행. `lib/app.dart` 가 같은 신호로
///   콘텐츠를 다시 읽으므로, 그 새 일정 위에서 판정이 다시 돈다.
///
/// 로그인 게이트 안쪽인 것도 의도다 — 판정 결과를 쓸 계정이 없는 실행에서는
/// OS 에 측위를 물을 이유가 없다.
///
/// **복귀마다 판정과 함께 [locationPermissionStatusProvider] 도 새로 낸다.**
/// 판정 하나로는 권한을 다 말하지 못한다 — [judgeStadiumVisit] 이 후보
/// 게이트를 권한보다 먼저 보므로, 경기 없는 날(월요일·비시즌 전체)의 재판정은
/// 권한을 묻지 않고 [StadiumVisitReason.noGameToday] 로 끝난다. 그 갈래에서
/// 권한을 대신 답하는 자리가 그 provider 이고(4.5 의 배지 탭 안내와 5.2 의 홈
/// 상단이 함께 쓴다), 그것이 [FutureProvider.autoDispose] 라 **한 실행에서 딱
/// 한 번만 답이 났다**: 사람이 OS 설정에서 권한을 끄고(또는 켜고) 돌아와도
/// 홈 상단은 옛 답을 계속 읽었다(phase 5 통합 검증 round 2 의 REJECT 사유,
/// 실측으로 권한 조회 횟수가 복귀 전후 1 → 1 이었다). 이 자리가 그 답을
/// 판정과 같은 신호에 매단다.
///
/// **[LocationPermissionGateway.request] 는 여전히 지나지 않는다** — 다시
/// 여는 것은 다이얼로그 없는 조회 하나뿐이고, 그 진입점은 4.5 의 몫이다.
/// 되묻는 주기도 **복귀당 한 번**이다: 홈이 빌드될 때마다 묻는 모양은 위치
/// 게이트웨이를 override 하지 않는 부팅 시험들을 무더기로 깨뜨린 적이 있다
/// (`current_location.dart` 첫머리 참조). 아무도 구독하지 않는 동안에는
/// [Ref.invalidate] 가 그 provider 를 **만들지도 않는다**(실측: 구독 없는
/// `autoDispose` 를 invalidate 해도 생성 횟수가 0 이다) — 그래서 권한을 물을
/// 까닭이 없는 갈래에서는 이 줄이 조회를 하나도 만들지 않는다.
class StadiumVisitTrigger extends ConsumerStatefulWidget {
  const StadiumVisitTrigger({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<StadiumVisitTrigger> createState() =>
      _StadiumVisitTriggerState();
}

class _StadiumVisitTriggerState extends ConsumerState<StadiumVisitTrigger>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 빌드 도중에 다른 provider 를 고칠 수 없으므로 한 프레임 뒤로 미룬다
    // (2.5 의 위치 권한 게이트가 같은 까닭으로 같은 모양을 쓴다).
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 판정보다 먼저 권한 답을 버린다 — 그래야 이 복귀에서 다시 그리는 화면이
    // 옛 답을 한 프레임도 참으로 쓰지 않는다. 구독하는 화면이 없으면 아무
    // 조회도 생기지 않는다(위 문서 참조).
    if (mounted) ref.invalidate(locationPermissionStatusProvider);
    _check();
  }

  void _check() {
    if (!mounted) return;
    unawaited(ref.read(stadiumVisitProvider.notifier).run());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
