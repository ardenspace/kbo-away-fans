/// 배지 판이 방문이 아닌 판정을 안내하는 자리 (step 4.5).
///
/// `.wellbegun/begin.md` 의 실패 갈래("도장을 못 받는 날")를 실현한다:
/// 위치 확인이 안 되면 도장이 없고, 배지 탭은 **왜** 못 받는지 안내하며
/// 권한 문제면 설정으로 이어 준다 — 그러면서도 **판은 그대로 열리고**
/// (acceptance 셋째) 추천·좋아요·홈은 이 파일이 하는 일과 무관하게 그대로
/// 동작한다(acceptance 넷째 — 이 파일은 배지 탭 밖 어디에서도 쓰이지 않고,
/// [stadiumVisitProvider] 를 구독하는 자리도 이 파일 하나다).
///
/// **`ContentFallback`·`EmptyStateNotice` 어느 쪽도 아니다.** `REGISTRY.md`
/// 가 적은 대로 `ContentFallback` 은 "콘텐츠·사용자 데이터를 못 얻었다"이고
/// `EmptyStateNotice` 는 "얻었는데 하나도 없다"인데, 이 화면이 안내하는
/// 것은 **판정 결과값 그 자체가 말하는 뜻**이다 — 무언가를 읽는 데 실패한
/// 것이 아니라([StadiumVisitResult] 는 서버 왕복 없이 기기에서 이미 나온
/// 값이다), 사람에게 그 값의 도메인적 의미(권한이 없다·조건이 안 맞다)를
/// 옮기는 셋째 얼굴이다. 그래서 재사용하지 않고 새로 짓는다 — 로스터의
/// 두 위젯 다 이 뜻을 표현할 자리를 갖고 있지 않다(`onRetry` 는 "다시
/// 읽기"지 "권한을 다시 묻기"가 아니고, 재시도 문구도 고정돼 있다).
///
/// **이유 다섯을 안내 둘로 묶은 근거.** 계약(plan.md step 4.5)이 명령한
/// 갈래는 "권한 거부"·"판정 실패" 둘뿐이라 [StadiumVisitReason.permissionMissing]
/// 하나가 앞엣것이고 나머지 넷([StadiumVisitReason.noGameToday]·
/// [StadiumVisitReason.locationUnavailable]·[StadiumVisitReason.outsideRadius]·
/// [StadiumVisitReason.outsideTimeWindow])이 뒤엣것이다 — **권한이 있고
/// 없고**가 사람이 할 수 있는 일이 갈리는 유일한 경계이기 때문이다(권한이
/// 없으면 설정으로 갈 수 있고, 있으면 이 자리에서 할 수 있는 일이 없다).
/// 다만 네 이유가 사람에게 하는 말은 같지 않다(`noGameToday` 는 "당신
/// 탓이 아니다", `outsideRadius` 는 "구장에 있지 않다") — 그래서 "판정
/// 실패"라는 한 얼굴 **안에서** 이유마다 다른 문구를 쓴다. 계약이 요구한
/// "다른 문구로 안내한다"를 이유 넷 모두에서 지키면서도, 시험이 요구하는
/// "두 안내"라는 경계(권한 유무)는 그대로 둔다.
///
/// **재요청 가능 여부는 이 자리에서 새로 묻는다.** [StadiumVisitReason.permissionMissing]
/// 은 `denied`·`permanentlyDenied` 를 하나로 접은 값이다(4.1 의 의도된
/// 설계, `lib/location/CLAUDE.md` 참조) — 그 문서가 "다시 물을 수 있는지를
/// 갈라야 하는 자리는 그때 `LocationPermissionGateway.status()` 를 그
/// 자리에서 물으면 된다"고 남긴 자리가 여기다. 그래서 [_PermissionMissingNotice]
/// 는 [locationPermissionGatewayProvider] 에 **다시** 묻고, 그 답에 따라
/// 버튼을 가른다: `denied` 면 [LocationPermissionGateway.request] 로 앱
/// 안에서 OS 다이얼로그를 다시 띄우고, `permanentlyDenied` 면
/// [LocationPermissionGateway.openSettings] 로 설정 앱을 연다. 앱 안에서
/// 다시 물어 허용을 받으면(설정에 다녀올 필요가 없는 갈래) 그 자리에서
/// [StadiumVisitCheck.run] 을 한 번 더 불러 판정을 다시 돈다 — 그러지
/// 않으면 다음 포그라운드 복귀까지 기다려야 한다. `permanentlyDenied` 뒤
/// 설정에 다녀오면 앱이 배경→포그라운드를 지나므로 `StadiumVisitTrigger` 의
/// `resumed` 가 이미 다시 판정한다(따로 부를 필요가 없다).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../location/location.dart';
import '../../location/visit_check.dart';
import 'stadium_visit.dart';

