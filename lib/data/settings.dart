import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide options, shared by all maps.
@immutable
class AppSettings {
  const AppSettings({
    this.snapToMarkers = true,
    this.showRouteNames = true,
    this.showAreaNames = true,
    this.showRoutes = true,
    this.showAreas = true,
  });

  /// While drawing a route or area, a tap near a marker puts the point
  /// exactly on it. The point stays independent of the marker afterwards.
  final bool snapToMarkers;
  final bool showRouteNames;
  final bool showAreaNames;

  /// Whether routes and areas are drawn at all (on every map).
  final bool showRoutes;
  final bool showAreas;

  AppSettings copyWith({
    bool? snapToMarkers,
    bool? showRouteNames,
    bool? showAreaNames,
    bool? showRoutes,
    bool? showAreas,
  }) => AppSettings(
    snapToMarkers: snapToMarkers ?? this.snapToMarkers,
    showRouteNames: showRouteNames ?? this.showRouteNames,
    showAreaNames: showAreaNames ?? this.showAreaNames,
    showRoutes: showRoutes ?? this.showRoutes,
    showAreas: showAreas ?? this.showAreas,
  );
}

/// Where settings are kept between launches.
abstract interface class SettingsStore {
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
}

/// Keeps settings only while the app runs; the default until main provides
/// persistent storage, and what tests use.
class MemorySettingsStore implements SettingsStore {
  final _values = <String, bool>{};

  @override
  bool? getBool(String key) => _values[key];

  @override
  Future<void> setBool(String key, bool value) async => _values[key] = value;
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static const keys = {
    SettingsNotifier._snapKey,
    SettingsNotifier._routeNamesKey,
    SettingsNotifier._areaNamesKey,
    SettingsNotifier._routesKey,
    SettingsNotifier._areasKey,
  };

  /// Loads stored settings once, so screens never show defaults first.
  static Future<PrefsSettingsStore> load() async => PrefsSettingsStore(
    await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(allowList: keys),
    ),
  );

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => MemorySettingsStore(),
);

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _snapKey = 'snapToMarkers';
  static const _routeNamesKey = 'showRouteNames';
  static const _areaNamesKey = 'showAreaNames';
  static const _routesKey = 'showRoutes';
  static const _areasKey = 'showAreas';

  SettingsStore get _store => ref.read(settingsStoreProvider);

  @override
  AppSettings build() {
    final store = ref.watch(settingsStoreProvider);
    const defaults = AppSettings();
    return AppSettings(
      snapToMarkers: store.getBool(_snapKey) ?? defaults.snapToMarkers,
      showRouteNames: store.getBool(_routeNamesKey) ?? defaults.showRouteNames,
      showAreaNames: store.getBool(_areaNamesKey) ?? defaults.showAreaNames,
      showRoutes: store.getBool(_routesKey) ?? defaults.showRoutes,
      showAreas: store.getBool(_areasKey) ?? defaults.showAreas,
    );
  }

  Future<void> setSnapToMarkers(bool value) {
    state = state.copyWith(snapToMarkers: value);
    return _store.setBool(_snapKey, value);
  }

  Future<void> setShowRouteNames(bool value) {
    state = state.copyWith(showRouteNames: value);
    return _store.setBool(_routeNamesKey, value);
  }

  Future<void> setShowAreaNames(bool value) {
    state = state.copyWith(showAreaNames: value);
    return _store.setBool(_areaNamesKey, value);
  }

  Future<void> setShowRoutes(bool value) {
    state = state.copyWith(showRoutes: value);
    return _store.setBool(_routesKey, value);
  }

  Future<void> setShowAreas(bool value) {
    state = state.copyWith(showAreas: value);
    return _store.setBool(_areasKey, value);
  }
}
