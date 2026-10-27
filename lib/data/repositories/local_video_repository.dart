import 'dart:io';

import '../services/video_storage_service.dart';
import 'video_repository.dart';

class LocalVideoRepository implements VideoRepository {
  LocalVideoRepository({required this._storage});

  final VideoStorageService _storage;

  @override
  Future<String?> pickAndStore(int sessionId) async {
    final path = await _storage.pickVideoPath();
    if (path == null) return null;
    return _storage.moveIntoStorage(sourcePath: path, sessionId: sessionId);
  }

  @override
  Future<File> resolve(String fileName) => _storage.fileFor(fileName);

  @override
  Future<void> delete(String fileName) => _storage.delete(fileName);
}