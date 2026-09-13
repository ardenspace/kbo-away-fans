import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../backend/auth.dart';
import '../../backend/user_data.dart';
import '../../content/kst.dart';
import '../../design/app_theme.dart';
import '../home/next_away_game.dart' show clockProvider;
import '../team_select/selected_team.dart';

/// 설정 시트와 앱 루트가 함께 보는 테마 설정.
@immutable
class ThemeSettings {
  const ThemeSettings({required this.family, required this.brightnessMode});

  const ThemeSettings.defaults()
    : family = AppThemeFamily.a,
      brightnessMode = ThemeMode.system;

  final AppThemeFamily family;
  final ThemeMode brightnessMode;

  ThemeSettings copyWith({AppThemeFamily? family, ThemeMode? brightnessMode}) =>
      ThemeSettings(
        family: family ?? this.family,
        brightnessMode: brightnessMode ?? this.brightnessMode,
      );

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings &&
      other.family == family &&
      other.brightnessMode == brightnessMode;

  @override
  int get hashCode => Object.hash(family, brightnessMode);
}

const String kThemeSettingsPrefsKey = 'theme_settings';
const String _themeCacheSeparator = '|';

/// 첫 프레임에 쓸 계정 귀속 테마 사본.
class ThemeSettingsStore {
  const ThemeSettingsStore();

  Future<ThemeSettings?> read(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final parts = prefs
        .getString(kThemeSettingsPrefsKey)
        ?.split(_themeCacheSeparator);
    if (parts == null || parts.length != 3 || parts.first != uid) return null;
    final family = AppThemeFamily.values.where((v) => v.name == parts[1]);
    final mode = ThemeMode.values.where((v) => v.name == parts[2]);
    if (family.length != 1 || mode.length != 1) return null;
    return ThemeSettings(family: family.single, brightnessMode: mode.single);
  }

  Future<void> write(String uid, ThemeSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kThemeSettingsPrefsKey,
      '$uid$_themeCacheSeparator${settings.family.name}'
      '$_themeCacheSeparator${settings.brightnessMode.name}',
    );
  }
}

final themeSettingsStoreProvider = Provider<ThemeSettingsStore>(
  (_) => const ThemeSettingsStore(),
);

final cachedThemeSettingsProvider =
    AsyncNotifierProvider<CachedThemeSettings, ThemeSettings?>(
      CachedThemeSettings.new,
      retry: (retryCount, error) => null,
    );

class CachedThemeSettings extends AsyncNotifier<ThemeSettings?> {
  ({String uid, ThemeSettings settings})? _written;

  @override
  Future<ThemeSettings?> build() async {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return null;
    final stored = await ref.watch(themeSettingsStoreProvider).read(user.uid);
    final written = _written;
    return written?.uid == user.uid ? written!.settings : stored;
  }

  Future<void> write(String uid, ThemeSettings settings) async {
    final entry = (uid: uid, settings: settings);
    if (_written == entry) return;
    await ref.read(themeSettingsStoreProvider).write(uid, settings);
    _written = entry;
    state = AsyncData(settings);
  }
}

/// 프로필의 테마 설정을 화면에 즉시 반영하고 원본 사용자 문서에 남긴다.
///
/// 쓰기는 한 줄로 세워 빠르게 연속 선택해도 마지막 선택이 서버에 남는다. 화면
/// 상태는 서버 왕복보다 먼저 바뀌며, 실패하면 그 쓰기가 아직 최신 선택인 필드만
/// 되돌린다. 서로 다른 두 필드의 선택은 한쪽 실패로 함께 되돌아가지 않는다.
final themeSettingsProvider =
    NotifierProvider<ThemeSettingsNotifier, ThemeSettings>(
      ThemeSettingsNotifier.new,
    );

class ThemeSettingsNotifier extends Notifier<ThemeSettings> {
  Future<void> _queue = Future<void>.value();
  String? _ownerUid;
  AppThemeFamily? _pendingFamily;
  ThemeMode? _pendingBrightnessMode;
  int _familyRevision = 0;
  int? _pendingFamilyRevision;
  int? _completedFamilyRevision;
  int _brightnessRevision = 0;
  int? _pendingBrightnessRevision;
  int? _completedBrightnessRevision;

