import 'package:custom_map_marker/core/coordinate_mapper.dart';
import 'package:custom_map_marker/data/legend.dart';
import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/map_shape.dart';
import 'package:custom_map_marker/data/settings.dart';
import 'package:custom_map_marker/data/providers.dart';
import 'package:custom_map_marker/features/map_view/clustered_marker_layer.dart';
import 'package:custom_map_marker/features/map_view/map_view_screen.dart';
import 'package:custom_map_marker/features/scale/scale_bar.dart';
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
  late FakeShapeRepository shapeRepo;

  setUp(() {
    shapeRepo = FakeShapeRepository();
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
    List<MapShape> shapes = const [],
    AppSettings settings = const AppSettings(),
    double? metersPerPixel,
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
      metersPerPixel: metersPerPixel,
    );
    repo = FakeMapRepository([MapSummary(map: project, markerCount: 0)]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          markersProvider.overrideWith((ref, mapId) => Stream.value(markers)),
          legendProvider.overrideWith((ref, mapId) => Stream.value(legend)),
          legendRepositoryProvider.overrideWithValue(legendRepo),
          markerRepositoryProvider.overrideWithValue(markerRepo),
          shapesProvider.overrideWith((ref, mapId) => Stream.value(shapes)),
          shapeRepositoryProvider.overrideWithValue(shapeRepo),
          settingsStoreProvider.overrideWithValue(
            MemorySettingsStore()
              ..setBool('snapToMarkers', settings.snapToMarkers)
              ..setBool('showRouteNames', settings.showRouteNames)
              ..setBool('showAreaNames', settings.showAreaNames)
              ..setBool('showRoutes', settings.showRoutes)
              ..setBool('showAreas', settings.showAreas),
          ),
          mapRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(home: MapViewScreen(project: project)),
      ),
    );
    await tester.pump();
    return () =>
        MapCamera.of(tester.element(find.byType(ClusteredMarkerLayer)));
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

    await tester.tap(find.byTooltip('Więcej'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zmień nazwę'));
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

    await tester.tap(find.byTooltip('Lista'));
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

      await tester.tap(find.byTooltip('Lista'));
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
      MapController.of(tester.element(find.byType(ClusteredMarkerLayer)))
          .move(camera().center, native);
      await tester.pump();
      expect(find.byType(MarkerClusterBadge), findsNothing);
      expect(find.byType(MarkerPin), findsNWidgets(4));
    });
  });

  group('routes and areas', () {
    /// flutter_map waits to tell a tap from a double tap (which zooms), so a
    /// tap only lands after that window.
    Future<void> tapMap(WidgetTester tester, Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> startDrawing(WidgetTester tester, String kind) async {
      await tester.tap(find.byTooltip('Rysuj'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kind));
      await tester.pumpAndSettle();
    }

    Offset mapPoint(WidgetTester tester, Offset normalized) {
      final camera = MapCamera.of(
        tester.element(find.byType(ClusteredMarkerLayer)),
      );
      final latLng = MapCoordinateMapper(
        widthPx: 1000,
        heightPx: 800,
      ).toLatLng(normalized);
      return tester.getTopLeft(find.byType(FlutterMap)) +
          camera.latLngToScreenOffset(latLng);
    }

    testWidgets('draws a route point by point and saves it', (tester) async {
      await pumpMap(tester, width: 1000, height: 800);
      await startDrawing(tester, 'Trasa');
      expect(find.textContaining('min. 2'), findsOneWidget);
      final done = find.widgetWithText(FilledButton, 'Gotowe');
      expect(tester.widget<FilledButton>(done).onPressed, isNull);

      await tapMap(tester, mapPoint(tester, const Offset(0.2, 0.3)));
      await tapMap(tester, mapPoint(tester, const Offset(0.6, 0.7)));
      await tapMap(tester, mapPoint(tester, const Offset(0.8, 0.2)));
      expect(find.text('Trasa: 3 punkty'), findsOneWidget);

      await tester.tap(find.byTooltip('Cofnij punkt'));
      await tester.pump();
      expect(find.text('Trasa: 2 punkty'), findsOneWidget);

      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(find.text('Nowa trasa'), findsOneWidget);
      // Routes have no fill opacity choice.
      expect(find.text('Wypełnienie'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Nazwa (opcjonalnie)'),
        'Szlak',
      );
      await tester.tap(find.text('Przerywana'));
      await tester.ensureVisible(find.text('Zapisz'));
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      final (mapId, kind, points, style) = shapeRepo.added.single;
      expect((mapId, kind), ('map', ShapeKind.route));
      expect(points, hasLength(2));
      expect(points[0].dx, closeTo(0.2, 0.01));
      expect(points[1].dy, closeTo(0.7, 0.01));
      expect((style.name, style.dashed), ('Szlak', true));
      // Back to normal: the banner is gone.
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('an area needs three points', (tester) async {
      await pumpMap(tester, width: 1000, height: 800);
      await startDrawing(tester, 'Obszar');
      for (final p in const [Offset(0.2, 0.2), Offset(0.5, 0.2)]) {
        await tapMap(tester, mapPoint(tester, p));
      }
      final done = find.widgetWithText(FilledButton, 'Gotowe');
      expect(tester.widget<FilledButton>(done).onPressed, isNull);
      await tapMap(tester, mapPoint(tester, const Offset(0.4, 0.6)));
      expect(tester.widget<FilledButton>(done).onPressed, isNotNull);

      await tester.tap(done);
      await tester.pumpAndSettle();
      expect(find.text('Nowy obszar'), findsOneWidget);
      expect(find.text('Wypełnienie'), findsOneWidget);
    });

    testWidgets('cancelling drops the points', (tester) async {
      await pumpMap(tester, width: 1000, height: 800);
      await startDrawing(tester, 'Trasa');
      await tapMap(tester, mapPoint(tester, const Offset(0.2, 0.3)));
      await tester.tap(find.byTooltip('Anuluj rysowanie'));
      await tester.pump();
      expect(find.byType(FilledButton), findsNothing);
      expect(shapeRepo.added, isEmpty);
    });

    for (final snap in [true, false]) {
      testWidgets('snapping to markers ${snap ? 'on' : 'off'}', (tester) async {
        await pumpMap(
          tester,
          width: 1000,
          height: 800,
          markers: [
            testMarker('m', 'Wyzima', color: 0xFFE53935, x: 0.5, y: 0.5),
          ],
          settings: AppSettings(snapToMarkers: snap),
        );
        await startDrawing(tester, 'Trasa');
        // A few pixels beside the marker's tip (not on its pin).
        await tapMap(
          tester,
          mapPoint(tester, const Offset(0.5, 0.5)) + const Offset(12, 8),
        );
        await tapMap(tester, mapPoint(tester, const Offset(0.1, 0.1)));
        await tester.tap(find.widgetWithText(FilledButton, 'Gotowe'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Zapisz'));
        await tester.tap(find.text('Zapisz'));
        await tester.pumpAndSettle();

        final first = shapeRepo.added.single.$3.first;
        if (snap) {
          expect(first, const Offset(0.5, 0.5));
        } else {
          expect(first, isNot(const Offset(0.5, 0.5)));
        }
      });
    }

    testWidgets('shows routes and areas with names per settings', (
      tester,
    ) async {
      final shapes = [
        testShape('a', ShapeKind.area, const [
          Offset(0.1, 0.1),
          Offset(0.4, 0.1),
          Offset(0.3, 0.4),
        ], name: 'Temeria'),
        testShape('r', ShapeKind.route, const [
          Offset(0.5, 0.5),
          Offset(0.9, 0.9),
        ], name: 'Szlak'),
      ];
      await pumpMap(tester, width: 1000, height: 800, shapes: shapes);
      expect(find.byType(PolygonLayer<String>), findsOneWidget);
      expect(find.byType(PolylineLayer<String>), findsOneWidget);
      expect(find.text('Szlak'), findsOneWidget);
      final polygon = tester
          .widget<PolygonLayer<String>>(find.byType(PolygonLayer<String>))
          .polygons
          .single;
      expect(polygon.label, 'Temeria');

      await pumpMap(
        tester,
        width: 1000,
        height: 800,
        shapes: shapes,
        settings: const AppSettings(
          showRouteNames: false,
          showAreaNames: false,
        ),
      );
      expect(find.text('Szlak'), findsNothing);
      expect(
        tester
            .widget<PolygonLayer<String>>(find.byType(PolygonLayer<String>))
            .polygons
            .single
            .label,
        isNull,
      );
    });
  });

  group('editing routes and areas', () {
    Future<void> tapMap(WidgetTester tester, Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Offset screenOf(WidgetTester tester, Offset normalized) {
      final camera = MapCamera.of(
        tester.element(find.byType(ClusteredMarkerLayer)),
      );
      final latLng = MapCoordinateMapper(
        widthPx: 1000,
        heightPx: 800,
      ).toLatLng(normalized);
      return tester.getTopLeft(find.byType(FlutterMap)) +
          camera.latLngToScreenOffset(latLng);
    }

    final route = testShape('r', ShapeKind.route, const [
      Offset(0.2, 0.5),
      Offset(0.8, 0.5),
    ], name: 'Szlak');
    final area = testShape('a', ShapeKind.area, const [
      Offset(0.2, 0.2),
      Offset(0.6, 0.2),
      Offset(0.6, 0.6),
      Offset(0.2, 0.6),
    ], name: 'Temeria');

    Future<void> openDetails(WidgetTester tester, Offset on) async {
      await tapMap(tester, screenOf(tester, on));
      await tester.pumpAndSettle();
    }

    testWidgets('tapping a route opens it; delete can be undone', (
      tester,
    ) async {
      await pumpMap(tester, width: 1000, height: 800, shapes: [route]);
      await openDetails(tester, const Offset(0.5, 0.5));
      expect(find.text('Trasa · 2 punkty'), findsOneWidget);

      await tester.tap(find.text('Usuń'));
      await tester.pumpAndSettle();
      expect(shapeRepo.removed, ['r']);
      expect(find.text('Usunięto trasę „Szlak”'), findsOneWidget);
      await tester.tap(find.text('Cofnij'));
      await tester.pump();
      expect(shapeRepo.restored, ['r']);
    });

    testWidgets('edits the look of an area', (tester) async {
      await pumpMap(tester, width: 1000, height: 800, shapes: [area]);
      await openDetails(tester, const Offset(0.4, 0.4));
      expect(find.text('Obszar · 4 punkty'), findsOneWidget);
      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();
      expect(find.text('Edytuj obszar'), findsOneWidget);
      await tester.tap(find.text('45%'));
      await tester.ensureVisible(find.text('Zapisz'));
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();
      final (id, style) = shapeRepo.styled.single;
      expect((id, style.name, style.fillOpacity), ('a', 'Temeria', 0.45));
    });

    Future<void> editPoints(WidgetTester tester, Offset on) async {
      await openDetails(tester, on);
      await tester.tap(find.text('Zmień punkty'));
      await tester.pumpAndSettle();
    }

    testWidgets('drags a point and saves', (tester) async {
      await pumpMap(tester, width: 1000, height: 800, shapes: [route]);
      await editPoints(tester, const Offset(0.5, 0.5));
      final camera = MapCamera.of(
        tester.element(find.byType(ClusteredMarkerLayer)),
      );
      final centerBefore = camera.center;
      final from = screenOf(tester, const Offset(0.8, 0.5));
      final to = screenOf(tester, const Offset(0.8, 0.2));
      // Many small moves, like a real finger: the map's own drag
      // recognizers get every chance to steal the gesture.
      await tester.timedDragFrom(
        from,
        to - from,
        const Duration(milliseconds: 600),
      );
      await tester.pump();
      expect(
        MapCamera.of(tester.element(find.byType(ClusteredMarkerLayer))).center,
        centerBefore,
        reason: 'dragging a point must not pan the map',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Gotowe'));
      await tester.pumpAndSettle();

      final (id, points) = shapeRepo.repointed.single;
      expect(id, 'r');
      expect(points[0], const Offset(0.2, 0.5));
      expect(points[1].dx, closeTo(0.8, 0.02));
      expect(points[1].dy, closeTo(0.2, 0.02));
    });

    testWidgets('tapping a segment middle inserts a point', (tester) async {
      await pumpMap(tester, width: 1000, height: 800, shapes: [route]);
      await editPoints(tester, const Offset(0.4, 0.5));
      await tester.tapAt(screenOf(tester, const Offset(0.5, 0.5)));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Gotowe'));
      await tester.pumpAndSettle();
      final points = shapeRepo.repointed.single.$2;
      expect(points, hasLength(3));
      expect(points[1].dx, closeTo(0.5, 0.01));
    });

    testWidgets('deletes a selected point but keeps the minimum', (
      tester,
    ) async {
      await pumpMap(tester, width: 1000, height: 800, shapes: [area]);
      await editPoints(tester, const Offset(0.4, 0.4));
      IconButton deleteButton() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.delete_outline),
      );
      expect(deleteButton().onPressed, isNull);

      await tester.tapAt(screenOf(tester, const Offset(0.6, 0.6)));
      await tester.pump();
      expect(deleteButton().onPressed, isNotNull);
      await tester.tap(find.byTooltip('Usuń punkt'));
      await tester.pump();

      // Down to three: an area can't lose another one.
      await tester.tapAt(screenOf(tester, const Offset(0.2, 0.2)));
      await tester.pump();
      expect(deleteButton().onPressed, isNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Gotowe'));
      await tester.pumpAndSettle();
      final saved = shapeRepo.repointed.single.$2;
      expect(saved, hasLength(3));
      expect(saved[0].dx, closeTo(0.2, 1e-9));
      expect(saved[1].dx, closeTo(0.6, 1e-9));
      expect(saved[2].dy, closeTo(0.6, 1e-9));
      expect(saved[2].dx, closeTo(0.2, 1e-9));
    });

    testWidgets('cancelling discards the changes', (tester) async {
      await pumpMap(tester, width: 1000, height: 800, shapes: [route]);
      await editPoints(tester, const Offset(0.5, 0.5));
      await tester.tapAt(screenOf(tester, const Offset(0.5, 0.5)));
      await tester.pump();
      await tester.tap(find.byTooltip('Anuluj zmiany'));
      await tester.pump();
      expect(shapeRepo.repointed, isEmpty);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('while drawing, taps inside an area add points', (
      tester,
    ) async {
      await pumpMap(tester, width: 1000, height: 800, shapes: [area]);
      await tester.tap(find.byTooltip('Rysuj'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Trasa'));
      await tester.pumpAndSettle();
      await tapMap(tester, screenOf(tester, const Offset(0.3, 0.3)));
      await tapMap(tester, screenOf(tester, const Offset(0.5, 0.5)));
      expect(find.text('Trasa: 2 punkty'), findsOneWidget);
      expect(find.text('Zmień punkty'), findsNothing);
    });
  });

  group('routes and areas with filters and the list', () {
    final route = testShape(
      'r',
      ShapeKind.route,
      const [Offset(0.1, 0.1), Offset(0.3, 0.2)],
      name: 'Szlak',
      color: 0xFFE53935,
    );
    final area = testShape(
      'a',
      ShapeKind.area,
      const [Offset(0.6, 0.6), Offset(0.9, 0.6), Offset(0.8, 0.9)],
      name: 'Temeria',
      color: 0xFF1E88E5,
    );

    testWidgets('the legend filter hides shapes of hidden colors', (
      tester,
    ) async {
      await pumpMap(
        tester,
        width: 1000,
        height: 800,
        shapes: [route, area],
        legend: {0xFFE53935: const LegendEntry(hidden: true)},
      );
      expect(find.byType(PolylineLayer<String>), findsNothing);
      expect(find.byType(PolygonLayer<String>), findsOneWidget);
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isTrue);
    });

    testWidgets('settings can turn routes or areas off everywhere', (
      tester,
    ) async {
      await pumpMap(
        tester,
        width: 1000,
        height: 800,
        shapes: [route, area],
        settings: const AppSettings(showAreas: false),
      );
      expect(find.byType(PolylineLayer<String>), findsOneWidget);
      expect(find.byType(PolygonLayer<String>), findsNothing);
      // Not a filter: no flag on the legend button.
      expect(tester.widget<Badge>(find.byType(Badge)).isLabelVisible, isFalse);
    });

    testWidgets('picking an area in the list fits it into view', (
      tester,
    ) async {
      final camera = await pumpMap(
        tester,
        width: 1000,
        height: 800,
        shapes: [route, area],
      );
      final before = camera().zoom;
      await tester.tap(find.byTooltip('Lista'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Obszary'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Temeria'));
      await tester.pumpAndSettle();

      expect(camera().zoom, greaterThan(before));
      final mapper = MapCoordinateMapper(widthPx: 1000, heightPx: 800);
      for (final p in area.points) {
        expect(camera().visibleBounds.contains(mapper.toLatLng(p)), isTrue);
      }
    });
  });

  group('scale and measuring', () {
    Future<void> tapMap(WidgetTester tester, Offset at) async {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 400));
    }

    Offset screenOf(WidgetTester tester, Offset normalized) {
      final camera = MapCamera.of(
        tester.element(find.byType(ClusteredMarkerLayer)),
      );
      final latLng = MapCoordinateMapper(
        widthPx: 1000,
        heightPx: 800,
      ).toLatLng(normalized);
      return tester.getTopLeft(find.byType(FlutterMap)) +
          camera.latLngToScreenOffset(latLng);
    }

    testWidgets('calibrates the scale from two points', (tester) async {
      await pumpMap(tester, width: 1000, height: 800);
      expect(find.byType(ScaleBar), findsNothing);

      await tester.tap(find.byTooltip('Więcej'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ustaw skalę mapy'));
      await tester.pumpAndSettle();
      expect(find.textContaining('(0/2)'), findsOneWidget);

      // 500 px apart on a 1000 px wide image.
      await tapMap(tester, screenOf(tester, const Offset(0.25, 0.5)));
      await tapMap(tester, screenOf(tester, const Offset(0.75, 0.5)));
      await tester.pumpAndSettle();
      expect(find.text('Skala mapy'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '100');
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();

      final (id, metersPerPixel) = repo.scales.single;
      expect(id, 'map');
      expect(metersPerPixel, closeTo(100000 / 500, 0.5));
      expect(find.text('Skala zapisana'), findsOneWidget);
      expect(find.byType(ScaleBar), findsOneWidget);
    });

    testWidgets('measures a distance with the ruler', (tester) async {
      await pumpMap(tester, width: 1000, height: 800, metersPerPixel: 10);
      await tester.tap(find.byTooltip('Zmierz'));
      await tester.pump();
      await tapMap(tester, screenOf(tester, const Offset(0.1, 0.5)));
      await tapMap(tester, screenOf(tester, const Offset(0.6, 0.5)));
      // ~500 px × 10 m.
      expect(find.textContaining('Odległość: 5 km'), findsOneWidget);
      await tester.tap(find.byTooltip('Cofnij punkt'));
      await tester.pump();
      expect(find.text('Odległość: stuknij punkty na mapie'), findsOneWidget);
      await tester.tap(find.byTooltip('Zamknij'));
      await tester.pump();
      expect(find.textContaining('Odległość'), findsNothing);
    });

    testWidgets('shows a route length in its details', (tester) async {
      await pumpMap(
        tester,
        width: 1000,
        height: 800,
        metersPerPixel: 10,
        shapes: [
          testShape('r', ShapeKind.route, const [
            Offset(0.2, 0.5),
            Offset(0.8, 0.5),
          ]),
        ],
      );
      await tapMap(tester, screenOf(tester, const Offset(0.5, 0.5)));
      await tester.pumpAndSettle();
      expect(find.text('Długość: 6 km'), findsOneWidget);
    });
  });
}
