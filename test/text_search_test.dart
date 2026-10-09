import 'package:custom_map_marker/core/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('folds case and Polish diacritics', () {
    expect(foldForSearch('Żółw ŁĄKA Ćma Ęś Ńź'), 'zolw laka cma es nz');
  });

  test('matches regardless of case and diacritics', () {
    expect(matchesSearch('wyzima', ['Wyzima']), isTrue);
    expect(matchesSearch('zolw', ['Żółw']), isTrue);
    expect(matchesSearch('ŻÓŁW', ['zolw']), isTrue);
    expect(matchesSearch('novi', ['Wyzima']), isFalse);
  });

  test('searches descriptions and requires every word', () {
    expect(matchesSearch('karczma', ['Wyzima', 'Karczma Pod Lisem']), isTrue);
    expect(
      matchesSearch('wyzima lis', ['Wyzima', 'Karczma Pod Lisem']),
      isTrue,
    );
    expect(matchesSearch('wyzima smok', ['Wyzima', 'Karczma']), isFalse);
    expect(matchesSearch('lis', ['Wyzima', null]), isFalse);
  });

  test('an empty or blank query matches everything', () {
    expect(matchesSearch('', ['x']), isTrue);
    expect(matchesSearch('   ', ['x']), isTrue);
  });
}