  @override
  ThemeSettings build() {
    final ownerUid = ref.watch(authStateProvider).value?.uid;
    final profile = ref.watch(userProfileProvider).value;
    final cached = ref.watch(cachedThemeSettingsProvider).value;

    if (_ownerUid != ownerUid) {
      _ownerUid = ownerUid;
      _pendingFamily = null;
      _pendingBrightnessMode = null;
      _pendingFamilyRevision = null;
      _completedFamilyRevision = null;
      _pendingBrightnessRevision = null;
      _completedBrightnessRevision = null;
      _queue = Future<void>.value();
    }
    if (profile == null || profile.uid != ownerUid) {
      return cached ?? const ThemeSettings.defaults();
    }

    final storedFamily = AppThemeFamily.values.byName(
      profile.defaultThemeFamily.name,
    );
    final storedBrightnessMode = _themeModeOf(profile.brightnessPreference);
    if (_pendingFamily == storedFamily &&
        _pendingFamilyRevision == _completedFamilyRevision) {
      _pendingFamily = null;
      _pendingFamilyRevision = null;
    }
    if (_pendingBrightnessMode == storedBrightnessMode &&
        _pendingBrightnessRevision == _completedBrightnessRevision) {
      _pendingBrightnessMode = null;
      _pendingBrightnessRevision = null;
    }
    final resolved = ThemeSettings(
      family: _pendingFamily ?? storedFamily,
      brightnessMode: _pendingBrightnessMode ?? storedBrightnessMode,
    );
    if (_pendingFamily == null && _pendingBrightnessMode == null) {
      unawaited(_writeThemeCache(profile.uid, resolved));
    }
    return resolved;
  }

  Future<void> setFamily(AppThemeFamily family) {
    final profile = _currentProfile();
    final previous = state.family;
    if (family == previous) return Future<void>.value();

    final revision = ++_familyRevision;
    _pendingFamily = family;
    _pendingFamilyRevision = revision;
    state = state.copyWith(family: family);
    return _enqueue(
      profile: profile,
      patch: UserProfilePatch(
        defaultThemeFamily: DefaultThemeFamily.values.byName(family.name),
      ),
      onCompleted: () {
        _completedFamilyRevision = revision;
        if (_pendingFamilyRevision != revision) return;
        final stored = ref.read(userProfileProvider).value;
        if (stored?.uid != profile.uid ||
            stored?.defaultThemeFamily.name != family.name) {
          return;
        }
        _pendingFamily = null;
        _pendingFamilyRevision = null;
      },
      rollback: () {
        if (_pendingFamilyRevision != revision) return;
        _pendingFamily = null;
        _pendingFamilyRevision = null;
        state = state.copyWith(family: previous);
      },
      cacheSettings: state.copyWith(family: family),
    );
  }

  Future<void> setBrightnessMode(ThemeMode mode) {
    final profile = _currentProfile();
    final previous = state.brightnessMode;
    if (mode == previous) return Future<void>.value();

    final revision = ++_brightnessRevision;
    _pendingBrightnessMode = mode;
    _pendingBrightnessRevision = revision;
    state = state.copyWith(brightnessMode: mode);
    return _enqueue(
      profile: profile,
      patch: UserProfilePatch(
        brightnessPreference: _brightnessPreferenceOf(mode),
      ),
      onCompleted: () {
        _completedBrightnessRevision = revision;
        if (_pendingBrightnessRevision != revision) return;
        final stored = ref.read(userProfileProvider).value;
        if (stored?.uid != profile.uid ||
            _themeModeOf(stored!.brightnessPreference) != mode) {
          return;
        }
        _pendingBrightnessMode = null;
        _pendingBrightnessRevision = null;
      },
      rollback: () {
        if (_pendingBrightnessRevision != revision) return;
        _pendingBrightnessMode = null;
        _pendingBrightnessRevision = null;
        state = state.copyWith(brightnessMode: previous);
      },
      cacheSettings: state.copyWith(brightnessMode: mode),
    );
  }

  UserProfile _currentProfile() {
    final profile = ref.read(userProfileProvider).value;
    final ownerUid = ref.read(authStateProvider).value?.uid;
    if (profile == null || profile.uid != ownerUid) {
      throw StateError('테마 설정을 저장할 사용자 프로필이 없다');
    }
    return profile;
  }

