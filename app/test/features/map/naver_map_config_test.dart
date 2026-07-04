/// task 2.3 — NCP Maps Client ID 배선 + 미주입 degrade 판정 단위 테스트 (R12).
///
/// 네이티브·키 의존 없음 — Client ID 문자열만 주입한 순수 Dart 단위 테스트.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/features/map/naver_map_config.dart';

void main() {
  group('shouldDegradeMap', () {
    test('빈 문자열(미주입) → shouldDegrade == true', () {
      expect(shouldDegradeMap(''), isTrue);
    });

    test('공백만 있는 값 → shouldDegrade == true', () {
      expect(shouldDegradeMap('   '), isTrue);
    });

    test('실제 Client ID 값 → shouldDegrade == false', () {
      expect(shouldDegradeMap('abc123xyz'), isFalse);
    });
  });

  group('ncpMapClientId (주입 상수)', () {
    test('dart-define 미주입 실행에서는 빈 문자열이라 degrade 경로를 탄다', () {
      // 테스트 실행에는 --dart-define 을 주지 않으므로 기본값은 빈 문자열이다.
      expect(ncpMapClientId, isEmpty);
      expect(shouldDegradeMap(ncpMapClientId), isTrue);
    });
  });
}