/// [StadiumVisitReason.permissionMissing] 을 다시 물을 수 있는지 — 4.1 이
/// 접어 둔 두 갈래를 이 자리에서 다시 벌린다.
final _permissionMissingStatusProvider =
    FutureProvider.autoDispose<LocationPermissionStatus>(
      (ref) => resolveLocationPermission(
        () => ref.read(locationPermissionGatewayProvider).status(),
      ),
    );

/// 배지 탭에 얹는 안내 — 가장 최근 방문 판정([stadiumVisitProvider])이
/// 방문이 아니면 이유를 보여주고, 아직 판정이 없거나(null) 방문이면 아무것도
/// 그리지 않는다(판 자체는 이 위젯과 무관하게 항상 열려 있다).
class VisitStatusNotice extends ConsumerWidget {
  const VisitStatusNotice({super.key});

  /// 권한 거부 안내 제목·설명.
  static const String permissionMissingTitle = '위치 권한이 없어서 도장을 확인하지 못했어요';
  static const String permissionMissingMessage =
      '위치 권한을 허용하면 구장에 도착했을 때 자동으로 도장을 받을 수 있어요.';

  /// 권한을 앱 안에서 다시 물을 수 있을 때의 버튼 문구.
  static const String requestPermissionLabel = '위치 권한 허용하기';

  /// 영구 거절 뒤 설정 앱으로 보낼 때의 버튼 문구.
  static const String openSettingsLabel = '설정에서 허용하기';

  /// 판정 실패(경기가 없음) 안내.
  static const String noGameTodayTitle = '오늘은 열리는 경기가 없어요';
  static const String noGameTodayMessage = '경기가 있는 날 구장 근처에서 앱을 열면 도장이 찍혀요.';

  /// 판정 실패(반경 밖) 안내.
  static const String outsideRadiusTitle = '구장에서 좀 떨어져 있어요';
  static const String outsideRadiusMessage = '구장 근처에 도착하면 자동으로 도장이 찍혀요.';

  /// 판정 실패(시간 창 밖) 안내.
  static const String outsideTimeWindowTitle = '지금은 도장을 받을 시간이 아니에요';
  static const String outsideTimeWindowMessage =
      '경기 시작 전후 정해진 시간 안에 구장에 있어야 도장이 찍혀요.';

  /// 판정 실패(위치를 못 얻음) 안내.
  static const String locationUnavailableTitle = '위치를 확인하지 못했어요';
  static const String locationUnavailableMessage =
      '위치 서비스가 켜져 있는지 확인하고 앱을 다시 열어보세요.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visit = ref.watch(stadiumVisitProvider);
    if (visit == null || visit.isVisit) return const SizedBox.shrink();

