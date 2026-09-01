/// ContentFallback 위젯 테스트 — 콘텐츠를 못 얻은 자리의 단일 얼굴:
/// 로드 중이면 스피너만, 실패면 안내 + (재시도 경로가 있을 때만) 버튼.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/ui/shared/content_fallback.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('로드 중이면 스피너만 보이고 안내 문구는 없다', (tester) async {
    await tester.pumpWidget(
      host(const ContentFallback(loading: true, title: '경기 일정을 불러오지 못했어요')),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('경기 일정을 불러오지 못했어요'), findsNothing);
  });

  testWidgets('실패면 제목·설명·재시도 버튼을 렌더한다', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      host(
        ContentFallback(
          loading: false,
          title: '경기 일정을 불러오지 못했어요',
          onRetry: () => retried++,
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('경기 일정을 불러오지 못했어요'), findsOneWidget);
    expect(find.text(ContentFallback.defaultMessage), findsOneWidget);

    await tester.tap(find.text(ContentFallback.retryLabel));
    await tester.pump();
    expect(retried, 1);
  });

  testWidgets('재시도 경로가 없으면 버튼을 두지 않는다', (tester) async {
    await tester.pumpWidget(host(const ContentFallback(loading: false)));

    expect(find.text(ContentFallback.retryLabel), findsNothing);
    expect(find.text(ContentFallback.defaultTitle), findsOneWidget);
  });
}
