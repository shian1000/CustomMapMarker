import 'dart:convert';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// Why a file couldn't be read as a map archive.
enum MapArchiveError {
  /// Not a ZIP, or no manifest from this app.
  notAMapFile,

  /// Written by a newer app version with an unknown format version.
  newerVersion,

  /// Recognized, but missing or broken parts.
  damaged,
}

class MapArchiveException implements Exception {
  const MapArchiveException(this.error, [this.detail]);

  final MapArchiveError error;
  final String? detail;

  @override
  String toString() => 'MapArchiveException(${error.name}: $detail)';
}

const manifestEntry = 'manifest.json';

/// Writes a map archive: [manifestJson] plus the image at [imagePath] stored
/// as [imageEntry]. The image is stored uncompressed: PNG/JPEG are already
/// compressed, and deflating 40+ MB again would only cost time.
///
/// Synchronous — run it in an isolate.
void writeMapArchive({
  required String zipPath,
  required String manifestJson,
  required String imagePath,
  required String imageEntry,
}) {
  final encoder = ZipFileEncoder()..create(zipPath);
  try {
    encoder.addArchiveFile(ArchiveFile.string(manifestEntry, manifestJson));
    // The level argument of addFileSync doesn't affect this; the entry's own
    // compression type decides.
    final image = InputFileStream(imagePath);
    try {
      encoder.addArchiveFile(
        ArchiveFile.stream(imageEntry, image)
          ..compression = CompressionType.none,
      );
    } finally {
      image.closeSync();
    }
  } finally {
    encoder.closeSync();
  }
}

/// Reads the manifest of the archive at [zipPath] and extracts the entry it
/// names as the image into [extractDir]. [imageEntryOf] validates the
/// manifest (throwing [MapArchiveException] if it's unusable) and picks that
/// entry name. Returns the manifest JSON and the extracted image path.
///
/// Synchronous — run it in an isolate.
({String manifestJson, String imagePath}) readMapArchive({
  required String zipPath,
  required String extractDir,
  required String Function(String manifestJson) imageEntryOf,
}) {
  final input = InputFileStream(zipPath);
  try {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeStream(input);
    } catch (e) {
      throw MapArchiveException(MapArchiveError.notAMapFile, '$e');
    }
    final manifestFile = archive.find(manifestEntry);
    final manifestBytes = manifestFile?.readBytes();
    if (manifestBytes == null) {
      throw const MapArchiveException(
        MapArchiveError.notAMapFile,
        'no manifest',
      );
    }
    final manifest = _decodeUtf8(manifestBytes);
    if (manifest == null) {
      throw const MapArchiveException(
        MapArchiveError.damaged,
        'manifest is not UTF-8',
      );
    }

    final imageEntry = imageEntryOf(manifest);
    final imageFile = archive.find(imageEntry);
    if (imageFile == null || !imageFile.isFile) {
      throw const MapArchiveException(MapArchiveError.damaged, 'no image');
    }
    // Only the base name: an entry like "../x" must not escape extractDir.
    final imagePath = p.join(extractDir, p.basename(imageEntry));
    final output = OutputFileStream(imagePath);
    try {
      imageFile.writeContent(output);
    } finally {
      output.closeSync();
    }
    return (manifestJson: manifest, imagePath: imagePath);
  } finally {
    input.closeSync();
  }
}

String? _decodeUtf8(List<int> bytes) {
  try {
    return const Utf8Decoder().convert(bytes);
  } on FormatException {
    return null;
  }
}
