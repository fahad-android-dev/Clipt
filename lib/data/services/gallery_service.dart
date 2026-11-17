import 'package:gal/gal.dart';

class GalleryService {
  /// Requests gallery access if not already granted.
  /// Returns true if access is available.
  static Future<bool> ensureAccess() async {
    if (await Gal.hasAccess(toAlbum: true)) return true;
    return await Gal.requestAccess(toAlbum: true);
  }

  /// Saves a video to the Clipt album.
  static Future<void> saveVideo(String path) async {
    try {
      await Gal.putVideo(path, album: 'Clipt');
    } on GalException catch (e) {
      throw Exception(e.type.message);
    }
  }
}
