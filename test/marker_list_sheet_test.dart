import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/data/map_shape.dart';
import 'package:custom_map_marker/features/marker_list/marker_list_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

MapMarker _marker(
  String id,
  String label, {
  String? description,
  required int day,
}) => MapMarker(
  id: id,
  mapId: 'map',
  x: 0.5,
  y: 0.5,
  label: label,
  description: description,
  colorValue: 0xFFE53935,
  createdAt: DateTime(2026, 10, day),
);

final _markers = [
  _marker('a', 'Wyzima', description: 'Stolica Temerii', day: 4),
  _marker('b', 'Ćwierć', day: 3),
  _marker('c', 'Novigrad', description: 'Wolne miasto', day: 2),
];

final _shapes = [
  testShape('r1', ShapeKind.route, const [
    Offset.zero,
    Offset(1, 1),
  ], name: 'Szlak do Wyzimy'),
  testShape('r2', ShapeKind.route, const [Offset.zero, Offset(1, 1)]),
  testShape('a1', ShapeKind.area, const [
    Offset.zero,
    Offset(1, 0),
    Offset(1, 1),
  ], name: 'Temeria'),
];

void main() {
  Future<MapListPick? Function()> openList(
    WidgetTester tester, {
    List<MapMarker> markers = const [],
    List<MapShape> shapes = const [],
    HiddenCounts hidden = (markers: 0, routes: 0, areas: 0),
    Set<ShapeKind> kindsOff = const {},
  }) async {
    MapListPick? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked = await showMapList(
              context,
              markers: markers,
              shapes: shapes,
              hidden: hidden,
              kindsOff: kindsOff,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => picked;
  }

  List<String> shownTitles(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      (tile.title! as Text).data!,
  ];

  Future<void> openTab(WidgetTester tester, String prefix) async {
    await tester.tap(find.textContaining(prefix));
    await tester.pumpAndSettle();
  }

  testWidgets('sorts markers alphabetically, ignoring diacritics', (
    tester,
  ) async {
    await openList(tester, markers: _markers);
    expect(shownTitles(tester), ['Ćwierć', 'Novigrad', 'Wyzima']);
    expect(find.text('3 z 3'), findsOneWidget);
  });

  testWidgets('sorts by newest', (tester) async {
    await openList(tester, markers: _markers);
    await tester.tap(find.text('Najnowsze'));
    await tester.pumpAndSettle();
    // Created on: Wyzima 4th, Ćwierć 3rd, Novigrad 2nd.
    expect(shownTitles(tester), ['Wyzima', 'Ćwierć', 'Novigrad']);
  });

  testWidgets('filters markers by name and description', (tester) async {
    await openList(tester, markers: _markers);
    await tester.enterText(find.byType(TextField), 'temerii');
    await tester.pump();
    expect(shownTitles(tester), ['Wyzima']);
    expect(find.text('1 z 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'smok');
    await tester.pump();
    expect(find.text('Nic nie znaleziono'), findsOneWidget);

    await tester.tap(find.byTooltip('Wyczyść'));
    await tester.pump();
    expect(shownTitles(tester), hasLength(3));
  });

  testWidgets('shows counts per tab and searches all of them', (tester) async {
    await openList(tester, markers: _markers, shapes: _shapes);
    expect(find.text('Znaczniki (3)'), findsOneWidget);
    expect(find.text('Trasy (2)'), findsOneWidget);
    expect(find.text('Obszary (1)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wyzim');
    await tester.pump();
    expect(find.text('Znaczniki (1)'), findsOneWidget);
    expect(find.text('Trasy (1)'), findsOneWidget);
    expect(find.text('Obszary (0)'), findsOneWidget);
  });

  testWidgets('lists unnamed routes after named ones', (tester) async {
    await openList(tester, shapes: _shapes);
    await openTab(tester, 'Trasy');
    expect(shownTitles(tester), ['Szlak do Wyzimy', 'Trasa bez nazwy']);
  });

  testWidgets('returns the picked marker or shape', (tester) async {
    var picked = await openList(tester, markers: _markers, shapes: _shapes);
    await tester.tap(find.text('Novigrad'));
    await tester.pumpAndSettle();
    expect((picked()! as MarkerPick).marker.id, 'c');

    picked = await openList(tester, markers: _markers, shapes: _shapes);
    await openTab(tester, 'Obszary');
    await tester.tap(find.text('Temeria'));
    await tester.pumpAndSettle();
    expect((picked()! as ShapePick).shape.id, 'a1');
  });

  testWidgets('explains empty tabs', (tester) async {
    await openList(tester, hidden: (markers: 0, routes: 2, areas: 0));
    expect(find.textContaining('nie ma jeszcze znaczników'), findsOneWidget);
    await openTab(tester, 'Trasy');
    expect(find.textContaining('Wszystko jest ukryte filtrem'), findsOneWidget);
    expect(find.text('0 z 0 · 2 ukryte filtrem'), findsOneWidget);
    await openTab(tester, 'Obszary');
    expect(find.textContaining('nie ma jeszcze obszarów'), findsOneWidget);
  });

  testWidgets('says when a kind is turned off in the settings', (tester) async {
    await openList(tester, kindsOff: {ShapeKind.route});
    await openTab(tester, 'Trasy');
    expect(find.text('Trasy są wyłączone w ustawieniach.'), findsOneWidget);
  });
}
