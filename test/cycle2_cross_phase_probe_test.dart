/// 사이클 2 전체 리뷰 탐침 — 다섯 phase 를 **한 실행으로** 가로지른다.
///
/// phase 별 통합 탐침은 각자 자기 phase 안만 걷는다. 특히 두 자리가 비어 있다:
///
///  - `phase2_journey_probe_test.dart` 는 앱 전체(`KboAwayFansApp`, 로그인
///    게이트부터)를 세우지만 schedule 을 **언제나 비워** 두어 홈 아래(3.x·4.x·5.x)
///    로는 내려가지 않는다.
///  - `phase4_seam_probe_test.dart` 는 도장·판·연출을 끝까지 걷지만
///    `MainTabsRoot` 를 **직접** 세운다 — 로그인 게이트도, 팀 선택도, 계정이
///    바뀌는 자리도 그 위에 없다.
///
/// 그래서 이 파일은 로그인 게이트에서 시작해 콘텐츠 파이프라인의 **실 산출물**
/// (`content-pipeline/data/*.json` 네 개 전부)을 물리고, 한 사람이
/// 로그인 → 팀 선택 → 위치 권한 → 5탭 → 홈(D-day·최근 5경기·현재 위치) →
/// 장소 좋아요 → 구장 방문 판정 → 도장 → 판 → 로그아웃 →
/// **다른 계정 로그인**까지 한 번에 걷는다.
///
/// 마지막 구간이 이 탐침의 값이다: 앞사람의 팀·좋아요·판이 새 계정의 화면에
/// 남는지를 **앱 전체**에서 잰다(기존 시험들은 그 자리를 상태 계층이나
/// 탭 뿌리에서만 재었다).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/app.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/features/auth/sign_in_screen.dart';
import 'package:kbo_away_fans/features/badges/stamp_reveal.dart';
import 'package:kbo_away_fans/features/home/current_location.dart';
import 'package:kbo_away_fans/features/home/home_screen.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/features/likes/likes_tab_screen.dart';
import 'package:kbo_away_fans/features/onboarding/location_consent.dart';
import 'package:kbo_away_fans/features/profile/profile_tab_screen.dart';
import 'package:kbo_away_fans/features/team_select/team_select_screen.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';
import 'package:kbo_away_fans/ui/shared/like_button.dart';
import 'package:kbo_away_fans/ui/shared/place_card.dart';
import 'package:kbo_away_fans/ui/shared/social_sign_in_button.dart';
import 'package:kbo_away_fans/ui/shared/stamp_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend/fake_backend.dart';
import 'content/live_schedule.dart';
import 'location/fake_location_permission_gateway.dart';

/// 첫 계정이 응원 팀으로 **먼저 보는** 팀 — 이 팀의 일정에 걸을 경기가 없으면
/// 앵커가 다른 팀으로 넘어간다([AwayGameAnchor.teamId] 가 실제로 고른 팀이다).
const String _teamId = 'lg';

/// 두 번째 계정이 고르는 팀 — 앞사람의 것이 남지 않았는지 보려면 첫 계정과
/// **다른 팀**이기만 하면 된다. 어느 팀인지는 팀 문서에서 고른다.
Team get _otherTeam =>
    _content.teams.teams.firstWhere((team) => team.id != _anchor.teamId);

/// 실 산출물 네 문서와, 이 여정이 걷는 원정 경기.
///
/// 경기를 리터럴로 박지 않는 까닭은 `test/content/live_schedule.dart` 의 첫
/// 문단에 있다 — 일정 문서는 크롤이 경기 시간대에 20분마다 다시 쓰고, 그 창은
/// 앞뒤로 움직인다(이 파일의 `8/27` 단언이 실제로 그렇게 빨간불이 됐다).
late LiveContent _content;
late AwayGameAnchor _anchor;

/// 구장 안에 선 기기 — 앵커 경기가 열리는 구장의 좌표.
DeviceFix get _atStadium =>
    DeviceFix(lat: _anchor.stadium.lat, lng: _anchor.stadium.lng);

