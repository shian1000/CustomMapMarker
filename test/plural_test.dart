import 'package:custom_map_marker/core/plural.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Polish plural forms of "znacznik"', () {
    final cases = {
      0: '0 znaczników',
      1: '1 znacznik',
      2: '2 znaczniki',
      4: '4 znaczniki',
      5: '5 znaczników',
      11: '11 znaczników',
      12: '12 znaczników',
      14: '14 znaczników',
      21: '21 znaczników',
      22: '22 znaczniki',
      104: '104 znaczniki',
      112: '112 znaczników',
    };
    cases.forEach((count, label) => expect(markerCountLabel(count), label));
  });
}
