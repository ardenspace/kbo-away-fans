/// Step 4.4 boundary tests — 도장이 찍히는 순간의 연출.
///
/// 계약이 이름 지은 세 갈래를 그대로 잰다:
///  1. **연출이 재생된다** — 위젯이 존재하는 것과 애니메이션이 실제로
///     진행하는 것은 다르다. 그래서 "재생됐다"를 그 프레임에 **실제로 그려진
///     변형 행렬**([_scaleOf])로 재고, 그 값이 구간 중간에서 시작 값도 끝
///     값도 아니어야 한다고 요구한다 — 처음부터 끝 모습으로 그려 놓고
///     트랜지션만 얹은 흉내로는 이 시험을 통과할 수 없다.
///  2. **등급이 오르는 도장이면 등급 상승이 이어서 보인다** — 찍힘이 끝난
///     **뒤에** 등급 문구가 뜨는 것(겹치지 않고 이어짐)과, 등급이 그대로인
///     도장에는 그 문구 자체가 아예 없는 것을 함께 잰다.
///  3. **연출을 건너뛰거나 중간에 화면을 벗어나도 데이터는 이미 확정되어
///     있다** — 위젯을 하나도 세우지 않은 채 판정→도장 파이프라인이 이미
///     서버(가짜 저장소)에 쓴 것을 확인하고, 연출을 탭으로 건너뛰거나
///     트리에서 통째로 들어내도 예외 없이 끝나는 것을 확인한다.
///
/// **프레임 수를 세지 않는다.** 이 파일이 한 번 걸렸던 함정이라 적어 둔다:
/// `AnimationController` 는 구간 끝(t = duration)의 틱에서 값이 이미 1.0
/// 이지만 상태는 아직 `completed` 가 아니다 — `_InterpolationSimulation.isDone`
/// 이 `time > duration` 이라는 **엄격 부등호**라서 그 한 틱 뒤에야 완료가
/// 알려진다(실측: `pump(420ms)` 뒤 값 1.0·문구 없음, 이어 `pump(1µs)` 하면
/// 문구가 뜬다). 그래서 "몇 번째 프레임에 뜬다"를 세는 시험은 1ms 짜리 마법
/// 숫자를 낳는다. 대신 **문구가 처음 뜬 프레임을 찾아, 그 프레임의 찍힘이
/// 이미 끝나 있었는지**를 잰다 — 계약이 말한 "이어서 보인다"가 프레임
/// 계산 없이 그대로 성질로 남는다.
///
/// **상한을 짧게 준다.** `testWidgets` 의 기본 상한도 `pumpAndSettle` 의 기본
/// 상한도 10분이라, 멎지 않는 애니메이션이나 가짜 시계 위에서 영영 완료되지
/// 않는 기다림이 생기면 실패가 10분 뒤에야 오고 그 메시지는 원인을 말해 주지
/// 않는다(이 파일이 실제로 그렇게 태웠다 — [_limit] 과 [_settle] 참조).
///
/// **짝 파일:** 도장 쓰기 자체(`StampWriteOutcome`)는
/// `test/backend/stamp_write_test.dart` 가 재고, 판이 칸 요약을 읽는 자리는
/// `test/features/badges/badge_board_test.dart` 가 잰다. 이 파일은 그 둘
/// 사이를 잇는 연출 하나만 잰다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/auth.dart';
import 'package:kbo_away_fans/backend/user_data.dart';
import 'package:kbo_away_fans/content/content_loader.dart';
import 'package:kbo_away_fans/content/content_providers.dart';
import 'package:kbo_away_fans/content/models.dart';
import 'package:kbo_away_fans/design/tokens.dart';
import 'package:kbo_away_fans/features/badges/stadium_visit.dart';
import 'package:kbo_away_fans/features/badges/stamp_award.dart';
import 'package:kbo_away_fans/features/badges/stamp_reveal.dart';
import 'package:kbo_away_fans/features/home/next_away_game.dart';
import 'package:kbo_away_fans/location/location.dart';
import 'package:kbo_away_fans/location/visit_check.dart';

import '../../backend/fake_backend.dart';

const String _uid = 'kakao:reveal-uid';

const double _jamsilLat = 37.5121;
const double _jamsilLng = 127.0719;

const NewUserProfile _newProfile = NewUserProfile(
  nickname: '원정러',
  favoriteTeamId: 'lg',
);

/// 이 파일의 시험 하나가 걸릴 수 있는 상한.
///
/// 기본값 10분을 그대로 두지 않는다 — 정착하지 않는 연출(무한 반복
/// 애니메이션·멎지 않는 컨트롤러·재구성 고리)이나 가짜 시계 위의 끝나지
/// 않는 기다림은 실패가 원인을 말해 주지 않으므로, 적어도 **빨리** 잡혀야
/// 한다.
const Timeout _limit = Timeout(Duration(seconds: 30));

