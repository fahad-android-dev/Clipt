import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/session_repository.dart';
import '../../domain/models/session.dart';
import '../../utils/formatters.dart';
import '../../data/repositories/video_repository.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required SessionRepository sessionRepository,
    required VideoRepository videoRepository,
  }) : _repository = sessionRepository,
       _videos = videoRepository {
    _subscription = _repository.watchSessions().listen(
      (sessions) {
        _sessions = sessions;
        _loading = false;
        _failed = false;
        notifyListeners();
      },
      onError: (Object _) {
        _loading = false;
        _failed = true;
        notifyListeners();
      },
    );
  }

  final SessionRepository _repository;
  final VideoRepository _videos;
  StreamSubscription<List<Session>>? _subscription;

  List<Session> _sessions = const [];
  bool _loading = true;
  bool _failed = false;

  List<Session> get sessions => _sessions;
  bool get isLoading => _loading;
  bool get hasFailed => _failed;

  /// Creates a session that is ready to start. An empty title gets a default
  /// name. The list updates by itself through the repository stream.
  Future<void> createSession(String title) async {
    final trimmed = title.trim();
    final name = trimmed.isEmpty
        ? 'Session ${formatDateTime(DateTime.now())}'
        : trimmed;
    await _repository.createSession(name);
  }

  Future<void> deleteSession(Session session) async {
    await _repository.deleteSession(session.id);
    final file = session.videoFile;
    if (file != null) await _videos.delete(file);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