  Future<void> _enqueue({
    required UserProfile profile,
    required UserProfilePatch patch,
    required VoidCallback onCompleted,
    required VoidCallback rollback,
    required ThemeSettings cacheSettings,
  }) async {
    Future<void> write() async {
      if (ref.read(authStateProvider).value?.uid != profile.uid) return;
      await ref.read(userDataStoreProvider).patchProfile(profile.uid, patch);
    }

    final task = _queue.then((_) => write(), onError: (_) => write());
    _queue = task;
    try {
      await task;
      if (_ownerUid == profile.uid) {
        onCompleted();
        await _writeThemeCache(profile.uid, cacheSettings);
      }
    } on Object {
      if (_ownerUid == profile.uid) rollback();
      rethrow;
    }
  }

  Future<void> _writeThemeCache(String uid, ThemeSettings settings) async {
    try {
      await ref.read(cachedThemeSettingsProvider.notifier).write(uid, settings);
    } on Object {
      // 원본 프로필 저장이 성공한 뒤 보조 캐시 실패로 화면을 되돌리지 않는다.
      // 다음 서버 스냅샷 또는 다음 설정 저장에서 다시 갱신한다.
    }
  }
}

/// 앱 루트가 `MaterialApp`에 공급하는 최종 테마.
///
/// 선택 팀은 [selectedTeamIdProvider]의 낙관적 값을 써서 팀 변경도 즉시
/// 반영한다. [AppVisualTheme.resolve]가 팀이 있을 때 A/B 계열보다 팀 색을
/// 우선하므로, 계열 선택은 저장되면서도 팀을 해제하기 전까지 겉으로 드러나지
/// 않는다.
final appVisualThemeProvider = Provider<AppVisualTheme>((ref) {
  final settings = ref.watch(themeSettingsProvider);
  final selectedTeam = ref.watch(selectedTeamIdProvider);
  final teamId = selectedTeam.hasValue ? selectedTeam.value : null;
  final brightness = ref.watch(resolvedThemeBrightnessProvider);
  return AppVisualTheme.resolve(
    favoriteTeamId: teamId,
    defaultFamily: settings.family,
    brightness: brightness,
  );
});

/// 수동 선택 또는 KST 시각 정책으로 해석한 실제 밝기.
///
/// 시간 경계에서의 재계산 예약은 이 provider가 아니라 앱 생명주기를 소유한
/// `KboAwayFansApp`이 맡는다. 그래서 구독자가 없는 provider가 긴 타이머를 남기지
/// 않는다. [clockProvider]를 재사용해 경계 테스트는 고정 시각을 주입할 수 있다.
final resolvedThemeBrightnessProvider = Provider<Brightness>((ref) {
  final mode = ref.watch(themeSettingsProvider).brightnessMode;
  if (mode == ThemeMode.light) return Brightness.light;
  if (mode == ThemeMode.dark) return Brightness.dark;

  final now = ref.watch(clockProvider)();
  return automaticThemeBrightness(now);
});

/// KST 07:00~18:59는 밝음, 그 밖은 어두움이다.
Brightness automaticThemeBrightness(DateTime moment) {
  final hour = moment.toUtc().add(kstOffset).hour;
  return hour >= 7 && hour < 19 ? Brightness.light : Brightness.dark;
}

/// 자동 밝기가 다음으로 바뀌기까지 남은 시간.
Duration durationUntilNextThemeBoundary(DateTime moment) {
  final kst = moment.toUtc().add(kstOffset);
  final next = switch (kst.hour) {
    < 7 => DateTime.utc(kst.year, kst.month, kst.day, 7),
    < 19 => DateTime.utc(kst.year, kst.month, kst.day, 19),
    _ => DateTime.utc(kst.year, kst.month, kst.day + 1, 7),
  };
  return next.difference(kst);
}

ThemeMode _themeModeOf(BrightnessPreference preference) => switch (preference) {
  BrightnessPreference.auto => ThemeMode.system,
  BrightnessPreference.light => ThemeMode.light,
  BrightnessPreference.dark => ThemeMode.dark,
};

BrightnessPreference _brightnessPreferenceOf(ThemeMode mode) => switch (mode) {
  ThemeMode.system => BrightnessPreference.auto,
  ThemeMode.light => BrightnessPreference.light,
  ThemeMode.dark => BrightnessPreference.dark,
};
