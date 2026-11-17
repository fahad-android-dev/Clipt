import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../domain/clip_planner.dart';
import '../../../domain/models/clip_edit.dart';
import '../../../domain/models/mark.dart';
import '../../../domain/models/session.dart';

class ClipsViewModel extends ChangeNotifier {
  ClipsViewModel({
    required SessionRepository sessionRepository,
    required VideoRepository videoRepository,
    required this.sessionId,
  })  : _repository = sessionRepository,
        _videos = videoRepository;

  final SessionRepository _repository;
  final VideoRepository _videos;
  final int sessionId;

  Session? _session;
  List<Mark> _marks = const [];
  List<ClipEdit> _edits = const [];
  File? _video;
  int? _videoDurationMs;
  bool _loading = true;
  bool _notFound = false;
  String? _error;

  /// Selected clip mark id; null until load completes.
  int? _selectedMarkId;

  /// Draft trim values for smooth slider interaction (not saved yet).
  final Map<int, ({int startMs, int endMs})> _draftTrims = {};

  bool get isLoading => _loading;
  bool get notFound => _notFound;
  String? get errorMessage => _error;
  File? get video => _video;
  int? get videoDurationMs => _videoDurationMs;
  String get title => _session?.title ?? '';
  int? get selectedMarkId => _selectedMarkId;

  Future<void> load() async {
    try {
      final session = await _repository.getSession(sessionId);
      if (session == null) {
        _notFound = true;
      } else {
        _session = session;
        _marks = await _repository.getMarks(sessionId);
        _edits = await _repository.getClipEdits(sessionId);
        final name = session.videoFile;
        if (name != null) {
          final file = await _videos.resolve(name);
          if (await file.exists()) {
            _video = file;
          }
        }
        // Select the first clip after load.
        _selectFirstValid();
      }
    } catch (_) {
      _notFound = true;
    }
    _loading = false;
    notifyListeners();
  }

  void _selectFirstValid() {
    final c = clips;
    if (c.isNotEmpty) {
      _selectedMarkId = c.first.mark.id;
    }
  }

  /// Selects the clip with [markId] and notifies listeners.
  void select(int markId) {
    _selectedMarkId = markId;
    notifyListeners();
  }

  void setVideoDuration(Duration d) {
    _videoDurationMs = d.inMilliseconds;
    notifyListeners();
  }

  List<PlannedClip> get clips {
    if (_session == null) return [];
    return planClips(
      marks: _marks,
      edits: _edits,
      syncOffsetMs: _session!.syncOffsetMs,
      delaySeconds: _session!.delaySeconds,
      videoDurationMs: _videoDurationMs,
    ).map((clip) {
      final draft = _draftTrims[clip.mark.id];
      if (draft != null) {
        return PlannedClip(
          mark: clip.mark,
          startMs: draft.startMs,
          endMs: draft.endMs,
          autoStartMs: clip.autoStartMs,
          autoEndMs: clip.autoEndMs,
          included: clip.included,
          isCustom: clip.isCustom,
        );
      }
      return clip;
    }).toList(growable: false);
  }

  void previewTrim(int markId, int startMs, int endMs) {
    _draftTrims[markId] = (startMs: startMs, endMs: endMs);
    notifyListeners();
  }

  Future<void> saveTrim(int markId) async {
    final draft = _draftTrims.remove(markId);
    if (draft == null) return;

    final clip = clips.firstWhere((c) => c.mark.id == markId);
    try {
      await _repository.saveClipEdit(ClipEdit(
        markId: markId,
        sessionId: sessionId,
        startMs: clip.isCustom ? draft.startMs : null,
        endMs: clip.isCustom ? draft.endMs : null,
        included: clip.included,
      ));
      _edits = await _repository.getClipEdits(sessionId);
      _error = null;
    } catch (_) {
      _error = 'Couldn\'t save that trim. Try again.';
    }
    notifyListeners();
  }

  Future<void> setIncluded(int markId, bool included) async {
    final clip = clips.firstWhere((c) => c.mark.id == markId);
    try {
      await _repository.saveClipEdit(ClipEdit(
        markId: markId,
        sessionId: sessionId,
        startMs: clip.isCustom ? clip.startMs : null,
        endMs: clip.isCustom ? clip.endMs : null,
        included: included,
      ));
      _edits = await _repository.getClipEdits(sessionId);
      _error = null;
    } catch (_) {
      _error = 'Couldn\'t save that change. Try again.';
    }
    notifyListeners();
  }

  Future<void> resetClip(int markId) async {
    try {
      await _repository.saveClipEdit(ClipEdit(
        markId: markId,
        sessionId: sessionId,
        startMs: null,
        endMs: null,
        included: true,
      ));
      _edits = await _repository.getClipEdits(sessionId);
      _error = null;
    } catch (_) {
      _error = 'Couldn\'t reset that clip. Try again.';
    }
    notifyListeners();
  }

  /// Shifts the clip's start by [deltaMs], clamping to the trim window and
  /// keeping the duration within [minClipMs]..[maxClipMs]. Saves immediately.
  Future<void> nudgeStart(int markId, int deltaMs) async {
    final clip = clips.firstWhere((c) => c.mark.id == markId);
    final newStart = (clip.startMs + deltaMs)
        .clamp(clip.windowStartMs, clip.windowEndMs);
    // Keep length in [minClipMs, maxClipMs]
    final minEnd = newStart + minClipMs;
    final maxEnd = newStart + maxClipMs;
    final newEnd = clip.endMs.clamp(minEnd, maxEnd).clamp(
          clip.windowStartMs,
          clip.windowEndMs,
        );
    _draftTrims[markId] = (startMs: newStart, endMs: newEnd);
    notifyListeners();
    await saveTrim(markId);
  }

  /// Shifts the clip's end by [deltaMs], clamping to the trim window and
  /// keeping the duration within [minClipMs]..[maxClipMs]. Saves immediately.
  Future<void> nudgeEnd(int markId, int deltaMs) async {
    final clip = clips.firstWhere((c) => c.mark.id == markId);
    final newEnd = (clip.endMs + deltaMs)
        .clamp(clip.windowStartMs, clip.windowEndMs);
    // Keep length in [minClipMs, maxClipMs]
    final minStart = newEnd - maxClipMs;
    final maxStart = newEnd - minClipMs;
    final newStart = clip.startMs.clamp(minStart, maxStart).clamp(
          clip.windowStartMs,
          clip.windowEndMs,
        );
    _draftTrims[markId] = (startMs: newStart, endMs: newEnd);
    notifyListeners();
    await saveTrim(markId);
  }

  /// Clears the current error message.
  void dismissError() {
    _error = null;
    notifyListeners();
  }

  int get includedCount => clips.where((c) => c.included).length;
  int get totalClips => clips.length;
  int get includedLengthMs =>
      clips.where((c) => c.included).fold(0, (sum, c) => sum + c.lengthMs);

  /// Keeps [_selectedMarkId] valid after clips list changes.
  void _ensureValidSelection() {
    final c = clips;
    if (c.isEmpty) {
      _selectedMarkId = null;
      return;
    }
    if (_selectedMarkId == null ||
        !c.any((clip) => clip.mark.id == _selectedMarkId)) {
      _selectedMarkId = c.first.mark.id;
    }
  }

  @override
  void notifyListeners() {
    _ensureValidSelection();
    super.notifyListeners();
  }
}
