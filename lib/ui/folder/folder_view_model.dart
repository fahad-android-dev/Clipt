import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/session_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../domain/models/folder.dart';
import '../../domain/models/session.dart';
import '../../utils/formatters.dart';

class FolderViewModel extends ChangeNotifier {
  FolderViewModel({
    required SessionRepository sessionRepository,
    required VideoRepository videoRepository,
    required this.folderId,
  })  : _repository = sessionRepository,
        _videos = videoRepository {
    _init();
  }

  final SessionRepository _repository;
  final VideoRepository _videos;
  final int? folderId;

  StreamSubscription<List<Session>>? _sessionSub;
  StreamSubscription<List<Folder>>? _folderSub;

  List<Folder> _folders = const [];
  List<Session> _sessions = const [];
  bool _loading = true;
  bool _notFound = false;

  bool get isLoading => _loading;
  bool get notFound => _notFound;
  String get title {
    if (folderId == null) return 'Unfiled';
    final folder = _folders.firstWhere(
      (f) => f.id == folderId,
      orElse: () => Folder(
        id: -1,
        name: 'Unknown',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    return folder.name;
  }

  List<Session> get sessions => _sessions;
  List<Folder> get moveTargets =>
      _folders.where((f) => f.id != folderId).toList();
  bool get canMoveToUnfiled => folderId != null;

  void _init() {
    _sessionSub = _repository.watchSessions().listen(
      (sessions) {
        _sessions = sessions.where((s) => s.folderId == folderId).toList();
        _loading = false;
        notifyListeners();
      },
      onError: (_) {
        _loading = false;
        notifyListeners();
      },
    );

    _folderSub = _repository.watchFolders().listen(
      (folders) {
        _folders = folders;
        if (folderId != null) {
          _notFound = !folders.any((f) => f.id == folderId);
        }
        notifyListeners();
      },
      onError: (_) {
        notifyListeners();
      },
    );
  }

  Future<void> createSession(String title) async {
    final trimmed = title.trim();
    final name = trimmed.isEmpty
        ? 'Session ${formatDateTime(DateTime.now())}'
        : trimmed;
    await _repository.createSession(name, folderId: folderId);
  }

  Future<void> deleteSession(Session session) async {
    final videoName = session.videoFile;
    await _repository.deleteSession(session.id);
    if (videoName != null) {
      await _videos.delete(videoName);
    }
  }

  Future<void> moveSession(Session session, int? targetFolderId) async {
    await _repository.moveSession(session.id, targetFolderId);
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _folderSub?.cancel();
    super.dispose();
  }
}
