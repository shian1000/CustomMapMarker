import 'package:custom_map_marker/data/legend.dart';
import 'package:custom_map_marker/data/map_shape.dart';
import 'package:custom_map_marker/data/providers.dart';
import 'package:custom_map_marker/features/legend/legend_sheet.dart';
import 'package:custom_map_marker/shared/marker_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

final red = markerColors[0].toARGB32();
final green = markerColors[3].toARGB32();
final brown = markerColors[9].toARGB32();

void main() {
  late FakeLegendRepository repo;

  setUp(() => repo = FakeLegendRepository());

  Future<void> pumpSheet(WidgetTester tester, MapLegend legend) async {
    // Tall enough for all twelve colors: the list only builds visible rows.
    tester.view.physicalSize = const Size(1080, 4400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          legendProvider.overrideWith((ref, id) => Stream.value(legend)),
          markersProvider.overrideWith(
            (ref, id) => Stream.value([
              testMarker('1', 'Wyzima', color: red),
              testMarker('2', 'Novigrad', color: red),
              testMarker('3', 'Las', color: green),
            ]),
          ),
          shapesProvider.overrideWith(
            (ref, id) => Stream.value([
              testShape('r', ShapeKind.route, const [
                Offset.zero,
                Offset(1, 1),
              ], color: red),
              // Brown is used only by an area.
              testShape('a', ShapeKind.area, const [
                Offset.zero,
                Offset(1, 0),
                Offset(1, 1),
              ], color: brown),
            ]),
          ),
          legendRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LegendSheet(mapId: 'map')),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder row(String title) => find.widgetWithText(ListTile, title);

  testWidgets('lists palette colors with names and marker counts', (
    tester,
  ) async {
    await pumpSheet(tester, {red: const LegendEntry(name: 'Miasta')});
    expect(
      find.descendant(
        of: row('Miasta'),
        matching: find.text('2 znaczniki · 1 trasa'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 obszar'), findsOneWidget);
    expect(find.text('Nieużywany'), findsWidgets);
    expect(find.text('1 znacznik'), findsOneWidget);
    expect(find.text('Bez nazwy'), findsWidgets);
  });

  testWidgets('switches hide and show a color', (tester) async {
    await pumpSheet(tester, {red: const LegendEntry(name: 'Miasta')});
    await tester.tap(
      find.descendant(of: row('Miasta'), matching: find.byType(Switch)),
    );
    await tester.pump();
    expect(repo.hidden, [('map', red, true)]);
  });

  testWidgets('unused colors cannot be toggled', (tester) async {
    await pumpSheet(tester, const {});
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    // Red and green by markers, brown by an area; nine palette colors are
    // unused.
    expect(switches.where((s) => s.onChanged != null), hasLength(3));
  });

  testWidgets('"Żadne" hides only the colors in use', (tester) async {
    await pumpSheet(tester, const {});
    await tester.tap(find.text('Żadne'));
    await tester.pump();
    expect(repo.hidden.toSet(), {
      ('map', red, true),
      ('map', green, true),
      ('map', brown, true),
    });
  });

  testWidgets('tapping a color names it', (tester) async {
    await pumpSheet(tester, {red: const LegendEntry(name: 'Miasta')});
    await tester.tap(row('Miasta'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Grody');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(repo.names, [('map', red, 'Grody')]);
  });
}
