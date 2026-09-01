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
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// 링 한 겹을 몸통 위에 올린 실제 화면 색 (반투명이면 몸통이 비쳐 나온다).
Color _over(Color body, Color layer) => Color.alphaBlend(layer, body);

/// 몸통 [body] 위에서 등급 [style] 이 얻는 **보장 대비** — 링을 이루는 겹
/// 가운데 몸통과 가장 크게 갈리는 겹의 대비.
///
/// 최대값을 쓰는 이유: 링은 여러 겹이 붙은 한 덩어리이고, 몸통과 같은
/// 밝기의 겹은 몸통에 묻히지만 그 옆의 겹이 갈리면 링의 존재는 그대로
/// 읽힌다. 밝은 겉테와 어두운 윤곽을 함께 두는 표현이 어떤 몸통 색에서도
/// 성립하는 근거가 이것이다.
double _guaranteedContrast(Color body, BadgeTierStyle style) => style.rings
    .map((layer) => _contrast(_over(body, layer.color), body))
    .reduce((a, b) => a > b ? a : b);

/// 비텍스트 UI 경계의 최소선 (WCAG 2.1 SC 1.4.11).
const double _minBoundary = 3;

/// 충분선 — 이 위로는 대비를 더 올려도 "테두리가 또렷하다"는 판단이 달라지지
/// 않는다고 보는 선. 밝은 겉테와 어두운 윤곽을 함께 둔 링이 **어떤 색 위에서도**
/// 넘게 되는 값(4.16:1, 흰색과 잉크색의 대비 곡선이 만나는 지점)에서 왔다.
const double _sufficient = 4;

/// 이웃 등급이 갈렸다고 볼 최소 대비.
const double _minTierStep = 1.5;

void main() {
  final teams = TeamThemes.byId;
  final tiers = BadgeTierTokens.byTier;
  const order = [BadgeTier.first, BadgeTier.regular, BadgeTier.master];

  group('배지 등급이 10개 팀 대표색 위에서 읽히는가', () {
    test('각 등급의 링이 팀 몸통색과 최소 3:1 로 갈린다', () {
      final failures = <String>[];
      for (final MapEntry(key: teamId, value: theme) in teams.entries) {
        for (final MapEntry(key: tier, value: style) in tiers.entries) {
          final ratio = _guaranteedContrast(theme.primary, style);
          if (ratio < _minBoundary) {
            failures.add(
              '$teamId × ${tier.name}: ${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      }
      expect(
        failures,
        isEmpty,
        reason: '팀 색 위에서 등급 링이 묻힌다:\n${failures.join('\n')}',
      );
    });

    test('같은 등급이 10개 팀 색 어디에서나 충분선 위에서 읽힌다', () {
      // 균일성을 "팀 간 대비 수치의 편차"로 재지 않는 이유:
      // 검은 몸통(kt) 위의 흰 겉테는 21:1 이고, 이 값을 기아 위의 4.6:1 에
      // 맞추려면 legibility 를 일부러 깎아야 한다. 게다가 몸통 상대휘도가
      // 0(kt)~0.26(한화)로 벌어져 있어, 몸통과 무관한 오버레이 한 벌로
      // "최소 3:1 이면서 팀 간 편차 1.5배 이내"는 아예 성립하지 않는다
      // (kt 에서 4.5:1 이하이려면 합성색 상대휘도 ≤0.175, 기아에서 3:1
      //  이상이려면 ≥0.63 — 같은 오버레이가 두 조건을 함께 만족할 수 없다).
      // 그래서 편차 상한 대신 **모든 팀이 충분선을 넘는지**를 잰다. 최소선
      // 3:1 보다 높은 요구이므로 검사는 느슨해지지 않는다.
      final failures = <String>[];
      for (final MapEntry(key: teamId, value: theme) in teams.entries) {
        for (final MapEntry(key: tier, value: style) in tiers.entries) {
          final ratio = _guaranteedContrast(theme.primary, style);
          if (ratio < _sufficient) {
            failures.add(
              '$teamId × ${tier.name}: ${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      }
      expect(
        failures,
        isEmpty,
        reason: '충분선($_sufficient:1)에 못 미치는 조합:\n${failures.join('\n')}',
      );
    });

    test('보장 대비는 팀 색이 아니라 링 구조에서 온다 — 색 공간 전체', () {
      // 팀 대표색은 "초기값이며 추후 조정할 수 있다"(team_themes.dart).
      // 10개 색에 맞춰 튜닝한 값이 아니라 어떤 몸통 색에도 성립하는 구조인지
      // 를 확인한다 — sRGB 큐브를 격자로 훑는다.
      final failures = <String>[];
      for (var r = 0; r <= 255; r += 15) {
        for (var g = 0; g <= 255; g += 15) {
          for (var b = 0; b <= 255; b += 15) {
            final body = Color.fromARGB(255, r, g, b);
            for (final MapEntry(key: tier, value: style) in tiers.entries) {
              final ratio = _guaranteedContrast(body, style);
              if (ratio < _sufficient) {
                failures.add(
                  '#$r,$g,$b × ${tier.name}: ${ratio.toStringAsFixed(2)}:1',
                );
              }
            }
          }
        }
      }
      expect(
        failures,
        isEmpty,
        reason: '몸통 색에 따라 링이 묻히는 구간이 있다:\n'
            '${failures.take(10).join('\n')}',
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
      final failures = <String>[];
      for (final MapEntry(key: teamId, value: theme) in teams.entries) {
        for (var i = 1; i < order.length; i++) {
          final lo = _over(theme.primary, tiers[order[i - 1]]!.ringColor);
          final hi = _over(theme.primary, tiers[order[i]]!.ringColor);
          final ratio = _contrast(lo, hi);
          if (ratio < _minTierStep) {
            failures.add(
              '$teamId: ${order[i - 1].name} ↔ ${order[i].name} '
              '${ratio.toStringAsFixed(2)}:1',
            );
          }
        }
      }
      expect(
        failures,
        isEmpty,
        reason: '이웃 등급이 색으로 구분되지 않는다:\n${failures.join('\n')}',
      );

      for (var i = 1; i < order.length; i++) {
        final lo = tiers[order[i - 1]]!;
        final hi = tiers[order[i]]!;
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
