import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/map_repository.dart';
import 'package:custom_map_marker/data/providers.dart';
import 'package:custom_map_marker/features/maps_list/maps_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeMapRepository implements MapRepository {
  final renamed = <(String, String)>[];
  final deleted = <String>[];

  @override
  Future<void> rename(String id, String name) async => renamed.add((id, name));

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

MapSummary _summary(String id, String name, int markers) => MapSummary(
  map: MapProject(
    id: id,
    name: name,
    imagePath: '/nonexistent/$id.png',
    widthPx: 100,
    heightPx: 100,
    createdAt: DateTime(2026),
  ),
  markerCount: markers,
);

void main() {
  late _FakeMapRepository repo;

  setUp(() => repo = _FakeMapRepository());

  Future<void> pumpList(WidgetTester tester, List<MapSummary> maps) => tester
      .pumpWidget(
        ProviderScope(
          overrides: [
            mapsProvider.overrideWith((ref) => Stream.value(maps)),
            mapRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(home: MapsListScreen()),
        ),
      )
      .then((_) => tester.pumpAndSettle());

  Future<void> openMenuItem(WidgetTester tester, String item) async {
    await tester.tap(find.byTooltip('Opcje mapy').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  testWidgets('shows an empty state without maps', (tester) async {
    await pumpList(tester, const []);
    expect(find.text('Nie masz jeszcze map'), findsOneWidget);
  });

  testWidgets('shows map names and marker counts', (tester) async {
    await pumpList(tester, [
      _summary('a', 'Temeria', 3),
      _summary('b', 'Redania', 1),
    ]);
    expect(find.text('Temeria'), findsOneWidget);
    expect(find.text('3 znaczniki'), findsOneWidget);
    expect(find.text('1 znacznik'), findsOneWidget);
  });

  testWidgets('renames a map', (tester) async {
    await pumpList(tester, [_summary('a', 'Temeria', 0)]);
    await openMenuItem(tester, 'Zmień nazwę');
    await tester.enterText(find.byType(TextFormField), '  Nilfgaard ');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(repo.renamed, [('a', 'Nilfgaard')]);
  });

  testWidgets('rejects an empty name', (tester) async {
    await pumpList(tester, [_summary('a', 'Temeria', 0)]);
    await openMenuItem(tester, 'Zmień nazwę');
    await tester.enterText(find.byType(TextFormField), '   ');
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(find.text('Podaj nazwę'), findsOneWidget);
    expect(repo.renamed, isEmpty);
  });

  for (final (count, text) in [
    (0, 'Mapa „Temeria” zostanie usunięta. '),
    (1, 'Mapa „Temeria” zostanie usunięta razem z 1 znacznikiem. '),
  ]) {
    testWidgets('delete confirmation for $count markers', (tester) async {
      await pumpList(tester, [_summary('a', 'Temeria', count)]);
      await openMenuItem(tester, 'Usuń');
      expect(
        find.text('${text}Tej operacji nie można cofnąć.'),
        findsOneWidget,
      );
    });
  }

  testWidgets('deletes a map only after confirmation', (tester) async {
    await pumpList(tester, [_summary('a', 'Temeria', 5)]);

    await openMenuItem(tester, 'Usuń');
    expect(
      find.text(
        'Mapa „Temeria” zostanie usunięta razem z 5 znacznikami. '
        'Tej operacji nie można cofnąć.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Anuluj'));
    await tester.pumpAndSettle();
    expect(repo.deleted, isEmpty);

    await openMenuItem(tester, 'Usuń');
    await tester.tap(find.widgetWithText(FilledButton, 'Usuń'));
    await tester.pumpAndSettle();
    expect(repo.deleted, ['a']);
    expect(find.text('Usunięto mapę „Temeria”'), findsOneWidget);
  });
}
