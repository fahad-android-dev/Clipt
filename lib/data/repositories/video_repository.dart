import 'dart:io';

/// Stores video files inside the app. Sessions refer to videos by file name,
/// because the full path to app storage can change between app updates.
abstract class VideoRepository {
  /// Opens the picker and stores the chosen video. Returns the stored file
  /// name, or null if the user cancelled.
  Future<String?> pickAndStore(int sessionId);

  Future<File> resolve(String fileName);

  Future<void> delete(String fileName);
}