    if (visit.reason == StadiumVisitReason.permissionMissing) {
      return const _PermissionMissingNotice();
    }
    final (title, message) = _judgmentFailureCopy(visit.reason);
    return _NoticeCard(title: title, message: message);
  }

  static (String, String) _judgmentFailureCopy(StadiumVisitReason reason) =>
      switch (reason) {
        StadiumVisitReason.noGameToday => (
          noGameTodayTitle,
          noGameTodayMessage,
        ),
        StadiumVisitReason.outsideRadius => (
          outsideRadiusTitle,
          outsideRadiusMessage,
        ),
        StadiumVisitReason.outsideTimeWindow => (
          outsideTimeWindowTitle,
          outsideTimeWindowMessage,
        ),
        StadiumVisitReason.locationUnavailable => (
          locationUnavailableTitle,
          locationUnavailableMessage,
        ),
        // 부르는 쪽([build])이 이미 걸러 낸다 — 여기 닿지 않는다.
        StadiumVisitReason.permissionMissing ||
        StadiumVisitReason.visited => throw ArgumentError(
          '판정 실패 문구는 방문·권한 거부 갈래를 받지 않는다: $reason',
        ),
      };
}

/// 권한 거부 안내 — [LocationPermissionGateway.status] 를 다시 물어 재요청
/// 가능 여부([LocationPermissionStatus.denied] vs
/// [LocationPermissionStatus.permanentlyDenied])로 버튼을 가른다.
class _PermissionMissingNotice extends ConsumerWidget {
  const _PermissionMissingNotice();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(_permissionMissingStatusProvider);
    // 아직 답이 없는 짧은 구간은 "아직 물어볼 수 있는 상태"로 다룬다 —
    // `resolveLocationPermission` 이 알아내지 못한 실행을 `denied` 로 접는
    // 것과 같은 판단이다(`lib/location/location.dart` 문서 참조).
    final permanentlyDenied =
        statusAsync.value == LocationPermissionStatus.permanentlyDenied;

    return _NoticeCard(
      title: VisitStatusNotice.permissionMissingTitle,
      message: VisitStatusNotice.permissionMissingMessage,
      actionLabel: permanentlyDenied
          ? VisitStatusNotice.openSettingsLabel
          : VisitStatusNotice.requestPermissionLabel,
      onAction: () =>
          _handleTap(context, ref, permanentlyDenied: permanentlyDenied),
    );
  }

  Future<void> _handleTap(
    BuildContext context,
    WidgetRef ref, {
    required bool permanentlyDenied,
  }) async {
    final gateway = ref.read(locationPermissionGatewayProvider);
    if (permanentlyDenied) {
      await gateway.openSettings();
    } else {
      final result = await resolveLocationPermission(gateway.request);
      if (result == LocationPermissionStatus.granted && context.mounted) {
        // 설정에 다녀올 필요가 없는 갈래라 포그라운드 복귀 신호가 없다 —
        // 다음 트리거를 기다리지 않고 이 자리에서 바로 판정을 다시 돈다.
        await ref.read(stadiumVisitProvider.notifier).run();
      }
    }
    // 위젯이 그사이 사라졌을 수 있다(비동기 기다림 중 화면을 떠난 경우) —
    // 사라진 뒤의 `ref` 는 리버팟이 안전하지 않다고 못 박은 자리다
    // (`lib/ui/shared/place_like_wiring.dart` 의 `notifyPlaceLikeFailed` 와
    // 같은 방식).
    if (context.mounted) {
      ref.invalidate(_permissionMissingStatusProvider);
    }
  }
}

/// 안내 한 장 — 제목 + 설명 + (있으면) 행동 버튼.
///
/// `ContentFallback` 과 뼈대가 닮아 있지만 문서 첫머리가 적은 대로 다른
/// 뜻을 나르는 자리라 그 위젯을 갈아 쓰지 않는다.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        SpaceTokens.lg,
        SpaceTokens.lg,
        SpaceTokens.lg,
        0,
      ),
      padding: const EdgeInsets.all(SpaceTokens.lg),
      decoration: BoxDecoration(
        color: ColorTokens.surface,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(color: ColorTokens.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextTokens.sectionTitle),
          const SizedBox(height: SpaceTokens.sm),
          Text(message, style: TextTokens.bodyMuted),
          if (actionLabel case final String label) ...[
            const SizedBox(height: SpaceTokens.md),
            FilledButton(
              onPressed: onAction,
              child: Text(label, style: TextTokens.inheritColor(TextTokens.label)),
            ),
          ],
        ],
      ),
    );
  }
}
