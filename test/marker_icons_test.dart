import 'package:custom_map_marker/shared/marker_icons.dart';
import 'package:custom_map_marker/shared/widgets/marker_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keys are unique', () {
    final keys = markerIcons.map((i) => i.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('looks icons up by key', () {
    expect(markerIconFor('castle')?.icon, Icons.castle);
    expect(markerIconFor(null), isNull);
    expect(markerIconFor('unknown'), isNull);
  });

  testWidgets('the pin draws its icon in a contrasting color', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: MarkerPin(
            label: 'Kaer Morhen',
            color: Color(0xFFFDD835), // yellow: needs a dark icon
            icon: Icons.castle,
          ),
        ),
      ),
    );
    final icon = tester.widget<Icon>(find.byIcon(Icons.castle));
    expect(icon.color, Colors.black);
  });

  testWidgets('the plain pin has no inner icon', (tester) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: MarkerPin(label: 'X', color: Color(0xFF1E88E5)),
        ),
      ),
    );
    expect(find.byType(Icon), findsOneWidget);
  });
}
