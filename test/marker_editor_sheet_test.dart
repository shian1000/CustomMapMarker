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

  testWidgets('picks an icon and shows its name', (tester) async {
    final result = await openEditor(tester);
    expect(find.text('zwykła pinezka'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nazwa'),
      'Wyzima',
    );
    await tester.tap(find.byTooltip('Zamek'));
    await tester.pump();
    expect(find.text('Zamek'), findsWidgets);
    await tester.ensureVisible(find.text('Dodaj'));
    await tester.tap(find.text('Dodaj'));
    await tester.pumpAndSettle();
    expect(result()!.icon, 'castle');
  });

  testWidgets('can go back to the plain pin', (tester) async {
    final result = await openEditor(
      tester,
      initial: const MarkerDraft(label: 'Most', colorValue: 1, icon: 'castle'),
    );
    expect(find.text('Zamek'), findsWidgets);
    await tester.tap(find.byTooltip('Zwykła pinezka'));
    await tester.pump();
    await tester.ensureVisible(find.text('Zapisz'));
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(result()!.icon, isNull);
  });

  testWidgets('treats an unknown icon key as the plain pin', (tester) async {
    final result = await openEditor(
      tester,
      initial: const MarkerDraft(label: 'X', colorValue: 1, icon: 'from-v99'),
    );
    expect(find.text('zwykła pinezka'), findsOneWidget);
    await tester.ensureVisible(find.text('Zapisz'));
    await tester.tap(find.text('Zapisz'));
    await tester.pumpAndSettle();
    expect(result()!.icon, isNull);
  });
}
