import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../data/repositories/session_repository.dart';
import '../../data/repositories/video_repository.dart';
import '../../domain/models/mark.dart';
import '../../domain/models/session.dart';

class ReviewViewModel extends ChangeNotifier {
  ReviewViewModel({
    required SessionRepository sessionRepository,
    required VideoRepository videoRepository,
    required this.sessionId,
  })  : _repository = sessionRepository,
        _videos = videoRepository;

  static const maxDelay = 20;

  final SessionRepository _repository;
  final VideoRepository _videos;
  final int sessionId;

  Session? _session;
  List<Mark> _marks = const [];
  File? _video;
  bool _loading = true;
  bool _notFound = false;
  bool _importing = false;
  String? _error;

  /// What the slider shows right now (may be mid-drag).
  int _delaySeconds = 8;

  /// What is saved in the database.
  int _savedDelay = 8;

  bool get isLoading => _loading;
  bool get notFound => _notFound;
  bool get isImporting => _importing;
  String get title => _session?.title ?? '';
  Duration? get length => _session?.length;
  List<Mark> get marks => _marks;
  File? get video => _video;
  bool get hasVideo => _video != null;
  int get delaySeconds => _delaySeconds;
  String? get errorMessage => _error;

  /// Where a clip for this mark starts: the tap time minus the reaction
  /// delay, never before the start of the recording.
  int clipStartMs(Mark mark) {
    final start = mark.atMs - _delaySeconds * 1000;
    return start < 0 ? 0 : start;
  }

  Future<void> load() async {
    try {
      final session = await _repository.getSession(sessionId);
      if (session == null) {
        _notFound = true;
      } else {
        _session = session;
        _delaySeconds = session.delaySeconds;
        _savedDelay = session.delaySeconds;
        _marks = await _repository.getMarks(sessionId);
        final name = session.videoFile;
        if (name != null) {
          final file = await _videos.resolve(name);
          if (await file.exists()) {
            _video = file;
          } else {
            _error = 'The linked video file is missing. Add it again.';
          }
        }
      }
    } catch (_) {
      _notFound = true;
    }
    _loading = false;
    notifyListeners();
  }

  /// Picks a video and links it to this session. Replaces any earlier one.
  Future<void> addVideo() async {
    if (_importing) return;
    _importing = true;
    _error = null;
    notifyListeners();
    try {
      final name = await _videos.pickAndStore(sessionId);
      if (name != null) {
        final old = _session?.videoFile;
        await _repository.setVideo(sessionId, name);
        _session = await _repository.getSession(sessionId);
        _video = await _videos.resolve(name);
        if (old != null && old != name) await _videos.delete(old);
      }
    } catch (_) {
      _error = 'Couldn\'t add that video. Try again.';
    }
    _importing = false;
    notifyListeners();
  }

  Future<void> removeVideo() async {
    final name = _session?.videoFile;
    if (name == null) return;
    try {
      await _repository.setVideo(sessionId, null);
      await _videos.delete(name);
      _session = await _repository.getSession(sessionId);
      _video = null;
      _error = null;
    } catch (_) {
      _error = 'Couldn\'t remove the video. Try again.';
    }
    notifyListeners();
  }

  /// Called while the slider moves. Updates the screen only.
  void previewDelay(int seconds) {
    _delaySeconds = seconds.clamp(0, maxDelay);
    notifyListeners();
  }

  /// Called when the finger lifts. Saves to the database.
  Future<void> saveDelay() async {
    if (_delaySeconds == _savedDelay) return;
    try {
      await _repository.updateSessionDelay(sessionId, _delaySeconds);
      _savedDelay = _delaySeconds;
      _error = null;
    } catch (_) {
      _delaySeconds = _savedDelay;
      _error = 'Couldn\'t save the delay. Try again.';
    }
    notifyListeners();
  }

  Future<void> changeTag(int markId, String tag) async {
    try {
      await _repository.updateMarkTag(markId, tag);
      _marks = [
        for (final m in _marks)
          m.id == markId
              ? Mark(id: m.id, sessionId: m.sessionId, atMs: m.atMs, tag: tag)
              : m,
      ];
      _error = null;
    } catch (_) {
      _error = 'Couldn\'t change that tag. Try again.';
    }
    notifyListeners();
  }

  Future<void> deleteMark(int markId) async {
    try {
      await _repository.deleteMark(markId);
      _marks = _marks.where((m) => m.id != markId).toList(growable: false);
      _error = null;
    } catch (_) {
      _error = 'Couldn\'t delete that mark. Try again.';
    }
    notifyListeners();
  }
}