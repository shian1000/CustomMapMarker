import 'package:file_picker/file_picker.dart';

typedef PickedImage = ({String path, String name});

class ImageFilePicker {
  const ImageFilePicker();

  /// Lets the user pick an image. Returns its local path and original file
  /// name, or null when cancelled.
  Future<PickedImage?> pick() async {
    final file = (await FilePicker.pickFiles(type: FileType.image)).firstOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;
    return (path: path, name: file.name);
  }

  /// Lets the user pick any file, e.g. an exported `.cmm` map. Android's
  /// picker can't filter by an extension without a known MIME type, so the
  /// file is validated when read instead.
  Future<String?> pickAnyFile() async =>
      (await FilePicker.pickFiles(type: FileType.any)).firstOrNull?.path;
}
