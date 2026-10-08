import 'package:file_picker/file_picker.dart';

class ImageFilePicker {
  const ImageFilePicker();

  /// Lets the user pick an image. Returns its path, or null when cancelled.
  Future<String?> pick() async {
    final files = await FilePicker.pickFiles(type: FileType.image);
    return files.firstOrNull?.path;
  }
}
