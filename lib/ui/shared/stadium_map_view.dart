import 'package:flutter/material.dart';

import '../../design/tokens.dart';

/// flutter_naver_map 래퍼 — 마커·모션·길안내 딥링크를 한곳에 모으는
/// 앱 내 모든 지도 표시 지점.
///
/// 골격 단계: 네이버 지도 SDK(클라이언트 ID·플랫폼 설정) 연결 전이므로
/// 자리 표시만 렌더한다. SDK 연결은 지도 step에서 이 위젯 내부만 교체한다.
class StadiumMapView extends StatelessWidget {
  const StadiumMapView({
    super.key,
    required this.stadiumId,
  });

  /// 중심이 되는 구장의 안정 id (stadiums.json의 id).
  final String stadiumId;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(RadiusTokens.md),
      child: ColoredBox(
        color: ColorTokens.surfaceDim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(SpaceTokens.lg),
            child: Text(
              '지도 준비 중 · $stadiumId',
              style: const TextStyle(
                fontFamily: TypeTokens.fontFamily,
                fontSize: TypeTokens.label,
                fontWeight: TypeTokens.weightMedium,
                color: ColorTokens.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
