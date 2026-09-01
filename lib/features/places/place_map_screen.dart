import 'package:flutter/material.dart';

import '../../content/models.dart';
import '../../design/tokens.dart';
import '../../ui/shared/map_links.dart';
import '../../ui/shared/stadium_map_view.dart';
import '../../ui/shared/team_theme_scope.dart';

/// 장소 지도 화면 — PlaceDetailSheet '지도에서 보기'로 진입한다.
///
/// 앱 내 지도([StadiumMapView])에 구장·장소 마커를 띄우고,
/// '길안내'는 네이버지도 앱/웹 딥링크([launchNaverMapRoute])로 나간다.
class PlaceMapScreen extends StatelessWidget {
  const PlaceMapScreen({
    super.key,
    required this.place,
    this.stadium,
    this.themeKey,
  });

  /// 지도 중심이 되는 추천 장소.
  final Place place;

  /// 원정 구장 — stadiums 문서를 못 얻었으면 null (장소 마커만 표시).
  final Stadium? stadium;

  /// 화면에 적용할 팀 테마 키 (null 이면 기본 토큰).
  final String? themeKey;

  @override
  Widget build(BuildContext context) {
    final themeKey = this.themeKey;
    if (themeKey == null) return _scaffold(context);
    return TeamThemeScope.forTeam(
      teamId: themeKey,
      // 앱바가 스코프 안쪽 context 로 테마를 읽도록 Builder 를 끼운다.
      child: Builder(builder: _scaffold),
    );
  }

  Widget _scaffold(BuildContext context) {
    final stadium = this.stadium;
    final markers = <StadiumMapMarker>[
      StadiumMapMarker(
        id: 'place-${place.id}',
        label: place.name,
        lat: place.lat,
        lng: place.lng,
      ),
      if (stadium != null)
        StadiumMapMarker(
          id: 'stadium-${stadium.id}',
          label: stadium.name,
          lat: stadium.lat,
          lng: stadium.lng,
        ),
    ];
    // 구장이 있으면 두 마커가 같이 보이게 중점을 중심으로 잡는다.
    final centerLat = stadium == null
        ? place.lat
        : (place.lat + stadium.lat) / 2;
    final centerLng = stadium == null
        ? place.lng
        : (place.lng + stadium.lng) / 2;

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: _appBar(context),
      body: Padding(
        padding: const EdgeInsets.all(SpaceTokens.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: StadiumMapView(
                centerLat: centerLat,
                centerLng: centerLng,
                markers: markers,
              ),
            ),
            const SizedBox(height: SpaceTokens.md),
            FilledButton(
              onPressed: () => launchNaverMapRoute(
                name: place.name,
                lat: place.lat,
                lng: place.lng,
              ),
              child: const Text('길안내'),
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    final theme = TeamThemeScope.maybeOf(context);
    final barBg = theme?.primary ?? ColorTokens.surface;
    final barFg = theme?.onPrimary ?? ColorTokens.textPrimary;
    return AppBar(
      backgroundColor: barBg,
      foregroundColor: barFg,
      title: Text(
        place.name,
        style: TextTokens.appBarTitle.copyWith(color: barFg),
      ),
    );
  }
}
