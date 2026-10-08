import 'package:custom_map_marker/core/coordinate_mapper.dart';
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
    int? tileMaxZoom,
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
              tileMaxZoom: tileMaxZoom,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return () => MapCamera.of(tester.element(find.byType(MarkerLayer)));
  }

  bool showsWholeImage(MapCamera camera, int width, int height) {
    final image = MapCoordinateMapper(widthPx: width, heightPx: height).bounds;
    final visible = camera.visibleBounds;
    return visible.west <= image.west &&
        visible.east >= image.east &&
        visible.north >= image.north &&
        visible.south <= image.south;
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
      expect(showsWholeImage(camera(), w, h), isTrue);
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
    expect(showsWholeImage(camera(), 4000, 3000), isTrue);
  });

  testWidgets('draws small maps as one image and large maps as tiles', (
    tester,
  ) async {
    await pumpMap(tester, width: 1000, height: 800);
    expect(find.byType(OverlayImageLayer), findsOneWidget);
    expect(find.byType(TileLayer), findsNothing);

    final camera = await pumpMap(
      tester,
      width: 10000,
      height: 6000,
      tileMaxZoom: 6,
    );
    expect(find.byType(TileLayer), findsOneWidget);
    expect(find.byType(OverlayImageLayer), findsNothing);
    expect(showsWholeImage(camera(), 10000, 6000), isTrue);
  });

  testWidgets('requests tiles matching physical pixels on dense screens', (
    tester,
  ) async {
    // pumpMap uses a 2.75× screen: tiles come from 2 levels higher and are
    // drawn at a quarter of the usual size.
    await pumpMap(tester, width: 10000, height: 6000, tileMaxZoom: 6);
    final layer = tester.widget<TileLayer>(find.byType(TileLayer));
    expect(layer.tileDimension, 64);
    expect(layer.zoomOffset, 2);
    expect(layer.maxNativeZoom, 4);
  });
}
