import 'dart:io';

import 'package:custom_map_marker/core/tile_generator.dart';
import 'package:custom_map_marker/features/map_view/map_snapshot.dart';
import 'package:custom_map_marker/features/map_view/snapshot_options_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'fakes.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('snapshot'));
  tearDown(() => dir.deleteSync(recursive: true));

  /// Left half red, right half blue.
  String writeMap(int width, int height) {
    final image = img.Image(width: width, height: height);
    for (final px in image) {
      final left = px.x < width / 2;
      px
        ..r = left ? 255 : 0
        ..g = 0
        ..b = left ? 0 : 255;
    }
    final path = p.join(dir.path, 'map.png');
    File(path).writeAsBytesSync(img.encodePng(image));
    return path;
  }

  img.Image decode(List<int> png) => img.decodePng(png as dynamic)!;

  bool isRed(img.Pixel px) => px.r > 200 && px.b < 60;
  bool isBlue(img.Pixel px) => px.b > 200 && px.r < 60;

  testWidgets('renders the whole map with markers', (tester) async {
    await tester.runAsync(() async {
      final path = writeMap(400, 300);
      final project = testMap('m', width: 400, height: 300).withImage(path);
      final withMarker = decode(
        await renderMapSnapshot(
          project: project,
          markers: [testMarker('1', 'Tu', color: 0xFF43A047, x: 0.25, y: 0.5)],
        ),
      );
      final bare = decode(
        await renderMapSnapshot(project: project, markers: const []),
      );
      expect((withMarker.width, withMarker.height), (400, 300));
      expect(isRed(bare.getPixel(20, 280)), isTrue);
      expect(isBlue(bare.getPixel(380, 280)), isTrue);

      // The marker (tip at 100, 150) changes pixels just above its tip and
      // nowhere else. (Tests have no icon font, so its exact shape differs.)
      var near = 0;
      var far = 0;
      for (final px in withMarker) {
        final other = bare.getPixel(px.x, px.y);
        if (px.r == other.r && px.g == other.g && px.b == other.b) continue;
        final inBox = (px.x - 100).abs() < 60 && px.y > 80 && px.y <= 160;
        inBox ? near++ : far++;
      }
      expect(near, greaterThan(100));
      expect(far, 0);
    });
  });

  testWidgets('scales down to the maximum side', (tester) async {
    await tester.runAsync(() async {
      final path = writeMap(400, 300);
      final png = await renderMapSnapshot(
        project: testMap('m', width: 400, height: 300).withImage(path),
        markers: const [],
        maxSide: 200,
      );
      final out = decode(png);
      expect((out.width, out.height), (200, 150));
    });
  });

  testWidgets('renders only the requested region', (tester) async {
    await tester.runAsync(() async {
      final path = writeMap(400, 300);
      final png = await renderMapSnapshot(
        project: testMap('m', width: 400, height: 300).withImage(path),
        markers: const [],
        region: const Rect.fromLTWH(0.5, 0, 0.5, 1),
      );
      final out = decode(png);
      expect((out.width, out.height), (200, 300));
      expect(isBlue(out.getPixel(10, 150)), isTrue);
    });
  });

  testWidgets('composes tiled maps from a pyramid level', (tester) async {
    await tester.runAsync(() async {
      final path = writeMap(600, 300);
      final maxZoom = generateTiles(path, p.join(dir.path, 'tiles'), (_) {});
      final png = await renderMapSnapshot(
        project: testMap(
          'm',
          width: 600,
          height: 300,
          tileMaxZoom: maxZoom,
        ).withImage(path),
        markers: const [],
        maxSide: 150,
      );
      final out = decode(png);
      expect((out.width, out.height), (150, 75));
      expect(isRed(out.getPixel(10, 40)), isTrue);
      expect(isBlue(out.getPixel(140, 40)), isTrue);
    });
  });

  testWidgets('fails clearly when a tile is missing and cannot be rendered', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final path = writeMap(600, 300);
      await expectLater(
        renderMapSnapshot(
          project: testMap(
            'm',
            width: 600,
            height: 300,
            tileMaxZoom: 2,
          ).withImage(path),
          markers: const [],
        ),
        throwsStateError,
      );
    });
  });

  group('options dialog', () {
    Future<SnapshotOptions? Function()> open(
      WidgetTester tester, {
      required bool filterActive,
    }) async {
      SnapshotOptions? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showSnapshotOptionsDialog(
                context,
                filterActive: filterActive,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return () => result;
    }

    testWidgets('defaults to the whole map', (tester) async {
      final result = await open(tester, filterActive: false);
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();
      expect(result(), (area: SnapshotArea.wholeMap, skipHidden: false));
    });

    testWidgets('offers the visible part and skipping hidden markers', (
      tester,
    ) async {
      final result = await open(tester, filterActive: true);
      await tester.tap(find.text('Widoczny fragment'));
      await tester.tap(find.text('Pomiń znaczniki ukryte filtrem'));
      await tester.pump();
      await tester.tap(find.text('Zapisz'));
      await tester.pumpAndSettle();
      expect(result(), (area: SnapshotArea.visible, skipHidden: false));
    });
  });
}