/// 상한을 준 [WidgetTester.pumpAndSettle] — 기본 상한(10분)을 쓰지 않는다.
Future<void> _settle(WidgetTester tester) => tester.pumpAndSettle(
  const Duration(milliseconds: 16),
  EnginePhase.sendSemanticsUpdate,
  const Duration(seconds: 5),
);

/// 연출이 소비할 결과 하나 — 필드를 골라 만든다.
StampAwardResult _result({
  String cellId = 'jamsil_lg',
  int count = 1,
  BadgeTier tier = BadgeTier.first,
  bool tierIncreased = true,
}) => StampAwardResult(
  cellId: cellId,
  count: count,
  tier: tier,
  tierIncreased: tierIncreased,
);

/// [StampReveal] 하나만 세우는 최소 host — 리버팟이 필요 없다(생성자 인자로
/// 다 받는 순수 위젯이다).
Widget _hostReveal({
  required StampAwardResult result,
  required VoidCallback onDone,
  String? teamLabel,
}) => MaterialApp(
  home: Scaffold(
    body: StampReveal(result: result, onDone: onDone, teamLabel: teamLabel),
  ),
);

/// **지금 프레임에 실제로 그려진** 배지의 확대 배율.
///
/// 애니메이션 객체의 `value` 가 아니라 그 프레임의 [Transform] 행렬에서
/// 꺼내는 것이 요점이다 — 컨트롤러만 돌고 화면이 다시 그려지지 않는 구현은
/// 여기서 값이 얼어붙어 잡히고, `value` 를 읽는 시험은 그것을 놓친다.
double _scaleOf(WidgetTester tester) => tester
    .widget<Transform>(
      find
          .descendant(
            of: find.byKey(StampReveal.badgeTransformKey),
            matching: find.byType(Transform),
          )
          .first,
    )
    .transform
    .entry(0, 0);

/// 등급 상승 문구가 지금 트리에 있는가.
bool _tierShown() => find.byKey(StampReveal.tierUpKey).evaluate().isNotEmpty;

/// 등급 상승 문구의 지금 투명도.
double _tierOpacityOf(WidgetTester tester) => tester
    .widget<FadeTransition>(find.byKey(StampReveal.tierUpKey))
    .opacity
    .value;

/// 두 연출(찍힘 + 등급 상승)을 넉넉히 덮는 프레임 훑기 — 걸음은 찍힘 구간의
/// 1/8 이고 걸음 수는 두 구간의 합보다 길다. "끝까지 뜨지 않는다" 를 재는
/// 쪽이 구간이 끝나기도 전에 훑기를 멈추면 안 된다.
Duration get _scanStep => MotionTokens.stamp.duration ~/ 8;
const int _scanFrames = 24;

