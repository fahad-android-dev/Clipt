import 'package:share_plus/share_plus.dart';

class ShareService {
  static Future<void> shareFiles(
    List<String> paths, {
    String? text,
  }) async {
    final xFiles = paths.map((path) => XFile(path)).toList();
    await SharePlus.instance.share(
      ShareParams(
        files: xFiles,
        text: text,
      ),
    );
  }
}
