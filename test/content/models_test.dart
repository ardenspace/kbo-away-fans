/// 계약 파서(models.dart)의 경계 — schedule schemaVersion 2 의 점수·승패.
///
/// `content_loader_test.dart` 는 로더를 통과하는 문서 단위로 계약을 확인한다.
/// 여기서는 [Game.fromJson] 을 직접 불러 스키마(`schema/schedule.schema.json`)의
/// `$defs/score`(0~99)·`$defs/gameResult`·else 분기(끝나지 않은 경기에 점수 금지)와
/// 앱 파서가 같은 폭인지를 값 하나씩 못 박는다.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/content/models.dart';

/// 파싱 성공이면 [Game], 계약 위반이면 던져진 예외를 그대로 돌려준다.
Object? parseGame(Map<String, Object?> json) {
  try {
    return Game.fromJson(json);
  } on Object catch (e) {
    return e;
  }
}

Map<String, Object?> gameJson(Map<String, Object?> over) => {
      'id': 'g1',
      'date': '2026-08-23',
      'startTime': '17:00',
      'homeTeamId': 'lg',
      'awayTeamId': 'nc',
      'stadiumId': 'jamsil',
      'status': 'scheduled',
      ...over,
    };

void main() {
  group('Game.fromJson 의 점수·승패 경계가 스키마와 같은 폭인지', () {
    test(r'점수 범위 [0,99] 밖은 거부한다 (스키마 $defs/score 와 같은 상한·하한)', () {
      expect(
        parseGame(gameJson({
          'status': 'finished',
          'homeScore': 100,
          'awayScore': 1,
          'result': 'home_win',
        })),
        isA<Exception>(),
      );
      expect(
        parseGame(gameJson({
          'status': 'finished',
          'homeScore': -1,
          'awayScore': 1,
          'result': 'away_win',
        })),
        isA<Exception>(),
      );
    });

    test('취소 두 상태에 점수가 붙어도 거부한다 (스키마 else 분기와 같은 규칙)', () {
      for (final status in ['canceled', 'rain_canceled']) {
        expect(
          parseGame(gameJson({
            'status': status,
            'homeScore': 0,
            'awayScore': 0,
            'result': 'draw',
          })),
          isA<Exception>(),
          reason: status,
        );
      }
    });

    test('점수 키가 null 값으로만 들어와도 예정 경기는 거부한다', () {
      expect(parseGame(gameJson({'homeScore': null})), isA<Exception>());
    });

    test('미지의 result 문자열은 거부한다', () {
      expect(
        parseGame(gameJson({
          'status': 'finished',
          'homeScore': 7,
          'awayScore': 3,
          'result': 'HOME',
        })),
        isA<Exception>(),
      );
    });
  });
}
