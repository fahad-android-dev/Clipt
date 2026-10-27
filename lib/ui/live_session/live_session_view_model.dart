import 'package:flutter/foundation.dart';

import '../../data/repositories/session_repository.dart';
import '../../domain/models/session.dart';
import '../../utils/formatters.dart';

class LiveSessionViewModel extends ChangeNotifier {
  LiveSessionViewModel({
    required SessionRepository sessionRepository,
    required this.sessionId,
  }) : _repository = sessionRepository;

  static const tags = ['Clutch', 'Funny', 'Fail'];

  final SessionRepository _repository;
  final int sessionId;

  Session? _session;
  bool _loading = true;
  bool _notFound = false;
  String _tag = tags.first;
  int _markCount = 0;
  String? _lastMark;
  String? _error;

  bool get isLoading => _loading;
  bool get notFound => _notFound;
  bool get isReady => _session?.isReady ?? false;
  bool get isLive => _session?.isLive ?? false;
  String get title => _session?.title ?? '';
  String get selectedTag => _tag;
  int get markCount => _markCount;
  String? get lastMark => _lastMark;
  String? get errorMessage => _error;

  /// Time since the session started. Zero until Start is pressed. Based on
  /// the wall clock, so it stays correct if the phone locks or the app is
  /// paused for a while.
  Duration get elapsed {
    final s = _session;
    final start = s?.startedAt;
    if (s == null || start == null) return Duration.zero;
    return (s.endedAt ?? DateTime.now()).difference(start);
  }

  Future<void> load() async {
    try {
      final session = await _repository.getSession(sessionId);
      if (session == null) {
        _notFound = true;
      } else {
        _session = session;
        _markCount = (await _repository.getMarks(sessionId)).length;
      }
    } catch (_) {
      _notFound = true;
    }
    _loading = false;
    notifyListeners();
  }

  /// Starts the timer. Only works on a session that is ready.
  Future<void> start() async {
    if (!isReady) return;
    try {
      await _repository.startSession(sessionId);
      final updated = await _repository.getSession(sessionId);
      if (updated == null) {
        _notFound = true;
      } else {
        _session = updated;
        _error = null;
      }
    } catch (_) {
      _error = 'Couldn\'t start the session. Try again.';
    }
    notifyListeners();
  }

  void selectTag(String tag) {
    _tag = tag;
    notifyListeners();
  }

  /// Saves a mark at the current time. The counter updates instantly; if the
  /// save fails, the counter is rolled back and an error message is shown.
  Future<void> mark() async {
    if (!isLive) return;
    final ms = elapsed.inMilliseconds;
    _markCount++;
    _lastMark = formatClock(ms);
    _error = null;
    notifyListeners();
    try {
      await _repository.addMark(sessionId: sessionId, atMs: ms, tag: _tag);
    } catch (_) {
      _markCount--;
      _error = 'Couldn\'t save that mark. Try again.';
      notifyListeners();
    }
  }

  Future<void> end() => _repository.endSession(sessionId);
}