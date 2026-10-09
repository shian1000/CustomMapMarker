const _diacritics = {
  'ą': 'a',
  'ć': 'c',
  'ę': 'e',
  'ł': 'l',
  'ń': 'n',
  'ó': 'o',
  'ś': 's',
  'ź': 'z',
  'ż': 'z',
};

/// Lower-cases [text] and strips Polish diacritics, so "Żółw" and "zolw"
/// compare equal.
String foldForSearch(String text) {
  final lower = text.toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    out.write(_diacritics[char] ?? char);
  }
  return out.toString();
}

/// Whether every word of [query] occurs in one of [fields], ignoring case and
/// Polish diacritics. An empty query matches everything.
bool matchesSearch(String query, Iterable<String?> fields) {
  final words = foldForSearch(query).split(RegExp(r'\s+'))
    ..removeWhere((w) => w.isEmpty);
  if (words.isEmpty) return true;
  final haystack = [
    for (final field in fields)
      if (field != null) foldForSearch(field),
  ].join('\n');
  return words.every(haystack.contains);
}
