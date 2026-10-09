import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/features/marker_list/marker_list_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  Future<MapMarker? Function()> openList(
    WidgetTester tester,
    List<MapMarker> markers,
  ) async {
    MapMarker? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                picked = await showMarkerList(context, markers),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => picked;
  }

  List<String> shownLabels(WidgetTester tester) => [
    for (final tile in tester.widgetList<ListTile>(find.byType(ListTile)))
      (tile.title! as Text).data!,
  ];

  testWidgets('sorts alphabetically, ignoring diacritics', (tester) async {
    await openList(tester, _markers);
    expect(shownLabels(tester), ['Ćwierć', 'Novigrad', 'Wyzima']);
    expect(find.text('3 z 3'), findsOneWidget);
  });

  testWidgets('sorts by newest', (tester) async {
    await openList(tester, _markers);
    await tester.tap(find.text('Najnowsze'));
    await tester.pumpAndSettle();
    // Created on: Wyzima 4th, Ćwierć 3rd, Novigrad 2nd.
    expect(shownLabels(tester), ['Wyzima', 'Ćwierć', 'Novigrad']);
  });

  testWidgets('filters by name and description', (tester) async {
    await openList(tester, _markers);
    await tester.enterText(find.byType(TextField), 'temerii');
    await tester.pump();
    expect(shownLabels(tester), ['Wyzima']);
    expect(find.text('1 z 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cwierc');
    await tester.pump();
    expect(shownLabels(tester), ['Ćwierć']);

    await tester.enterText(find.byType(TextField), 'smok');
    await tester.pump();
    expect(find.text('Nic nie znaleziono'), findsOneWidget);

    await tester.tap(find.byTooltip('Wyczyść'));
    await tester.pump();
    expect(shownLabels(tester), hasLength(3));
  });

  testWidgets('explains how to add markers when there are none', (
    tester,
  ) async {
    await openList(tester, const []);
    expect(find.textContaining('nie ma jeszcze znaczników'), findsOneWidget);
  });

  testWidgets('returns the tapped marker', (tester) async {
    final picked = await openList(tester, _markers);
    await tester.tap(find.text('Novigrad'));
    await tester.pumpAndSettle();
    expect(picked()?.id, 'c');
  });
}
