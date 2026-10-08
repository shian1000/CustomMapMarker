import 'package:custom_map_marker/data/map_marker.dart';
import 'package:custom_map_marker/features/marker_editor/marker_editor_sheet.dart';
import 'package:custom_map_marker/shared/marker_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<MarkerDraft? Function()> openEditor(
    WidgetTester tester, {
    MarkerDraft? initial,
  }) async {
    MarkerDraft? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showMarkerEditor(context, initial: initial),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  testWidgets('requires a label', (tester) async {
    final result = await openEditor(tester);
    await tester.tap(find.text('Dodaj'));
    await tester.pumpAndSettle();
    expect(find.text('Podaj nazwę'), findsOneWidget);
    expect(result(), isNull);
  });

  testWidgets('returns trimmed label, description and chosen color', (
    tester,
  ) async {
    final result = await openEditor(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nazwa'),
      ' Las ',
    );
    await tester.tap(
      find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration! as BoxDecoration).color == markerColors[5],
      ),
    );
    await tester.tap(find.text('Dodaj'));
    await tester.pumpAndSettle();

    final draft = result()!;
    expect(draft.label, 'Las');
    expect(draft.description, isNull);
    expect(draft.colorValue, markerColors[5].toARGB32());
  });

  testWidgets('prefills an existing marker for editing', (tester) async {
    final result = await openEditor(
      tester,
      initial: const MarkerDraft(
        label: 'Most',
        description: 'Stary',
        colorValue: 0xFF1E88E5,
      ),
    );
    expect(find.text('Edytuj znacznik'), findsOneWidget);
    expect(find.text('Most'), findsOneWidget);
    expect(find.text('Stary'), findsOneWidget);
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(result()!.colorValue, 0xFF1E88E5);
  });
}
