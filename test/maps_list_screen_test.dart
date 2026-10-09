import 'package:custom_map_marker/data/map_project.dart';
import 'package:custom_map_marker/data/image_file_picker.dart';
import 'package:custom_map_marker/data/providers.dart';
import 'package:custom_map_marker/features/maps_list/maps_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:custom_map_marker/core/map_archive.dart';
import 'package:custom_map_marker/data/map_transfer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

MapSummary _summary(String id, String name, int markers) => MapSummary(
  map: testMap(id, name: name),
  markerCount: markers,
);

void main() {
  late FakeMapRepository repo;
  MapArchiveException? transferError;

  setUp(() => repo = FakeMapRepository());

  Future<void> pumpList(
    WidgetTester tester,
    List<MapSummary> maps, {
    PickedImage? picked,
    String? anyFile,
  }) => tester
      .pumpWidget(
        ProviderScope(
          overrides: [
            mapsProvider.overrideWith((ref) => Stream.value(maps)),
            mapRepositoryProvider.overrideWithValue(repo),
            imageFilePickerProvider.overrideWithValue(
              FakeImageFilePicker(picked, anyFile: anyFile),
            ),
            mapTransferProvider.overrideWithValue(
              _FailingTransfer(() => transferError),
            ),
            // Import opens the map screen, which watches markers.
            markersProvider.overrideWith((ref, id) => Stream.value(const [])),
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

  group('import', () {
    testWidgets('asks for a name, suggesting a date for numeric file names', (
      tester,
    ) async {
      await pumpList(
        tester,
        const [],
        picked: (path: '/cache/1000021497.jpg', name: '1000021497.jpg'),
      );
      await tester.tap(find.text('Importuj mapę'));
      await _settle(tester);
      await tester.tap(find.text('Obraz'));
      await _settle(tester);

      expect(find.text('Nowa mapa'), findsOneWidget);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, startsWith('Mapa z '));

      await tester.enterText(find.byType(TextFormField), 'Kontynent');
      await tester.tap(find.widgetWithText(FilledButton, 'Importuj'));
      await _settle(tester);
      expect(repo.imported, [('/cache/1000021497.jpg', 'Kontynent')]);
    });

    testWidgets('keeps a meaningful file name and can be cancelled', (
      tester,
    ) async {
      await pumpList(
        tester,
        const [],
        picked: (path: '/cache/x.jpg', name: 'Swiat_Wiedzmina.jpg'),
      );
      await tester.tap(find.text('Importuj mapę'));
      await _settle(tester);
      await tester.tap(find.text('Obraz'));
      await _settle(tester);
      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, 'Swiat_Wiedzmina');

      await tester.tap(find.text('Anuluj'));
      await _settle(tester);
      expect(repo.imported, isEmpty);
    });
  });

  group('enable tiling', () {
    testWidgets('is offered only for maps that need it', (tester) async {
      repo.tileable.add('big');
      await pumpList(tester, [_summary('big', 'Duża', 0)]);
      await tester.tap(find.byTooltip('Opcje mapy'));
      await tester.pumpAndSettle();
      expect(find.text('Popraw jakość (kafelki)'), findsOneWidget);

      await tester.tap(find.text('Popraw jakość (kafelki)'));
      await tester.pumpAndSettle();
      expect(repo.tiled, ['big']);
      expect(
        find.text('Mapa „Duża” korzysta teraz z kafelków'),
        findsOneWidget,
      );
    });

    testWidgets('is hidden for other maps', (tester) async {
      await pumpList(tester, [_summary('small', 'Mała', 0)]);
      await tester.tap(find.byTooltip('Opcje mapy'));
      await tester.pumpAndSettle();
      expect(find.text('Popraw jakość (kafelki)'), findsNothing);
    });
  });

  testWidgets('offers export in the map menu', (tester) async {
    await pumpList(tester, [_summary('a', 'Temeria', 0)]);
    await tester.tap(find.byTooltip('Opcje mapy'));
    await tester.pumpAndSettle();
    expect(find.text('Eksportuj'), findsOneWidget);
  });

  testWidgets('explains why a map file cannot be imported', (tester) async {
    await pumpList(tester, const [], anyFile: '/x.cmm');
    for (final (error, message) in [
      (MapArchiveError.notAMapFile, 'To nie jest plik mapy (.cmm).'),
      (
        MapArchiveError.newerVersion,
        'Ten plik pochodzi z nowszej wersji aplikacji. Zaktualizuj ją.',
      ),
      (MapArchiveError.damaged, 'Plik mapy jest uszkodzony.'),
    ]) {
      transferError = MapArchiveException(error);
      await tester.tap(find.text('Importuj mapę'));
      await _settle(tester);
      await tester.tap(find.text('Plik mapy (.cmm)'));
      await _settle(tester);
      expect(find.text(message), findsOneWidget);
      ScaffoldMessenger.of(tester.element(find.byType(MapsListScreen)))
          .removeCurrentSnackBar();
      await _settle(tester);
    }
  });
}

/// Like pumpAndSettle, but tolerates the import button's endless spinner.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _FailingTransfer implements MapTransfer {
  _FailingTransfer(this.error);

  final MapArchiveException? Function() error;

  @override
  Future<MapProject> import(
    String path, {
    void Function(double progress)? onProgress,
  }) async => throw error()!;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
