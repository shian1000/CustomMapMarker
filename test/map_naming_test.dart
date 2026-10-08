import 'package:custom_map_marker/core/map_naming.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 10, 8);

  test('keeps meaningful file names without the extension', () {
    expect(suggestMapName('Świat Wiedźmina.png', date), 'Świat Wiedźmina');
    expect(suggestMapName('mapa_2.jpg', date), 'mapa_2');
  });

  test('replaces media-id and empty names with the import date', () {
    expect(suggestMapName('1000021497.jpg', date), 'Mapa z 8 października');
    expect(
      suggestMapName('2026-10-08_1234.png', date),
      'Mapa z 8 października',
    );
    expect(suggestMapName('.png', date), 'Mapa z 8 października');
    expect(suggestMapName('123', DateTime(2026, 3, 1)), 'Mapa z 1 marca');
  });
}
