import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbo_away_fans/design/team_themes.dart';
import 'package:kbo_away_fans/design/tokens.dart';

/// 등급 표현이 **몸통 색 위에서 실제로 읽히는가**를 알파 합성과 대비 계산으로
/// 검사한다. `tokens_test.dart` 는 등급 값의 모양(개수·임계·기하)을 보고,
/// 이 파일은 그 값이 화면에서 만들어 내는 성질을 본다.
///
/// 이 파일이 있는 이유: 예전 등급 값은 링 색 한 가지로만 갈렸는데, 링 색이
/// 팀 대표색과 `==` 로 같지 않은지만 보던 단언은 어떤 값을 넣어도 통과해
/// 한화·기아 위에서 세 등급이 전부 최소선 아래였다는 사실을 가렸다.
///
/// 대비를 재는 자리도 한 번 틀렸다. "링을 이루는 겹 중 최대"로 재던 판정은
/// 대비를 만드는 밝은 겹이 어두운 겹 안쪽에 갇혀 몸통과 한 번도 닿지 않아도
/// 통과해서, 실제로 그려지는 경계에서는 10팀 중 7팀이 3:1 미달(두산 1.04·
/// 롯데 1.05·키움 1.19·kt 1.21)인 값을 통과시켰다. 지금은 **몸통과 맞닿는
/// 겹**으로만 잰다.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 링 한 겹을 몸통 위에 올린 실제 화면 색 (반투명이면 몸통이 비쳐 나온다).
Color _over(Color body, Color layer) => Color.alphaBlend(layer, body);

/// 링이 몸통과 맞닿는 두 끝 겹 — 이름표와 함께.
///
/// 링 바깥은 칸 몸통이고 링 안쪽도 칸 몸통이라 **경계는 두 곳**이다. 링
/// 한가운데 아무리 밝은 겹이 있어도 몸통과 링을 가르는 선의 세기는 끝 겹이
/// 정하므로, 링이 몸통 위에 뜨는지는 이 두 겹으로만 잴 수 있다.
///
/// 두 곳 중 나은 쪽이 아니라 **양쪽 모두**를 요구하는 이유: 한쪽 경계만
/// 갈리면 링은 한 변만 또렷한 번진 덩어리로 읽히고, 안쪽 경계가 묻으면
/// 링과 몸통 한가운데가 이어져 보여 "가장자리에 얹은 링"이라는 형태 자체가
/// 무너진다.
Map<String, BadgeRingLayer> _boundaryLayers(BadgeTierStyle style) => {
  '바깥': style.rings.first,
  '안쪽': style.rings.last,
};

/// 비텍스트 UI 경계의 최소선 (WCAG 2.1 SC 1.4.11).
///
/// 요구 범위는 **10개 팀 대표색**이다. "어떤 sRGB 색 위에서도"라는 일반화는
/// 경계 기준으로 달성 불가능하다 — 흰 몸통이 밝은 끝 겹을, 검은 몸통이 어두운
/// 끝 겹을 각각 죽이므로 한 벌의 오버레이가 양쪽을 함께 만족할 수 없다.
const double _minBoundary = 3;

/// 경계 대비를 만드는 겹의 최소 굵기 (논리픽셀).
///
/// 대비 수치만 보면 굵기 0.1 짜리 겹으로도 통과한다. 배율 1x 화면에서 최소
/// 한 장치픽셀은 칠해져야 계산한 대비가 실제로 남으므로 1 논리픽셀을 요구한다.
const double _minBoundaryLayerWidth = 1;

/// 이웃 등급이 갈렸다고 볼 최소 대비.
const double _minTierStep = 1.5;

