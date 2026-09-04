/// 적대적 탐침 (step 2.4) — `watchProfile` 의 **배선**과 붙잡아 두는 장치의
/// 남은 자리를 잰다. 넷 다 변이 주입에서 살아남은 곳이다: 그 줄을 지우거나
/// 바꿔도 `flutter test` 가 전부 초록불이었다.
///
///  1) `watchProfile` 에서 `awaitServerConfirmation(...)` 배선을 통째로 걷어내고
///     `snapshots()` 를 그대로 흘려도 초록불이었다. 붙잡아 두는 변환과 출처를
///     읽는 술어는 각각 따로 시험이 있지만 **둘을 엮은 자리**는 아무도 재지
///     않는다 — `fake_cloud_firestore` 의 스냅샷은 언제나 `isFromCache: false`
///     라 그 대역으로는 조합을 돌려도 차이가 나지 않기 때문이다. 배선이
///     사라지면 기기를 바꾼 사람이 서버 왕복 전에 온보딩을 보고, 거기서 팀을
///     누르면 자기 팀을 잃는다 — 실기기에서만 드러난다.
///  2) 같은 자리의 `guardBackendStream` 을 걷어내도 초록불이었다. 그러면 SDK
///     예외가 계층 밖으로 그대로 새어 `lib/backend/CLAUDE.md` 의 "SDK 예외를
///     밖으로 내보내지 않는다"가 이 한 자리에서만 거짓이 된다.
///  3) 상한 `kProfileServerConfirmGrace` 를 5초에서 5시간으로 바꿔도
///     초록불이었다. 상한의 **동작**은 시험이 인수로 준 값으로만 재고 있어,
///     실제로 사람을 붙잡는 값은 아무도 보지 않는다.
///  4) 구독을 끊었을 때 상한 타이머가 남는지도 아무도 재지 않았다.
///  5) **값이 하나도 오지 않은 실행**에서 상한이 하는 일이 없었다. 상한
///     타이머가 붙잡아 둔 값을 풀어 주기만 하면, 풀어 줄 것이 없는 실행에서는
///     상한이 지나도 아래로 아무것도 흐르지 않는다 — 그리고 온라인에서 기기를
///     바꿔 처음 로그인한 사람이 정확히 그 실행이다(초기 스냅샷 자체가 오지
///     않는다). 상한이 무는 구간과 사람이 갇히는 구간이 서로 배타적이었다.
///
/// 1·2·3 을 소스 대조로 잡는 것은 `backend_wiring_sync_test.dart` 의 App Check
/// 배선과 같은 처리다 — 실행으로는 닿을 수 없는 배선이라 소스가 유일한 증거다.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/backend/errors.dart';
import 'package:kbo_away_fans/backend/user_data_firestore.dart';