void main() {
  group('연출이 재생된다', () {
    testWidgets('찍히는 배지의 확대값이 처음·중간·끝에서 서로 다르다', (tester) async {
      await tester.pumpWidget(
        _hostReveal(result: _result(tierIncreased: false), onDone: () {}),
      );

      // 시작 프레임 — 아직 아무것도 찍히지 않았다.
      expect(_scaleOf(tester), 0, reason: '아직 찍히기 전');

      // 중간 지점 — 시작도 끝도 아닌 값이어야 "실제로 진행"이 증명된다.
      await tester.pump(MotionTokens.stamp.duration ~/ 2);
      final midway = _scaleOf(tester);
      expect(midway, isNot(0), reason: '진행 중이라 0에 머물러 있으면 안 된다');
      expect(midway, isNot(1), reason: '아직 다 찍히지 않았다');

      // 끝 — 눌렀다 자리를 잡아 정확히 1로 정착한다.
      await tester.pump(MotionTokens.stamp.duration);
      expect(_scaleOf(tester), 1, reason: '다 찍히면 원래 크기로 정착한다');

      await _settle(tester);
    }, timeout: _limit);

    testWidgets('중간값이 시작·끝과 다른 프레임이 실제로 존재한다(스텝 스캔)', (tester) async {
      // 위 시험은 정확히 절반 지점 하나만 본다 — 구현이 그 한 프레임만 우연히
      // 절반을 흉내 내는 것을 막기 위해 촘촘히 훑는다.
      await tester.pumpWidget(
        _hostReveal(result: _result(tierIncreased: false), onDone: () {}),
      );

      final samples = <double>[_scaleOf(tester)];
      for (var i = 0; i < 10; i++) {
        await tester.pump(MotionTokens.stamp.duration ~/ 10);
        samples.add(_scaleOf(tester));
      }

      expect(
        samples.toSet().length,
        greaterThan(2),
        reason: '값이 시작·끝 둘뿐이면 중간 프레임이 하나도 안 그려진 것이다',
      );

      await _settle(tester);
    }, timeout: _limit);
  });

  group('등급이 오르는 도장이면 등급 상승이 이어서 보인다', () {
    testWidgets('등급이 오르면 찍힘이 끝난 뒤 등급 상승 문구가 이어 뜬다', (tester) async {
      await tester.pumpWidget(
        _hostReveal(
          result: _result(tier: BadgeTier.regular, tierIncreased: true),
          onDone: () {},
        ),
      );
      expect(_tierShown(), isFalse, reason: '찍히기도 전이다');

      // 찍힘이 한창 도는 중간 지점 — 여기서 문구가 있으면 두 연출이 겹친 것이다.
      await tester.pump(MotionTokens.stamp.duration ~/ 2);
      expect(_scaleOf(tester), isNot(1), reason: '아직 찍히는 중이어야 한다');
      expect(_tierShown(), isFalse, reason: '겹치지 않고 이어져야 한다');

      // 문구가 **처음 뜬 프레임**을 찾아, 그 프레임의 찍힘이 이미 끝나 있었는지를
      // 잰다 (프레임 수를 세지 않는 까닭은 이 파일 머리말에 적었다).
      double? scaleWhenTierAppeared;
      for (var i = 0; i < _scanFrames && scaleWhenTierAppeared == null; i++) {
        await tester.pump(_scanStep);
        if (_tierShown()) scaleWhenTierAppeared = _scaleOf(tester);
      }

      expect(
        scaleWhenTierAppeared,
        isNotNull,
        reason: '등급이 오르는 도장인데 문구가 끝내 뜨지 않았다',
      );
      expect(
        scaleWhenTierAppeared,
        1,
        reason: '찍힘이 다 끝난 뒤에야 이어 붙는다 — 도는 중이면 1이 아니다',
      );
      expect(
        _tierOpacityOf(tester),
        lessThan(1),
        reason: '이제 막 이어 붙었으니 아직 다 드러나지 않았다',
      );

      // 등급 연출까지 다 끝나면 완전히 보인다.
      await _settle(tester);
      expect(_tierOpacityOf(tester), 1);
      expect(
        find.text('등급 상승! ${BadgeTierTokens.regular.label}'),
        findsOneWidget,
      );
    }, timeout: _limit);

    testWidgets('등급이 그대로면 등급 상승 문구가 끝까지 뜨지 않는다', (tester) async {
      await tester.pumpWidget(
        _hostReveal(result: _result(tierIncreased: false), onDone: () {}),
      );

      expect(_tierShown(), isFalse);
      for (var i = 0; i < _scanFrames; i++) {
        await tester.pump(_scanStep);
        expect(_tierShown(), isFalse, reason: '등급이 안 오르면 이어질 문구가 어느 프레임에도 없다');
      }

      await _settle(tester);
      expect(_tierShown(), isFalse);
      expect(find.textContaining('등급 상승'), findsNothing);
      expect(_scaleOf(tester), 1, reason: '찍힘 자체는 끝까지 돈다');
    }, timeout: _limit);
  });

  group('연출을 건너뛰거나 중간에 화면을 벗어나도 데이터는 이미 확정되어 있다', () {
    // 이 시험은 **위젯을 하나도 세우지 않으므로** `testWidgets` 가 아니라
    // 보통 `test` 다. `testWidgets` 는 가짜 시계 위에서 돌아
    // `pumpEventQueue` 의 `Future.delayed(Duration.zero)` 가 `tester.pump`
    // 없이는 영영 완료되지 않는데, 그러면 실패가 기본 상한인 10분 뒤에
    // 원인을 말하지 않는 채로 온다(이 파일이 실제로 그렇게 태웠다). 짝 파일
    // `test/backend/stamp_write_test.dart` 의 판정 파이프라인 시험들도 같은
    // 까닭으로 전부 보통 `test` 다.
    test('위젯을 그리기도 전에 판정이 이미 서버에 도장을 남긴다', () async {
      final store = FakeUserDataStore();
      addTearDown(store.dispose);
      await store.createProfile(_uid, _newProfile);

      final auth = FakeAuthService(signedIn: const AuthUser(uid: _uid));
      addTearDown(auth.dispose);

      final schedule = ScheduleDocument(
        generatedAt: DateTime.utc(2026),
        games: const [
          Game(
            id: 'g-jamsil-lg',
            date: '2026-08-25',
            startTime: '18:30',
            homeTeamId: 'lg',
            awayTeamId: 'lotte',
            stadiumId: 'jamsil',
            status: GameStatus.scheduled,
          ),
        ],
      );
      const stadiums = StadiumsDocument(
        stadiums: [
          Stadium(
            id: 'jamsil',
            name: '잠실야구장',
            city: '서울',
            lat: _jamsilLat,
            lng: _jamsilLng,
            homeTeams: ['lg', 'doosan'],
          ),
        ],
      );

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(
            () => DateTime.parse('2026-08-25T18:00:00+09:00'),
          ),
          authServiceProvider.overrideWithValue(auth),
          userDataStoreProvider.overrideWithValue(store),
          stadiumsProvider.overrideWith((ref) async => ContentFresh(stadiums)),
          scheduleProvider.overrideWith((ref) async => ContentFresh(schedule)),
          stadiumVisitCheckerProvider.overrideWithValue(
            StadiumVisitChecker(
              readPermission: () async => LocationPermissionStatus.granted,
              readFix: () async =>
                  const DeviceFix(lat: _jamsilLat, lng: _jamsilLng),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(authStateProvider, (_, _) {});
      await pumpEventQueue();

      // 판정을 돈다 — 이 시험은 화면을 하나도 세우지 않는다. 그런데도 도장이
      // 남는다는 것이 곧 "데이터가 연출의 전제 조건이 아니다"의 증명이다.
      await container.read(stadiumVisitProvider.notifier).run();

      final stamps = await store.readStamps(_uid);
      expect(stamps, hasLength(1), reason: '연출을 하나도 안 그려도 도장은 남는다');

      final cell = (await store.readProfile(_uid))!.board['jamsil_lg'];
      expect(cell, isNotNull);
      expect(cell!.count, 1);

      // 연출 큐에도 같은 사실이 올라와 있다 — 이제부터는 화면의 몫이다.
      final queued = container.read(stampCelebrationProvider);
      expect(queued, hasLength(1));
      expect(queued.single.cellId, 'jamsil_lg');
    }, timeout: _limit);

    testWidgets('탭으로 건너뛰면 즉시 닫히고, 큐의 다음 연출이 이어진다', (tester) async {
      final firstResult = _result(cellId: 'jamsil_lg', tierIncreased: true);
      final secondResult = _result(
        cellId: 'gwangju_kia',
        count: 3,
        tier: BadgeTier.regular,
        tierIncreased: true,
      );

      final container = ProviderContainer(
        overrides: [
          teamsProvider.overrideWith(
            (ref) async => const ContentFresh(TeamsDocument(teams: [])),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(stampCelebrationProvider.notifier).show(firstResult);
      container.read(stampCelebrationProvider.notifier).show(secondResult);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: StampRevealOverlay(child: const SizedBox.expand()),
            ),
          ),
        ),
      );

      // 첫 연출이 아직 다 돌지 않은 채(중간 지점) 탭한다 — "중간에 벗어나도"
      // 가 곧 이 조작이다.
      await tester.pump(MotionTokens.stamp.duration ~/ 3);
      expect(_scaleOf(tester), isNot(0));
      expect(_scaleOf(tester), isNot(1));

      await tester.tap(find.byType(StampReveal));
      await tester.pump();

      // 큐가 줄어 둘째 연출로 넘어갔다 — 처음부터 다시 돈다(t=0).
      expect(container.read(stampCelebrationProvider), hasLength(1));
      expect(container.read(stampCelebrationProvider).single, secondResult);
      expect(_scaleOf(tester), 0, reason: '둘째 연출은 처음부터 다시 돈다');

      await tester.tap(find.byType(StampReveal));
      await tester.pump();
      expect(container.read(stampCelebrationProvider), isEmpty);
      expect(find.byType(StampReveal), findsNothing);

      await _settle(tester);
    }, timeout: _limit);

    testWidgets('연출이 끝나기 전에 트리에서 통째로 들어내도 예외가 없다', (tester) async {
      final container = ProviderContainer(
        overrides: [
          teamsProvider.overrideWith(
            (ref) async => const ContentFresh(TeamsDocument(teams: [])),
          ),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(stampCelebrationProvider.notifier)
          .show(_result(tierIncreased: true));

      Widget host(Widget child) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: Scaffold(body: child)),
      );

      await tester.pumpWidget(
        host(StampRevealOverlay(child: const SizedBox.expand())),
      );
      await tester.pump(MotionTokens.stamp.duration ~/ 2);

      // "화면을 벗어난다"의 가장 거친 형태 — 위젯 자체가 트리에서 사라진다.
      await tester.pumpWidget(host(const SizedBox.shrink()));
      await _settle(tester);

      expect(tester.takeException(), isNull);
    }, timeout: _limit);
  });
}