/// 구장에서 멀리 떨어진 지점 — 계정을 바꾸기 전에 기기를 여기로 옮긴다.
const DeviceFix _farAway = DeviceFix(lat: kOffStadiumLat, lng: kOffStadiumLng);

/// 기기가 지금 어디 있는가 — 걸어가면서 바꾼다.
class _Where {
  DeviceFix fix = _atStadium;
}

Finder _buttonOf(AuthProviderId provider) => find.byWidgetPredicate(
  (widget) => widget is SocialSignInButton && widget.provider == provider,
);

/// 도장 연출이 떠 있으면 먼저 걷어 낸다 — 연출은 화면 전체를 덮으므로 그
/// 위로는 탭이 닿지 않는다(`phase4_seam_probe_test.dart` 의 `_openBadges` 와
/// 같은 처리).
Future<void> _dismissReveal(WidgetTester tester) async {
  if (find.byType(StampReveal).evaluate().isEmpty) return;
  await tester.tap(find.byType(StampReveal));
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await _dismissReveal(tester);
  final finder = find.text(text).first;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    // 네 문서 다 **실 산출물**을 그대로 판다 — 파이프라인의 계약과 앱의 파서가
    // 어긋나면 여기서 던진다(schedule 은 이 사이클에서 schemaVersion 2 가 됐다).
    _content = readLiveContent();
    // 걸을 경기는 그 문서에서 고른다 — 어느 경기인지는 산출물이 정한다.
    _anchor = pickAwayGameAnchor(content: _content, preferredTeamId: _teamId);
  });

  testWidgets(
    '다섯 phase 를 한 실행으로 가로지르고, 다른 계정으로 바뀌어도 앞사람의 것이 남지 않는다',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      final auth = FakeAuthService();
      addTearDown(auth.dispose);
      final gateway = FakeLocationPermissionGateway(
        afterRequest: LocationPermissionStatus.granted,
      );
      final where = _Where();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(auth),
            userDataStoreProvider.overrideWithValue(store),
            locationPermissionGatewayProvider.overrideWithValue(gateway),
            clockProvider.overrideWithValue(() => _anchor.atGame),
            teamsProvider.overrideWith(
              (ref) async => ContentFresh(_content.teams),
            ),
            stadiumsProvider.overrideWith(
              (ref) async => ContentFresh(_content.stadiums),
            ),
            placesProvider.overrideWith(
              (ref) async => ContentFresh(_content.places),
            ),
            scheduleProvider.overrideWith(
              (ref) async => ContentFresh(_content.schedule),
            ),
            stadiumVisitCheckerProvider.overrideWith((ref) {
              final g = ref.watch(locationPermissionGatewayProvider);
              return StadiumVisitChecker(
                readPermission: g.status,
                readFix: () async => where.fix,
              );
            }),
          ],
          child: const KboAwayFansApp(),
        ),
      );
      await tester.pumpAndSettle();

      // ── phase 2 — 계정 없이 쓰는 경로가 없다.
      expect(find.byType(SignInScreen), findsOneWidget);

      await tester.tap(_buttonOf(AuthProviderId.google));
      await tester.pumpAndSettle();
      expect(find.byType(TeamSelectScreen), findsOneWidget);

      await _tapText(tester, _content.teams.byId(_anchor.teamId)!.name);
      expect(find.byType(LocationConsentScreen), findsOneWidget);
      await _tapText(tester, '위치 권한 허용하기');

      // ── phase 3·5 — 홈에 닿고, 홈 상단이 이 사람의 것이다.
      expect(find.byType(HomeScreen), findsOneWidget);
      final uidA = fakeUidOf(AuthProviderId.google);
      expect(store.documents[uidA]![UserFields.favoriteTeamId], _anchor.teamId);

      // 5.1 — 최근 경기 요약이 실 산출물의 끝난 경기에서 선다.
      //      앵커 경기 자신이 그 팀의 최근 다섯 줄 안에 드는 종료 경기다.
      expect(
        find.text(_anchor.dayLabel, skipOffstage: false),
        findsOneWidget,
        reason:
            '최근 5경기 요약이 schedule schemaVersion 2 의 과거 경기를 읽는다 '
            '(앵커: ${_anchor.game.id})',
      );

      // 5.2 — 현재 위치 줄이 홈에 서 있다.
      expect(
        find.byKey(kCurrentLocationRowKey, skipOffstage: false),
        findsOneWidget,
      );

      // ── phase 4 — 구장 안에서 앱이 떠 있으니 판정 → 도장이 선다.
      await tester.pumpAndSettle(const Duration(seconds: 5));
      expect(
        store.stamps[uidA]?.keys,
        contains(_anchor.stampDocumentId),
        reason: '경기일 + 구장 반경 + 시간 창 세 조건이 맞으면 도장이 찍힌다',
      );
      final boardA = (await store.readProfile(uidA))!.board;
      expect(boardA[_anchor.boardCellId]?.count, 1);

      // ── phase 3 — 장소 좋아요.
      await _tapText(tester, '추천');
      // 추천 목록이 실제로 서는 구장을 장소 문서에서 고른다.
      await _tapText(tester, stadiumWithPlaces(_content).name);
      final likeButton = find
          .descendant(
            of: find.byType(PlaceCard, skipOffstage: false),
            matching: find.byType(LikeButton, skipOffstage: false),
          )
          .first;
      await tester.ensureVisible(likeButton);
      await tester.pumpAndSettle();
      await tester.tap(likeButton);
      await tester.pumpAndSettle();
      expect(store.likes[uidA], isNotEmpty, reason: '좋아요가 이 계정 아래에 남는다');

      // 계정을 바꾸기 전에 기기를 구장 밖으로 옮긴다 — 그래야 뒤이어 서는
      // 빈 판이 "앞사람의 것이 안 넘어왔다"만 뜻한다(구장 안에 그대로 있으면
      // 새 계정도 제 도장을 정당하게 받으므로 두 가지가 섞인다).
      where.fix = _farAway;

      // ── phase 3 — 로그아웃. 게이트가 위에 쌓인 route 까지 내린다.
      await _tapText(tester, '마이페이지');
      await _tapText(tester, ProfileTabScreen.signOutLabel);
      expect(
        find.byType(SignInScreen),
        findsOneWidget,
        reason: '로그아웃하면 장소 화면이 위에 남지 않고 로그인 화면으로 돌아온다',
      );

      // ── 다른 계정 — 앞사람의 것이 하나도 넘어오지 않아야 한다.
      await tester.tap(_buttonOf(AuthProviderId.kakao));
      await tester.pumpAndSettle();
      expect(
        find.byType(TeamSelectScreen),
        findsOneWidget,
        reason: '문서가 없는 새 계정은 앞사람의 팀으로 홈에 들어가지 않는다',
      );

      await _tapText(tester, _otherTeam.name);
      // 위치 설명은 **다시 서지 않는다** — OS 권한은 기기의 것이고 앞사람이
      // 이미 허용했다(`location_consent.dart`: 이미 결정된 값이면 게이트를
      // 그대로 지나간다). `phase2_journey_probe_test.dart` 의 계정 전환
      // 시험이 새 계정에서도 설명을 보는 것은 그 시험의 앞사람이 "나중에"를
      // 눌러 권한이 미결정으로 남았기 때문이다.
      expect(find.byType(LocationConsentScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);

      final uidB = fakeUidOf(AuthProviderId.kakao);
      expect(store.documents[uidB]![UserFields.favoriteTeamId], _otherTeam.id);

      // 판: 새 계정의 칸은 전부 비어 있다.
      await _tapText(tester, '배지');
      final filled = tester
          .widgetList<StampBadge>(find.byType(StampBadge))
          .where((badge) => badge.stamps > 0);
      expect(
        filled,
        isEmpty,
        reason: '앞사람의 도장이 새 계정의 판에 남으면 안 된다',
      );

      // 좋아요: 새 계정의 목록은 비어 있다.
      await _tapText(tester, '좋아요');
      expect(
        find.text(LikesTabScreen.emptyTitle, skipOffstage: false),
        findsOneWidget,
        reason: '앞사람의 좋아요가 새 계정의 목록에 남으면 안 된다',
      );
      expect(store.likes[uidB] ?? const <String, Object?>{}, isEmpty);
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
