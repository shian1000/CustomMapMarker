/// Picks the Polish plural form for [count], e.g.
/// `pluralPl(n, 'znacznik', 'znaczniki', 'znaczników')`.
String pluralPl(int count, String one, String few, String many) {
  if (count == 1) return one;
  final lastDigit = count % 10;
  final lastTwo = count % 100;
  if (lastDigit >= 2 && lastDigit <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return few;
  }
  return many;
}

String markerCountLabel(int count) =>
    '$count ${pluralPl(count, 'znacznik', 'znaczniki', 'znaczników')}';

String routeCountLabel(int count) =>
    '$count ${pluralPl(count, 'trasa', 'trasy', 'tras')}';

String areaCountLabel(int count) =>
    '$count ${pluralPl(count, 'obszar', 'obszary', 'obszarów')}';
