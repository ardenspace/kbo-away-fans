/// 응원 팀 선택의 저장·상태 계층 (step 2.2).
///
/// 저장은 shared_preferences 단일 키 — 값은 common.defs teamId 10종
/// (`lib/content/content_ids.dart` 의 [kTeamIds]). 서버 전송 없음(spec
/// "로컬 prefs" 계약). 미지/오염 값은 읽기 시 null 로 취급해
/// 온보딩으로 자연 복귀한다.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../content/content_ids.dart';

/// 선택한 응원 팀 id 가 저장되는 prefs 키.
const String kSelectedTeamPrefsKey = 'selected_team_id';

/// 응원 팀 id 의 기기 저장소 (shared_preferences 래퍼).
class SelectedTeamStore {
  const SelectedTeamStore();

  /// 저장된 팀 id. 없거나 로스터([kTeamIds]) 밖 값이면 null.
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(kSelectedTeamPrefsKey);
    if (id == null || !kTeamIds.contains(id)) return null;
    return id;
  }

  /// 팀 id 를 저장한다. 로스터 밖 id 는 프로그래밍 오류.
  Future<void> write(String teamId) async {
    assert(kTeamIds.contains(teamId), '알 수 없는 teamId: $teamId');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kSelectedTeamPrefsKey, teamId);
  }
}

/// 저장소 주입 지점 (테스트에서 override 가능).
final selectedTeamStoreProvider = Provider<SelectedTeamStore>(
  (_) => const SelectedTeamStore(),
);

/// 현재 응원 팀 id — null 이면 미선택(온보딩 대상).
final selectedTeamIdProvider =
    AsyncNotifierProvider<SelectedTeamNotifier, String?>(
  SelectedTeamNotifier.new,
);

/// 응원 팀 선택 상태 — 기기 저장과 앱 상태를 함께 갱신한다.
class SelectedTeamNotifier extends AsyncNotifier<String?> {
  @override
  Future<String?> build() => ref.watch(selectedTeamStoreProvider).read();

  /// 팀을 선택한다: 저장 후 상태 반영 — 루트 게이트가 즉시 홈으로 전환하고
  /// 홈의 TeamThemeScope 가 새 팀 테마를 적용한다.
  Future<void> select(String teamId) async {
    await ref.read(selectedTeamStoreProvider).write(teamId);
    state = AsyncData(teamId);
  }
}
