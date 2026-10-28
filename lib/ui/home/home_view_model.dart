import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/session_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../domain/models/folder.dart';
import '../../domain/models/session.dart';

class FolderSummary {
  const FolderSummary({
    required this.folder,
    required this.sessionCount,
  });

  final Folder folder;
  final int sessionCount;
}

class SearchResults {
  const SearchResults({
    required this.folders,
    required this.sessions,
    required this.isEmpty,
  });

  final List<FolderSummary> folders;
  final List<Session> sessions;
  final bool isEmpty;
}

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required SessionRepository sessionRepository,
    required VideoRepository videoRepository,
  })  : _repository = sessionRepository,
        _videos = videoRepository {
    _init();
  }

  final SessionRepository _repository;
  final VideoRepository _videos;

  StreamSubscription<List<Session>>? _sessionSub;
  StreamSubscription<List<Folder>>? _folderSub;

  List<Folder> _folders = const [];
  List<Session> _sessions = const [];
  bool _loading = true;
  bool _failed = false;
  String _query = '';

  bool get isLoading => _loading;
  bool get hasFailed => _failed;
  String get query => _query;
  bool get isSearching => _query.trim().isNotEmpty;

  List<FolderSummary> get folders {
    final lowerQuery = _query.toLowerCase();
    return _folders
        .where((f) => f.name.toLowerCase().contains(lowerQuery))
        .map((f) => FolderSummary(
              folder: f,
              sessionCount: _sessions.where((s) => s.folderId == f.id).length,
            ))
        .toList();
  }

  int get unfiledCount =>
      _sessions.where((s) => s.folderId == null).length;

  SearchResults get results {
    if (!isSearching) {
      return const SearchResults(
        folders: [],
        sessions: [],
        isEmpty: false,
      );
    }

    final lowerQuery = _query.toLowerCase();
    final matchingFolders = _folders
        .where((f) => f.name.toLowerCase().contains(lowerQuery))
        .map((f) => FolderSummary(
              folder: f,
              sessionCount: _sessions.where((s) => s.folderId == f.id).length,
            ))
        .toList();

    final matchingSessions = _sessions
        .where((s) => s.title.toLowerCase().contains(lowerQuery))
        .toList();

    return SearchResults(
      folders: matchingFolders,
      sessions: matchingSessions,
      isEmpty: matchingFolders.isEmpty && matchingSessions.isEmpty,
    );
  }

  String folderLabelFor(Session session) {
    if (session.folderId == null) return 'Unfiled';
    final folder = _folders.firstWhere(
      (f) => f.id == session.folderId,
      orElse: () => Folder(
        id: -1,
        name: 'Unknown',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    return folder.name;
  }

  void _init() {
    _sessionSub = _repository.watchSessions().listen(
      (sessions) {
        _sessions = sessions;
        _loading = false;
        _failed = false;
        notifyListeners();
      },
      onError: (_) {
        _loading = false;
        _failed = true;
        notifyListeners();
      },
    );

    _folderSub = _repository.watchFolders().listen(
      (folders) {
        _folders = folders;
        notifyListeners();
      },
      onError: (_) {
        notifyListeners();
      },
    );
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  Future<void> createFolder(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _repository.createFolder(trimmed);
  }

  Future<void> renameFolder(Folder folder, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == folder.name) return;
    await _repository.renameFolder(folder.id, trimmed);
  }

  Future<void> deleteFolder(Folder folder) async {
    final sessions = await _repository.getSessionsInFolder(folder.id);
    for (final session in sessions) {
      if (session.videoFile != null) {
        await _videos.delete(session.videoFile!);
      }
    }
    await _repository.deleteFolder(folder.id);
  }

  Future<int> getSessionCountInFolder(int folderId) async {
    final sessions = await _repository.getSessionsInFolder(folderId);
    return sessions.length;
  }

  Future<void> deleteSession(Session session) async {
    final videoName = session.videoFile;
    await _repository.deleteSession(session.id);
    if (videoName != null) {
      await _videos.delete(videoName);
    }
  }

  @override
  void dispose() {
    _sessionSub?.cancel();
    _folderSub?.cancel();
    super.dispose();
  }
}
