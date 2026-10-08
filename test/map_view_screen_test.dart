import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/providers.dart';
import 'package:custom_map_marker/features/map_view/map_view_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MapCamera Function()> pumpMap(
    WidgetTester tester, {
    required int width,
    required int height,
  }) async {
    // Same logical size as the test phone (1080x2340 @ 2.75).
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          markersProvider.overrideWith((ref, mapId) => Stream.value(const [])),
        ],
        child: MaterialApp(
          home: MapViewScreen(
            project: MapProject(
              id: 'map',
              name: 'Mapa',
              imagePath: '/nonexistent.png',
              widthPx: width,
              heightPx: height,
              createdAt: DateTime(2026),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return () => MapCamera.of(tester.element(find.byType(MarkerLayer)));
  }

  bool showsWholeImage(MapCamera camera) {
    final visible = camera.visibleBounds;
    // The image spans one unit along its longer side, from the top-left at
    // (0, 0) towards east and south.
    return visible.west <= 0 && visible.east >= 1 ||
        visible.north >= 0 && visible.south <= -1;
  }

  for (final (w, h) in [
    (20, 10),
    (1000, 800),
    (4000, 3000),
    (3000, 12000),
    (60000, 40000),
  ]) {
    testWidgets('initially shows the whole $w×$h image', (tester) async {
      final camera = await pumpMap(tester, width: w, height: h);
      expect(showsWholeImage(camera()), isTrue);
    });
  }

  testWidgets('can zoom out below the fitted view and fit again', (
    tester,
  ) async {
    final camera = await pumpMap(tester, width: 4000, height: 3000);
    final fitted = camera().zoom;

    await tester.tap(find.byTooltip('Przybliż'));
    await tester.pump();
    expect(camera().zoom, closeTo(fitted + 1, 1e-9));

    await tester.tap(find.byTooltip('Oddal'));
    await tester.tap(find.byTooltip('Oddal'));
    await tester.pump();
    expect(camera().zoom, lessThan(fitted));

    await tester.tap(find.byTooltip('Pokaż całą mapę'));
    await tester.pump();
    expect(camera().zoom, closeTo(fitted, 1e-9));
    expect(showsWholeImage(camera()), isTrue);
  });
}
