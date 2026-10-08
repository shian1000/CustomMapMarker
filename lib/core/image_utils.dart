import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class UnsupportedImageException implements Exception {
  const UnsupportedImageException(this.path);

  final String path;

  @override
  String toString() => 'Nieobsługiwany format obrazu: $path';
}

/// [format] is one of `jpeg`, `png`, `webp`, `gif`, `bmp`.
typedef PreparedImage = ({String path, int width, int height, String format});

/// Copies the image at [sourcePath] to [destDir] as `map.<ext>`, baking the
/// EXIF orientation into the pixels when needed so the stored file and its
/// reported size always match what is displayed.
///
/// Synchronous and potentially slow — run it in an isolate.
PreparedImage prepareMapImage(String sourcePath, String destDir) {
  final bytes = File(sourcePath).readAsBytesSync();
  final decoder = _findDisplayableDecoder(bytes);
  if (decoder == null) throw UnsupportedImageException(sourcePath);

  if (decoder is img.JpegDecoder) {
    final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation;
    if (orientation != null && orientation != 1) {
      final baked = img.bakeOrientation(img.decodeJpg(bytes)!);
      final path = '$destDir/map.jpg';
      File(path).writeAsBytesSync(img.encodeJpg(baked, quality: 95));
      return (
        path: path,
        width: baked.width,
        height: baked.height,
        format: 'jpeg',
      );
    }
  }

  final info = _tryOrNull(() => decoder.startDecode(bytes));
  if (info == null) throw UnsupportedImageException(sourcePath);
  final ext = sourcePath.contains('.')
      ? sourcePath.substring(sourcePath.lastIndexOf('.')).toLowerCase()
      : '';
  final path = '$destDir/map$ext';
  File(path).writeAsBytesSync(bytes);
  return (
    path: path,
    width: info.width,
    height: info.height,
    format: _formatName(decoder),
  );
}

/// Fully decodes [bytes], accepting only formats Flutter can render.
img.Image decodeDisplayableImage(Uint8List bytes) {
  final decoder = _findDisplayableDecoder(bytes);
  final image = decoder == null
      ? null
      : _tryOrNull(() => decoder.decode(bytes));
  if (image == null) throw const UnsupportedImageException('');
  return image;
}

/// Only formats Flutter's image codecs can render.
img.Decoder? _findDisplayableDecoder(Uint8List bytes) {
  final candidates = <img.Decoder>[
    img.PngDecoder(),
    img.JpegDecoder(),
    img.WebPDecoder(),
    img.GifDecoder(),
    img.BmpDecoder(),
  ];
  for (final decoder in candidates) {
    if (_tryOrNull(() => decoder.isValidFile(bytes)) ?? false) return decoder;
  }
  return null;
}

/// The image package can throw on malformed input instead of returning null.
T? _tryOrNull<T>(T Function() f) {
  try {
    return f();
  } catch (_) {
    return null;
  }
}

String _formatName(img.Decoder decoder) => switch (decoder) {
  img.PngDecoder() => 'png',
  img.JpegDecoder() => 'jpeg',
  img.WebPDecoder() => 'webp',
  img.GifDecoder() => 'gif',
  img.BmpDecoder() => 'bmp',
  _ => 'unknown',
};
