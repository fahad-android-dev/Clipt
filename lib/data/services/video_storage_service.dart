import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Talks to the operating system: the video picker and the app's file storage.
class VideoStorageService {
  Future<Directory> _videosDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'videos'));
    return dir.create(recursive: true);
  }

  /// Opens the system picker. Returns the picked file's path, or null if the
  /// user cancelled.
  Future<String?> pickVideoPath() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result.isEmpty) return null;
    return result.first.path;
  }

  /// Moves the picked file into app storage and returns its new file name.
  Future<String> moveIntoStorage({
    required String sourcePath,
    required int sessionId,
  }) async {
    final dir = await _videosDir();
    final fileName = 'session_${sessionId}_'
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(sourcePath)}';
    final target = p.join(dir.path, fileName);
    final source = File(sourcePath);
    try {
      await source.rename(target); // instant when on the same volume
    } on FileSystemException {
      await source.copy(target); // slower fallback for large files
      try {
        await source.delete();
      } catch (_) {}
    }
    return fileName;
  }

  Future<File> fileFor(String fileName) async {
    final dir = await _videosDir();
    return File(p.join(dir.path, fileName));
  }

  Future<void> delete(String fileName) async {
    final file = await fileFor(fileName);
    if (await file.exists()) await file.delete();
  }
}