void main() {
  group('watchProfile 의 배선', () {
    const path = 'lib/backend/user_data_firestore.dart';
    final source = File(path).readAsStringSync();

    /// `watchProfile` 선언부터 그 메서드가 끝나는 `);` 까지.
    String bodyOfWatchProfile() {
      final start = source.indexOf('Stream<UserProfile?> watchProfile(');
      expect(start, greaterThanOrEqualTo(0), reason: '$path 에서 watchProfile 을 찾지 못했다');
      final end = source.indexOf('\n\n', start);
      expect(end, greaterThan(start));
      return source.substring(start, end);
    }

    test('스냅샷을 붙잡아 두는 변환을 실제로 거친다', () {
      final body = bodyOfWatchProfile();
      expect(
        body.contains('awaitServerConfirmation('),
        isTrue,
        reason: '이 배선이 사라져도 나머지 시험은 전부 통과한다 — 그리고 기기를 바꾼 '
            '사람이 서버 왕복 전에 온보딩을 보고 거기서 자기 팀을 잃는다',
      );
      expect(
        body.contains('isConfirmed: tellsProfileExistence'),
        isTrue,
        reason: '출처를 읽는 술어가 빠지면 붙잡아 두는 변환이 아무것도 붙잡지 않는다',
      );
    });

    test('스트림 실패가 도메인 오류로 옮겨진다', () {
      expect(
        bodyOfWatchProfile().contains('guardBackendStream('),
        isTrue,
        reason: '이 자리가 빠지면 SDK 예외가 상태 계층까지 그대로 샌다 — '
            'lib/backend/CLAUDE.md 의 오류 봉투 규약이 여기서만 거짓이 된다',
      );
    });

    test('사람을 붙잡는 상한이 실제로 사람이 견딜 길이다', () {
      // 인증 쪽 kAppCheckActivationTimeout 과 같은 판단이고 같은 길이다.
      expect(kProfileServerConfirmGrace, greaterThan(Duration.zero));
      expect(
        kProfileServerConfirmGrace,
        lessThanOrEqualTo(const Duration(seconds: 10)),
        reason: '이 값이 곧 기기를 바꾼 사람이 대기 화면을 보는 최대 시간이다 — '
            '늘리면 그만큼 사람이 스피너 앞에 앉아 있는다',
      );
    });
  });

  group('붙잡아 두는 변환의 남은 갈래', () {
    test('상한이 지난 뒤에 온 값은 다시 붙잡히지 않는다', () async {
      final source = StreamController<String>();
      addTearDown(source.close);
      final seen = <String>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(milliseconds: 20),
      ).listen(seen.add);
      addTearDown(subscription.cancel);

      source.add('모름');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(seen, ['모름'], reason: '상한이 지나면 붙잡아 둔 것을 내보낸다');

      // 상한은 **첫 답**에만 걸린다 — 그 뒤로는 붙잡는 타이머가 없으므로,
      // 여기서 다시 붙잡으면 그 값은 영영 나오지 못한다.
      source.add('모름');
      await pumpEventQueue();
      expect(seen, ['모름', '모름']);

      source.add('lg');
      await pumpEventQueue();
      expect(seen, ['모름', '모름', 'lg']);
    });

    test('원본이 상한 전에 닫히면 붙잡아 둔 값이 나오고 함께 닫힌다', () async {
      // 답이 오지 않은 채 스트림이 끝나는 갈래다 — 여기서 붙잡아 둔 값을
      // 버리면 그 실행은 값도 오류도 없이 끝나고, 게이트는 상한이 이미
      // 지나갔는데도 대기 화면에 남는다.
      final source = StreamController<String>();
      final seen = <String>[];
      var closed = false;
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(minutes: 5),
      ).listen(seen.add, onDone: () => closed = true);
      addTearDown(subscription.cancel);

      source.add('모름');
      await pumpEventQueue();
      expect(seen, isEmpty);

      await source.close();
      await pumpEventQueue();

      expect(seen, ['모름']);
      expect(closed, isTrue);
    });
  });

  group('값이 하나도 오지 않은 실행도 상한에서 끝난다', () {
    test('상한이 지나면 "서버를 읽지 못했다"가 흐른다', () async {
      // 온라인에서 문서 리스너는 로컬 캐시에 문서가 없으면 초기 스냅샷을
      // 아예 올리지 않는다(SDK 의 `shouldRaiseInitialEvent`). 기기를 바꿔
      // 처음 로그인한 사람이 바로 그 실행이라, 붙잡아 둘 값조차 없는 이
      // 갈래가 이 상한 장치의 주 대상이다. 여기서 아무것도 내보내지 않으면
      // 위 계층이 영영 로딩으로 남고 사람은 끝나지 않는 대기 화면에 갇힌다.
      final source = StreamController<String>();
      addTearDown(source.close);
      final seen = <String>[];
      final errors = <Object>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(milliseconds: 20),
      ).listen(seen.add, onError: errors.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(seen, isEmpty);
      expect(
        errors,
        hasLength(1),
        reason: '붙잡아 둔 값이 없으면 상한 타이머가 아무것도 하지 않는다 — '
            '그 실행은 값도 오류도 없이 영원히 이어진다',
      );
      expect(
        errors.single,
        isA<BackendNetworkError>().having(
          (error) => error.code,
          'code',
          kProfileConfirmTimeoutCode,
        ),
        reason: '"서버가 없다고 답했다"가 아니라 "서버를 읽지 못했다"로 확정한다 — '
            '앞엣것으로 확정하면 문서가 있는 사람이 온보딩으로 내려간다',
      );
    });

    test('상한이 지난 뒤에 온 진짜 답으로 수렴한다', () async {
      // 상한은 갈래를 정하는 바닥이지 사람을 옛 판단에 가두는 자물쇠가 아니다.
      final source = StreamController<String>();
      addTearDown(source.close);
      final seen = <String>[];
      final errors = <Object>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(milliseconds: 20),
      ).listen(seen.add, onError: errors.add);
      addTearDown(subscription.cancel);

      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(errors, hasLength(1));

      source.add('lg');
      await pumpEventQueue();

      expect(seen, ['lg'], reason: '상한 뒤에 도착한 답이 위 계층에 닿지 않았다');
    });

    test('상한 안에 답이 오면 오류는 나지 않는다', () async {
      final source = StreamController<String>();
      addTearDown(source.close);
      final seen = <String>[];
      final errors = <Object>[];
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(milliseconds: 40),
      ).listen(seen.add, onError: errors.add);
      addTearDown(subscription.cancel);

      source.add('lg');
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(seen, ['lg']);
      expect(errors, isEmpty, reason: '답을 받은 뒤에도 상한이 오류를 냈다');
    });

    test('원본이 값 없이 닫히면 오류 대신 그대로 닫힌다', () async {
      // 답이 오지 않은 채 스트림이 **끝난** 실행이다. 상한이 아직 남아 있어도
      // 더 기다릴 것이 없으므로, 상한 오류를 뒤늦게 얹지 않는다.
      final source = StreamController<String>();
      final seen = <String>[];
      final errors = <Object>[];
      var closed = false;
      final subscription = awaitServerConfirmation(
        source.stream,
        isConfirmed: (value) => value != '모름',
        grace: const Duration(milliseconds: 20),
      ).listen(seen.add, onError: errors.add, onDone: () => closed = true);
      addTearDown(subscription.cancel);

      await source.close();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(seen, isEmpty);
      expect(errors, isEmpty);
      expect(closed, isTrue);
    });
  });
}
