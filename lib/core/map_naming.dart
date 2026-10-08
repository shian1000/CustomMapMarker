import 'package:path/path.dart' as p;

const _monthsGenitive = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

/// Default name for a map imported from [fileName].
///
/// Android's photo picker often hands over a copy named only by a media id
/// (e.g. "1000021497.jpg"); such names fall back to "Mapa z 8 października".
String suggestMapName(String fileName, DateTime importedAt) {
  // A bare ".png" counts as a hidden file named ".png" for package:path.
  final base = p.basename(fileName).startsWith('.')
      ? ''
      : p.basenameWithoutExtension(fileName).trim();
  if (base.isNotEmpty && RegExp(r'[^\d\s_\-.]').hasMatch(base)) return base;
  final month = _monthsGenitive[importedAt.month - 1];
  return 'Mapa z ${importedAt.day} $month';
}