void main() {
  final teams = TeamThemes.byId;
  final tiers = BadgeTierTokens.byTier;
  const order = [BadgeTier.first, BadgeTier.regular, BadgeTier.master];

  group('배지 등급이 10개 팀 대표색 위에서 읽히는가', () {
    test('링이 몸통과 맞닿는 두 경계 모두 10개 팀 색에서 3:1 이상이다', () {
      final failures = <String>[];
      for (final MapEntry(key: teamId, value: theme) in teams.entries) {
        for (final MapEntry(key: tier, value: style) in tiers.entries) {
          for (final MapEntry(key: side, value: layer) in _boundaryLayers(
            style,
          ).entries) {
            final ratio = _contrast(
              _over(theme.primary, layer.color),
              theme.primary,
            );
            if (ratio < _minBoundary) {
              failures.add(
                '$teamId × ${tier.name} $side 경계: ${ratio.toStringAsFixed(2)}:1',
              );
            }
          }
        }
      }
      expect(
        failures,
        isEmpty,
        reason: '링과 몸통을 가르는 선이 팀 색에 묻힌다:\n${failures.join('\n')}',
      );
    });

    test('경계 대비를 만드는 겹이 눈에 남을 굵기다', () {
      // 위 검사는 색만 본다. 대비를 담당하는 겹이 실오라기처럼 얇아도 수치는
      // 그대로라, 굵기를 함께 단언하지 않으면 "계산상 통과, 화면에서 안 보임"
      // 이 가능하다.
      final failures = <String>[];
      for (final MapEntry(key: tier, value: style) in tiers.entries) {
        for (final MapEntry(key: side, value: layer) in _boundaryLayers(
          style,
        ).entries) {
          if (layer.width < _minBoundaryLayerWidth) {
            failures.add('${tier.name} $side 경계: ${layer.width}lp');
          }
        }
      }
      expect(
        failures,
        isEmpty,
        reason:
            '경계 대비를 만드는 겹이 ${_minBoundaryLayerWidth}lp 보다 얇다:\n'
            '${failures.join('\n')}',
      );
    });

    test('등급을 가리키는 금속 띠는 몸통과 맞닿지 않는다', () {
      // 등급 식별이 팀 색에 좌우되지 않는 근거. 금속 띠는 겉테·윤곽 사이에
      // 갇혀 있으므로, 띠가 무엇과 대비되는지가 팀마다 달라지지 않는다.
      // (링 바깥은 몸통이고, 링 안쪽도 칸 몸통이라 양쪽 끝 겹이 몸통과 닿는다.)
      const frame = [BadgeTierTokens.haloColor, BadgeTierTokens.contourColor];
      for (final MapEntry(key: tier, value: style) in tiers.entries) {
        final rings = style.rings;
        for (var i = 0; i < rings.length; i++) {
          if (rings[i].color != style.ringColor) continue;
          expect(
            i > 0 && i < rings.length - 1,
            isTrue,
            reason: '${tier.name}: 금속 띠가 링의 끝이라 몸통과 맞닿는다',
          );
          expect(
            frame,
            contains(rings[i - 1].color),
            reason: '${tier.name}: 금속 띠 바깥에 겉테·윤곽이 없다',
          );
          expect(
            frame,
            contains(rings[i + 1].color),
            reason: '${tier.name}: 금속 띠 안쪽에 겉테·윤곽이 없다',
          );
        }
        expect(
          _contrast(style.ringColor, BadgeTierTokens.contourColor),
          greaterThanOrEqualTo(_minBoundary),
          reason: '${tier.name}: 금속 띠가 이웃한 윤곽에 묻힌다',
        );
      }
    });

    test('이웃한 두 등급이 서로 갈린다', () {
      // 신호는 셋이다 — 금속색, 띠 개수, 링 전체 굵기. 색만으로 갈리던
      // 예전 값은 은색·금색의 상대휘도가 거의 같아 1.17:1 로 뭉갰다.
      //
      // 금속색 대비는 팀 10개를 돌지 않는다 — 링 색이 전부 불투명이라
      // 몸통 위에 합성해도 색이 그대로여서 열 번 모두 같은 값이 나온다.
      // 그 전제(불투명)를 먼저 단언하고 한 번만 잰다.
      for (final MapEntry(key: tier, value: style) in tiers.entries) {
        expect(
          style.rings.every((layer) => layer.color.a == 1),
          isTrue,
          reason:
              '${tier.name}: 링에 반투명 겹이 있어 몸통 색이 비쳐 나온다 — '
              '등급 구분을 팀별로 다시 재야 한다',
        );
      }

      for (var i = 1; i < order.length; i++) {
        final lo = tiers[order[i - 1]]!;
        final hi = tiers[order[i]]!;
        expect(
          _contrast(lo.ringColor, hi.ringColor),
          greaterThanOrEqualTo(_minTierStep),
          reason: '${order[i].name}: 아래 등급과 금속색이 구분되지 않는다',
        );
        expect(
          hi.bands,
          greaterThan(lo.bands),
          reason: '${order[i].name}: 띠 개수가 아래 등급보다 많지 않다',
        );
        expect(
          hi.ringWidth,
          greaterThan(lo.ringWidth),
          reason: '${order[i].name}: 링이 아래 등급보다 두껍지 않다',
        );
      }
    });
  });
}
