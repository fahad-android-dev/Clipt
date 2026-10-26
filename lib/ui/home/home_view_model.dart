import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/session_repository.dart';
import '../../domain/models/session.dart';
import '../../utils/formatters.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required SessionRepository sessionRepository})
      : _repository = sessionRepository {
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
  StreamSubscription<List<Session>>? _subscription;

  List<Session> _sessions = const [];
  bool _loading = true;
  bool _failed = false;

  List<Session> get sessions => _sessions;
  bool get isLoading => _loading;
  bool get hasFailed => _failed;

  /// Creates a session and returns its id. An empty title gets a default name.
  Future<int> startSession(String title) async {
    final trimmed = title.trim();
    final name =
        trimmed.isEmpty ? 'Session ${formatDateTime(DateTime.now())}' : trimmed;
    final session = await _repository.startSession(name);
    return session.id;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}