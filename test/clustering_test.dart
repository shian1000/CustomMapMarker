import 'package:custom_map_marker/core/clustering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<List<String>> groups(Map<String, Offset> points) => [
    for (final c in clusterByDistance(
      points.keys,
      (k) => points[k]!,
      maxDx: 100,
      maxDy: 50,
    ))
      c.members..sort(),
  ];

  test('keeps distant points apart', () {
    expect(groups({'a': Offset.zero, 'b': const Offset(300, 0)}), [
      ['a'],
      ['b'],
    ]);
  });

  test('uses a wide rectangle: merges side by side sooner than stacked', () {
    // 80 px apart horizontally overlaps (labels are wide)...
    expect(groups({'a': Offset.zero, 'b': const Offset(80, 0)}), [
      ['a', 'b'],
    ]);
    // ...but 80 px apart vertically doesn't.
    expect(groups({'a': Offset.zero, 'b': const Offset(0, 80)}), [
      ['a'],
      ['b'],
    ]);
  });

  test('centers a cluster on the mean of its members', () {
    final clusters = clusterByDistance(
      ['a', 'b'],
      (k) => k == 'a' ? Offset.zero : const Offset(60, 20),
      maxDx: 100,
      maxDy: 50,
    );
    expect(clusters.single.center, const Offset(30, 10));
    expect(clusters.single.isSingle, isFalse);
  });

  test('does not depend on the input order', () {
    final points = {
      'a': const Offset(0, 0),
      'b': const Offset(90, 10),
      'c': const Offset(180, 20),
      'd': const Offset(500, 500),
    };
    final forward = groups(points);
    final backward = groups(Map.fromEntries(points.entries.toList().reversed));
    expect(backward, forward);
  });

  test('handles no points', () {
    expect(groups({}), isEmpty);
  });
}
