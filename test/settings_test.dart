import 'package:custom_map_marker/data/settings.dart';
import 'package:custom_map_marker/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('everything is on by default', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final s = container.read(settingsProvider);
    expect(
      (
        s.snapToMarkers,
        s.showRouteNames,
        s.showAreaNames,
        s.showRoutes,
        s.showAreas,
        s.clusterMarkers,
      ),
      (true, true, true, true, true, true),
    );
  });

  test('loads stored values and stores changes', () async {
    final store = MemorySettingsStore()..setBool('showAreaNames', false);
    final container = ProviderContainer(
      overrides: [settingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    expect(container.read(settingsProvider).showAreaNames, isFalse);

    await container.read(settingsProvider.notifier).setSnapToMarkers(false);
    expect(container.read(settingsProvider).snapToMarkers, isFalse);
    expect(store.getBool('snapToMarkers'), isFalse);

    await container.read(settingsProvider.notifier).setClusterMarkers(false);
    expect(container.read(settingsProvider).clusterMarkers, isFalse);
    expect(store.getBool('clusterMarkers'), isFalse);
  });

  testWidgets('the settings screen toggles options', (tester) async {
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.tap(find.text('Nazwy tras'));
    await tester.pump();
    expect(store.getBool('showRouteNames'), isFalse);
    final tile = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Nazwy tras'),
    );
    expect(tile.value, isFalse);
  });

  testWidgets('the settings screen turns marker grouping off', (tester) async {
    final store = MemorySettingsStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [settingsStoreProvider.overrideWithValue(store)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Grupuj pobliskie znaczniki'),
      100,
    );
    await tester.tap(find.text('Grupuj pobliskie znaczniki'));
    await tester.pump();
    expect(store.getBool('clusterMarkers'), isFalse);
  });
}
