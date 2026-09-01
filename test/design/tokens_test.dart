import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';

/// content-pipeline/schema/common.defs.schema.json 의 teamId enum 10종.
const List<String> kboTeamIds = [
  'lg',
  'doosan',
  'kiwoom',
  'ssg',
  'kt',
  'kia',
  'samsung',
  'lotte',
  'nc',
  'hanwha',
];

void main() {
  group('팀 테마', () {
    test('10개 팀 테마가 모두 존재하고 팀 id로 조회된다', () {
      expect(TeamThemes.byId, hasLength(kboTeamIds.length));
      for (final id in kboTeamIds) {
        expect(
          TeamThemes.byId[id],
          isNotNull,
          reason: '팀 id "$id" 로 테마가 조회돼야 한다',
        );
      }
    });

    test('각 테마는 primary/secondary/on-color 를 가진다', () {
      for (final entry in TeamThemes.byId.entries) {
        final theme = entry.value;
        expect(theme.primary, isA<Color>());
        expect(theme.secondary, isA<Color>());
        expect(theme.onPrimary, isA<Color>());
        expect(theme.onSecondary, isA<Color>());
        expect(
          theme.primary,
          isNot(equals(theme.onPrimary)),
          reason: '${entry.key}: primary 와 on-color 가 같으면 콘텐츠가 안 보인다',
        );
      }
    });

    test('lerp 은 양 끝에서 원본과 같고 중간에서는 두 색 사이에 놓인다', () {
      const a = TeamThemes.lotte;
      const b = TeamThemes.hanwha;

      expect(TeamTheme.lerp(a, b, 0), equals(a));
      expect(TeamTheme.lerp(a, b, 1), equals(b));

      final mid = TeamTheme.lerp(a, b, 0.5);
      expect(mid, isNot(equals(a)));
      expect(mid, isNot(equals(b)));
      expect(mid.primary, equals(Color.lerp(a.primary, b.primary, 0.5)));
      expect(mid.onSecondary, equals(Color.lerp(a.onSecondary, b.onSecondary, 0.5)));
    });

    test('같은 테마끼리의 lerp 은 사본을 만들지 않는다', () {
      expect(
        TeamTheme.lerp(TeamThemes.lg, TeamThemes.lg, 0.5),
        same(TeamThemes.lg),
      );
    });

    test('값이 같으면 인스턴스가 달라도 == 이고 hashCode 도 같다', () {
      // 보간이 만드는 인스턴스는 매번 새것이라, 재알림 판정이 값 동등성에 걸린다.
      final copy = TeamTheme.lerp(TeamThemes.nc, TeamThemes.samsung, 1);
      expect(identical(copy, TeamThemes.samsung), isFalse);
      expect(copy, equals(TeamThemes.samsung));
      expect(copy.hashCode, equals(TeamThemes.samsung.hashCode));
    });
  });

  group('토큰 그룹 5종', () {
    test('color 토큰이 비어 있지 않다', () {
      const colors = [
        ColorTokens.background,
        ColorTokens.surface,
        ColorTokens.textPrimary,
        ColorTokens.textSecondary,
        ColorTokens.success,
        ColorTokens.warning,
        ColorTokens.danger,
      ];
      expect(colors, isNotEmpty);
    });

    test('space 토큰이 비어 있지 않고 오름차순이다', () {
      const scale = [
        SpaceTokens.xs,
        SpaceTokens.sm,
        SpaceTokens.md,
        SpaceTokens.lg,
        SpaceTokens.xl,
        SpaceTokens.xxl,
      ];
      expect(scale, isNotEmpty);
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('radius 토큰이 비어 있지 않고 오름차순이다', () {
      const scale = [
        RadiusTokens.sm,
        RadiusTokens.md,
        RadiusTokens.lg,
        RadiusTokens.xl,
        RadiusTokens.pill,
      ];
      expect(scale, isNotEmpty);
      for (var i = 1; i < scale.length; i++) {
        expect(scale[i], greaterThan(scale[i - 1]));
      }
    });

    test('type 토큰이 비어 있지 않다', () {
      const sizes = [
        TypeTokens.display,
        TypeTokens.title,
        TypeTokens.heading,
        TypeTokens.body,
        TypeTokens.label,
        TypeTokens.caption,
      ];
      const weights = [
        TypeTokens.weightRegular,
        TypeTokens.weightMedium,
        TypeTokens.weightBold,
        TypeTokens.weightExtraBold,
      ];
      expect(sizes, isNotEmpty);
      expect(weights, isNotEmpty);
    });

    test('motion 토큰이 비어 있지 않다', () {
      const durations = [
        MotionTokens.fast,
        MotionTokens.base,
        MotionTokens.slow,
        MotionTokens.themeShift,
        MotionTokens.weatherShift,
        MotionTokens.rainFall,
      ];
      expect(durations, isNotEmpty);
      for (final d in durations) {
        expect(d, greaterThan(Duration.zero));
      }
    });

    test('motion.stamp 는 지속과 커브를 함께 담는다', () {
      const stamp = MotionTokens.stamp;
      expect(stamp, isA<MotionSpec>());
      expect(stamp.duration, greaterThan(Duration.zero));
      expect(stamp.curve, isA<Curve>());
      expect(
        stamp.curve,
        same(MotionTokens.emphasized),
        reason: '커브는 기존 motion 커브 토큰에서 와야 한다',
      );
    });

    test('motion 기본 커브는 탄성(오버슈트)이다', () {
      final samples = List<double>.generate(
        101,
        (i) => MotionTokens.bouncy.transform(i / 100),
      );
      final peak = samples.reduce(math.max);
      expect(
        peak,
        greaterThan(1.0),
        reason: '탄성 커브라면 진행값이 1.0을 넘는 오버슈트 구간이 있어야 한다',
      );
    });
  });

  group('text.* 조합 스타일', () {
    test('조합 스타일 목록이 비어 있지 않고 서로 다르다', () {
      expect(TextTokens.all, isNotEmpty);
      expect(
        TextTokens.all.toSet(),
        hasLength(TextTokens.all.length),
        reason: '같은 값의 조합이 두 이름으로 있으면 사용처가 갈린다',
      );
    });

    test('모든 조합 스타일이 폰트·크기·굵기·색을 다 갖춘다', () {
      // Color·FontWeight 는 primitive equality 가 없어 const Set 을 못 만든다.
      final sizes = <double>{
        TypeTokens.display,
        TypeTokens.title,
        TypeTokens.heading,
        TypeTokens.body,
        TypeTokens.label,
        TypeTokens.caption,
      };
      final weights = <FontWeight>{
        TypeTokens.weightRegular,
        TypeTokens.weightMedium,
        TypeTokens.weightBold,
        TypeTokens.weightExtraBold,
      };
      final colors = <Color>{
        ColorTokens.textPrimary,
        ColorTokens.textSecondary,
        ColorTokens.textInverse,
      };

      for (final style in TextTokens.all) {
        expect(
          style.fontFamily,
          equals(TypeTokens.fontFamily),
          reason: '폰트는 TypeTokens.fontFamily 에서 와야 한다',
        );
        expect(
          style.fontSize,
          isNotNull,
          reason: '조합 스타일은 크기까지 완성돼 있어야 한다',
        );
        expect(
          sizes,
          contains(style.fontSize),
          reason: '크기 ${style.fontSize} 가 TypeTokens 크기 스케일 밖이다',
        );
        expect(
          weights,
          contains(style.fontWeight),
          reason: '굵기 ${style.fontWeight} 가 TypeTokens 굵기 토큰 밖이다',
        );
        expect(
          colors,
          contains(style.color),
          reason: '색 ${style.color} 가 ColorTokens 텍스트 색 밖이다',
        );
      }
    });

    test('이름 있는 조합이 낱개 토큰 조합과 정확히 같다', () {
      expect(TextTokens.display.fontSize, equals(TypeTokens.display));
      expect(TextTokens.display.fontWeight, equals(TypeTokens.weightExtraBold));
      expect(TextTokens.display.color, equals(ColorTokens.textPrimary));

      expect(TextTokens.bodyMuted.fontSize, equals(TypeTokens.body));
      expect(TextTokens.bodyMuted.fontWeight, equals(TypeTokens.weightMedium));
      expect(TextTokens.bodyMuted.color, equals(ColorTokens.textSecondary));

      expect(TextTokens.caption.fontSize, equals(TypeTokens.caption));
      expect(TextTokens.onTeamLabel.color, equals(ColorTokens.textInverse));
    });

    test('inheritColor 는 크기·굵기를 남기고 색만 뗀다', () {
      final inherited = TextTokens.inheritColor(TextTokens.label);
      expect(inherited.color, isNull);
      expect(inherited.fontSize, equals(TextTokens.label.fontSize));
      expect(inherited.fontWeight, equals(TextTokens.label.fontWeight));
      expect(inherited.fontFamily, equals(TextTokens.label.fontFamily));
    });
  });

  group('badge.* / badgeTier.*', () {
    test('판은 팀 테마 10개와 1:1 대응하는 10칸이다', () {
      expect(BadgeTokens.cellCount, equals(kboTeamIds.length));
      expect(BadgeTokens.cellCount, equals(TeamThemes.byId.length));
    });

    test('배지 판 수치가 낱개 토큰에서 오거나 양수다', () {
      expect(BadgeTokens.cellSize, greaterThan(0));
      expect(BadgeTokens.cellGap, equals(SpaceTokens.md));
      expect(BadgeTokens.cellRadius, equals(RadiusTokens.pill));
      expect(BadgeTokens.boardPadding, equals(SpaceTokens.lg));
      expect(BadgeTokens.emptyBorderWidth, greaterThan(0));
      expect(BadgeTokens.tierRingInset, greaterThan(0));
    });

    test('빈 칸 테두리는 굵기와 색이 짝으로 있다', () {
      // 굵기만 있으면 판을 그리는 쪽이 색을 직접 골라야 하는데, 그때 고르는
      // 값이 `Colors.grey` 류면 hex 리터럴이 아니라 하드코딩 검사를 빠져나간다.
      expect(BadgeTokens.emptyBorderColor, equals(ColorTokens.outline));
    });

    test('빈 칸 투명도는 보이되 획득 칸과 갈리는 범위다', () {
      expect(BadgeTokens.emptyOpacity, greaterThan(0));
      expect(BadgeTokens.emptyOpacity, lessThan(0.5));
    });

    test('등급은 3단계이고 각각 표현 값을 가진다', () {
      expect(BadgeTier.values, hasLength(3));
      expect(BadgeTierTokens.byTier, hasLength(BadgeTier.values.length));
      for (final tier in BadgeTier.values) {
        final style = BadgeTierTokens.byTier[tier];
        expect(style, isNotNull, reason: '$tier 에 대응하는 표현 값이 없다');
        expect(style!.label, isNotEmpty);
        expect(style.ringWidth, greaterThan(0));
        expect(style.bands, greaterThan(0), reason: '$tier 에 금속 띠가 없다');
        // 겹마다의 굵기 하한(1 논리픽셀)은 badge_tier_legibility_test.dart 가
        // 든다 — 여기에 `width > 0` 을 함께 두면 같은 성질을 두 파일이 서로
        // 다른 기준으로 재게 되고, 나중에 한쪽만 고치면 기준이 갈린다.
      }
    });

    test('등급은 팀 색을 갈아치우지 않고 칸 가장자리에만 얹힌다', () {
      // "얹는다"의 실질 — 링이 아무리 두꺼워져도 칸 한가운데는 팀 대표색으로
      // 남아야 한다. 링이 칸의 절반을 넘게 먹으면 칸을 보고 읽히는 색이
      // 팀 색이 아니라 등급 색이 되어, 얹은 것이 아니라 대체가 된다.
      // (등급이 몸통 색 위에서 실제로 읽히는지는 대비로 검사한다 —
      //  test/design/badge_tier_legibility_test.dart)
      for (final MapEntry(key: tier, value: style)
          in BadgeTierTokens.byTier.entries) {
        final ringSpan = BadgeTokens.tierRingInset + style.ringWidth;
        final core = BadgeTokens.cellSize - 2 * ringSpan;
        expect(
          core,
          greaterThanOrEqualTo(BadgeTokens.cellSize / 2),
          reason: '${tier.name}: 링이 칸의 절반 넘게 먹어 몸통이 남지 않는다',
        );
      }
    });

    test('임계 개수는 오름차순이고 도장 개수로 등급이 갈린다', () {
      final tiers = BadgeTier.values
          .map((t) => BadgeTierTokens.byTier[t]!)
          .toList();
      for (var i = 1; i < tiers.length; i++) {
        expect(tiers[i].minStamps, greaterThan(tiers[i - 1].minStamps));
      }

      expect(BadgeTierTokens.tierFor(0), isNull, reason: '빈 칸은 등급이 없다');
      expect(
        BadgeTierTokens.tierFor(BadgeTierTokens.first.minStamps),
        equals(BadgeTier.first),
      );
      expect(
        BadgeTierTokens.tierFor(BadgeTierTokens.regular.minStamps),
        equals(BadgeTier.regular),
      );
      expect(
        BadgeTierTokens.tierFor(BadgeTierTokens.master.minStamps + 100),
        equals(BadgeTier.master),
      );
    });
  });
}
