import 'package:flutter/material.dart';

import '../../design/app_theme.dart';
import '../../design/tokens.dart';
import 'themed_surface.dart';

/// 홈의 실시간 원정 여정이 거치는 사건 상태.
enum JourneyStatus { moving, nearby, live, postgame, cancelled }

/// 이동·도착·라이브·경기 종료·취소를 사건 중심으로 보여 주는 공통 비주얼.
///
/// 상태가 바뀔 때만 한 번 전환하며 반복 장식은 없다. 시스템이 애니메이션을
/// 끄도록 요청하면 [AnimatedSwitcher]도 만들지 않아 정적인 대안을 제공한다.
class JourneyStatusVisual extends StatelessWidget {
  const JourneyStatusVisual({
    super.key,
    required this.status,
    this.title,
    this.detail,
  });

  final JourneyStatus status;
  final String? title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final visual = Theme.of(context).extension<AppVisualTheme>()!;
    final presentation = _presentation(visual);
    final content = Semantics(
      key: ValueKey(status),
      container: true,
      label: '${title ?? presentation.title}. ${detail ?? presentation.detail}',
      child: ThemedSurface(
        tinted: true,
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                  presentation.accent.withValues(
                    alpha: JourneyTokens.statusTintOpacity,
                  ),
                  visual.surface,
                ),
                borderRadius: BorderRadius.circular(RadiusTokens.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.all(SpaceTokens.md),
                child: Icon(presentation.icon, color: presentation.accent),
              ),
            ),
            const SizedBox(width: SpaceTokens.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title ?? presentation.title,
                    style: TextTokens.bodyStrong.copyWith(
                      color: visual.textPrimary,
                    ),
                  ),
                  const SizedBox(height: SpaceTokens.xs),
                  Text(
                    detail ?? presentation.detail,
                    style: TextTokens.supporting.copyWith(
                      color: visual.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return content;
    return AnimatedSwitcher(
      duration: MotionTokens.base,
      switchInCurve: MotionTokens.standard,
      switchOutCurve: MotionTokens.standard,
      child: content,
    );
  }

  _JourneyPresentation _presentation(AppVisualTheme visual) => switch (status) {
    JourneyStatus.moving => _JourneyPresentation(
      icon: Icons.train_rounded,
      title: '구장으로 이동 중',
      detail: '원정길의 현재 위치를 확인해 보세요',
      accent: visual.primary,
    ),
    JourneyStatus.nearby => _JourneyPresentation(
      icon: Icons.sports_baseball_rounded,
      title: '구장 근처에 도착했어요',
      detail: '주변 추천과 입장 준비를 확인해 보세요',
      accent: visual.secondary,
    ),
    JourneyStatus.live => _JourneyPresentation(
      icon: Icons.sensors_rounded,
      title: '경기가 진행 중이에요',
      detail: '현재 경기 흐름을 함께 따라가요',
      accent: visual.success,
    ),
    JourneyStatus.postgame => _JourneyPresentation(
      icon: Icons.emoji_events_rounded,
      title: '경기가 끝났어요',
      detail: '오늘의 원정 기록을 남겨 보세요',
      accent: visual.success,
    ),
    JourneyStatus.cancelled => _JourneyPresentation(
      icon: Icons.cloud_off_rounded,
      title: '경기가 취소됐어요',
      detail: '변경된 일정과 안내를 확인해 주세요',
      accent: visual.danger,
    ),
  };
}

class _JourneyPresentation {
  const _JourneyPresentation({
    required this.icon,
    required this.title,
    required this.detail,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color accent;
}
