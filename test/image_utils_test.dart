import 'dart:io';

import 'package:custom_map_marker/core/image_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('map_import'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final file = File('${tmp.path}/$name')..writeAsBytesSync(bytes);
    return file.path;
  }

  Directory dest() => Directory('${tmp.path}/out')..createSync();

  test('copies PNG and reads its size', () {
    final src = write('a.PNG', img.encodePng(img.Image(width: 30, height: 20)));
    final result = prepareMapImage(src, dest().path);
    expect((result.width, result.height), (30, 20));
    expect(result.path, endsWith('map.png'));
    expect(File(result.path).lengthSync(), File(src).lengthSync());
  });

  test('bakes EXIF rotation into JPEG and swaps dimensions', () {
    final image = img.Image(width: 30, height: 20)
      ..exif.imageIfd.orientation = 6;
    final src = write('photo.jpg', img.encodeJpg(image));
    final result = prepareMapImage(src, dest().path);
    expect((result.width, result.height), (20, 30));
    final stored = File(result.path).readAsBytesSync();
    expect(img.decodeJpgExif(stored)?.imageIfd.orientation, isNull);
  });

  test('rejects non-image files', () {
    final src = write('notes.txt', 'hello'.codeUnits);
    expect(
      () => prepareMapImage(src, dest().path),
      throwsA(isA<UnsupportedImageException>()),
    );
  });
}
