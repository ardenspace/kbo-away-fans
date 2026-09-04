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
import '../../location/visit_check.dart';
import '../home/next_away_game.dart' show clockProvider;
import 'stamp_award.dart';

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
  /// **콘텐츠를 읽지 못한 실행에서는 판정하지 않고 상태를 그대로 둔다.**
  /// 일정을 모르면 "그날 경기가 없다"와 "일정을 못 읽었다"를 구분할 수 없고,
  /// 후자를 전자로 적으면 4.2 가 도장을 놓친 이유를 잘못 알게 된다.
  ///
  /// **이미 도장을 받은 경기만 남았으면 판정 자체를 건너뛴다** (4.2,
  /// decisions.md 2026-09-04 `[S]`). 트리거가 포그라운드 복귀마다 도는데,
  /// 도장을 이미 받은 뒤에도 계속 돌면 경기가 있는 날 앱을 켤 때마다 GPS 가
  /// 켜진다. 그 앎을 가진 계층이 [StampAward] 다 — 판정만 하는
  /// `lib/location/` 은 백엔드를 모른다.
  ///
  /// **도장 쓰기는 [_running] 밖에서 기다린다.** 이 빗장이 막으려는 것은
  /// 겹쳐 도는 **측위**이지 쓰기가 아니고, 오프라인에서는 서버 확인이 복구
  /// 뒤에나 오기 때문이다 — 그 기다림을 빗장 안에 두면 통신이 끊긴 구간
  /// 내내 다음 판정이 통째로 막힌다. 겹쳐 부른 도장 쓰기는 [StampAward] 가
  /// 자기 앎으로 막는다.
  Future<void> run() async {
    if (_running) return;
    _running = true;
    ScheduleDocument? schedule;
    StadiumVisitResult? result;
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
      if (award.coversAll(candidatesToJudge(candidates, now))) return;

      result = await ref
          .read(stadiumVisitCheckerProvider)
          .check(candidates: candidates, now: now);
      state = result;
    } finally {
      _running = false;
    }

    // 여기 닿았다는 것은 위 try 가 `return` 없이 끝났다는 뜻이라 둘 다 값이
    // 있다 (분석기가 그것을 알아 null 검사를 지우게 한다).
    await ref
        .read(stampAwardProvider.notifier)
        .award(result: result, schedule: schedule);
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
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() {
    if (!mounted) return;
    unawaited(ref.read(stadiumVisitProvider.notifier).run());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
