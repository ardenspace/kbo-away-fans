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
}
