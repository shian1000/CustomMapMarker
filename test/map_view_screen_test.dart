import 'package:custom_map_marker/core/coordinate_mapper.dart';
import 'package:custom_map_marker/data/legend.dart';
import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/providers.dart';
import 'package:custom_map_marker/features/map_view/clustered_marker_layer.dart';
import 'package:custom_map_marker/features/map_view/map_view_screen.dart';
import 'package:custom_map_marker/shared/marker_colors.dart';
import 'package:custom_map_marker/shared/widgets/marker_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeMapRepository repo;
  late FakeLegendRepository legendRepo;
  late FakeMarkerRepository markerRepo;

  setUp(() {
    legendRepo = FakeLegendRepository();
    markerRepo = FakeMarkerRepository();
  });

  Future<MapCamera Function()> pumpMap(
    WidgetTester tester, {
    required int width,
    required int height,
    int? tileMaxZoom,
    List<MapMarker> markers = const [],
    MapLegend legend = const {},
  }) async {
    // Same logical size as the test phone (1080x2340 @ 2.75).
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    final project = testMap(
      'map',
      width: width,
      height: height,
      tileMaxZoom: tileMaxZoom,
    );
    repo = FakeMapRepository([MapSummary(map: project, markerCount: 0)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          markersProvider.overrideWith((ref, mapId) => Stream.value(markers)),
          legendProvider.overrideWith((ref, mapId) => Stream.value(legend)),
          legendRepositoryProvider.overrideWithValue(legendRepo),
          markerRepositoryProvider.overrideWithValue(markerRepo),
          mapRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(home: MapViewScreen(project: project)),
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

  testWidgets('renames the map from the app bar', (tester) async {
    await pumpMap(tester, width: 1000, height: 800);
    expect(find.widgetWithText(AppBar, 'Mapa'), findsOneWidget);

    await tester.tap(find.byTooltip('Zmień nazwę'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Temeria');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();

    expect(repo.renamed, [('map', 'Temeria')]);
    expect(find.widgetWithText(AppBar, 'Temeria'), findsOneWidget);
  });

  testWidgets('flies to a marker picked from the list', (tester) async {
    final camera = await pumpMap(
      tester,
      width: 4000,
      height: 3000,
      markers: [
        MapMarker(
          id: 'k',
          mapId: 'map',
          x: 0.9,
          y: 0.1,
          label: 'Kaer Morhen',
          colorValue: 0xFF1E88E5,
          createdAt: DateTime(2026),
        ),
      ],
    );
    final fitted = camera().zoom;

    await tester.tap(find.byTooltip('Lista znaczników'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Kaer Morhen'));
    await tester.pumpAndSettle();

    final target = MapCoordinateMapper(
      widthPx: 4000,
      heightPx: 3000,
    ).toLatLng(const Offset(0.9, 0.1));
    expect(camera().center.latitude, closeTo(target.latitude, 1e-9));
    expect(camera().center.longitude, closeTo(target.longitude, 1e-9));
    expect(camera().zoom, closeTo(fitted + 2, 0.2));
  });

  group('legend filter', () {
    final red = markerColors[0].toARGB32();
    final green = markerColors[3].toARGB32();
    // Far apart, so they are never grouped.
    final markers = [
      testMarker('1', 'Wyzima', color: red, x: 0.1, y: 0.1),
      testMarker('2', 'Las', color: green, x: 0.9, y: 0.9),
    ];

    testWidgets('hides markers of hidden colors and flags the filter', (
      tester,
    ) async {
      await pumpMap(
        tester,
        width: 1000,
        height: 800,
        markers: markers,
        legend: {red: const LegendEntry(hidden: true)},
      );
      expect(find.byType(MarkerPin), findsOneWidget);
      expect(find.text('Las'), findsOneWidget);
      expect(find.text('Wyzima'), findsNothing);
      final badge = tester.widget<Badge>(find.byType(Badge));
      expect(badge.isLabelVisible, isTrue);

      await tester.tap(find.byTooltip('Lista znaczników'));
      await tester.pumpAndSettle();
      expect(find.text('1 z 1 · 1 ukryty filtrem'), findsOneWidget);
    });

    testWidgets('shows everything and no flag without hidden colors', (
      tester,
    ) async {
      await pumpMap(tester, width: 1000, height: 800, markers: markers);
      expect(find.byType(MarkerPin), findsNWidgets(2));
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('adding a marker in a hidden color shows that color again', (
      tester,
    ) async {
      await pumpMap(
        tester,
        width: 1000,
        height: 800,
        legend: {red: const LegendEntry(name: 'Miasta', hidden: true)},
      );
      await tester.longPressAt(tester.getCenter(find.byType(FlutterMap)));
      await tester.pumpAndSettle();
      // The editor names the selected (first, red) color.
      expect(find.text('Miasta'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nazwa'),
        'Oxenfurt',
      );
      await tester.tap(find.text('Dodaj'));
      await tester.pumpAndSettle();

      expect(markerRepo.added.single.$2.label, 'Oxenfurt');
      expect(legendRepo.hidden, [('map', red, false)]);
      expect(
        find.text('Kolor „Miasta” był ukryty filtrem – znów jest widoczny.'),
        findsOneWidget,
      );
    });
  });

  group('clustering', () {
    // Close together on a 4000 px wide image: overlap when zoomed out.
    final close = [
      testMarker('1', 'Wyzima', color: 0xFFE53935, x: 0.50, y: 0.50),
      testMarker('2', 'Oxenfurt', color: 0xFFE53935, x: 0.505, y: 0.50),
      testMarker('3', 'Novigrad', color: 0xFF1E88E5, x: 0.51, y: 0.505),
    ];
    final lone = testMarker(
      '4',
      'Kaer Morhen',
      color: 0xFF43A047,
      x: 0.9,
      y: 0.1,
    );

    testWidgets('groups overlapping markers into a counted circle', (
      tester,
    ) async {
      await pumpMap(
        tester,
        width: 4000,
        height: 3000,
        markers: [...close, lone],
      );
      final badge = tester.widget<MarkerClusterBadge>(
        find.byType(MarkerClusterBadge),
      );
      expect(badge.count, 3);
      // Mixed colors: neutral circle.
      expect(badge.color, isNull);
      expect(find.byType(MarkerPin), findsOneWidget);
      expect(find.text('Kaer Morhen'), findsOneWidget);
    });

    testWidgets('tapping a cluster zooms in until it splits', (tester) async {
      final camera = await pumpMap(
        tester,
        width: 4000,
        height: 3000,
        markers: [...close, lone],
      );
      final before = camera().zoom;
      await tester.tap(find.byType(MarkerClusterBadge));
      await tester.pumpAndSettle();
      expect(camera().zoom, greaterThan(before + 1));
      expect(find.text('Wyzima'), findsOneWidget);
      expect(find.text('Novigrad'), findsOneWidget);
    });

    testWidgets('shows every marker at full resolution', (tester) async {
      final camera = await pumpMap(
        tester,
        width: 4000,
        height: 3000,
        markers: [
          ...close,
          // Exactly on top of Wyzima: only separable by not clustering.
          testMarker('5', 'Wyzima 2', color: 0xFFE53935, x: 0.50, y: 0.50),
        ],
      );
      final native = MapCoordinateMapper(
        widthPx: 4000,
        heightPx: 3000,
      ).nativeZoom;
      MapController.of(tester.element(find.byType(MarkerLayer)))
          .move(camera().center, native);
      await tester.pump();
      expect(find.byType(MarkerClusterBadge), findsNothing);
      expect(find.byType(MarkerPin), findsNWidgets(4));
    });
  });
}
