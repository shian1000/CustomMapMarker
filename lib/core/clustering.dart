import 'dart:ui';

/// A group of nearby items, or a single item that had no close neighbours.
class Cluster<T> {
  Cluster(this.members, this.center);

  final List<T> members;

  /// Mean position of the members, in the coordinates they were given in.
  final Offset center;

  bool get isSingle => members.length == 1;
}

/// Groups [items] whose [positionOf] lie within [maxDx] horizontally and
/// [maxDy] vertically of a group's first item.
///
/// A rectangle rather than a radius, because what must not overlap are pins
/// with labels: much wider than tall. Greedy and O(n²), which is fine for the
/// hundreds of markers a map has. Items are visited top to bottom, left to
/// right, so the result doesn't depend on the order they were created in.
List<Cluster<T>> clusterByDistance<T>(
  Iterable<T> items,
  Offset Function(T item) positionOf, {
  required double maxDx,
  required double maxDy,
}) {
  final positioned = [for (final item in items) (item, positionOf(item))]
    ..sort((a, b) {
      final dy = a.$2.dy.compareTo(b.$2.dy);
      return dy != 0 ? dy : a.$2.dx.compareTo(b.$2.dx);
    });

  final taken = List.filled(positioned.length, false);
  final clusters = <Cluster<T>>[];
  for (var i = 0; i < positioned.length; i++) {
    if (taken[i]) continue;
    final (seed, seedAt) = positioned[i];
    final members = [seed];
    var sum = seedAt;
    for (var j = i + 1; j < positioned.length; j++) {
      if (taken[j]) continue;
      final (item, at) = positioned[j];
      // Sorted by y: nothing further down can be close enough.
      if (at.dy - seedAt.dy > maxDy) break;
      if ((at.dx - seedAt.dx).abs() <= maxDx) {
        taken[j] = true;
        members.add(item);
        sum += at;
      }
    }
    clusters.add(Cluster(members, sum / members.length.toDouble()));
  }
  return clusters;
}
