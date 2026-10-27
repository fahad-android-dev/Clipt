import '../../domain/models/mark.dart';
import '../../domain/models/session.dart';
import '../services/app_database.dart';
import 'session_repository.dart';

/// Stores sessions and marks in the local SQLite database.
class LocalSessionRepository implements SessionRepository {
  LocalSessionRepository({required AppDatabase database}) : _db = database;

  final AppDatabase _db;

  @override
  Stream<List<Session>> watchSessions() {
    return _db.watchSessionRows().map(
      (rows) => rows.map(_toSession).toList(growable: false),
    );
  }

  @override
  Future<Session> createSession(String title) async {
    final createdAt = DateTime.now();
    final id = await _db.insertSession(
      title: title,
      createdAtMs: createdAt.millisecondsSinceEpoch,
    );
    return Session(id: id, title: title, createdAt: createdAt);
  }

  @override
  Future<void> startSession(int id) async {
    final row = await _db.findSessionRow(id);
    if (row == null || row.startedAtMs != null) return; // missing or started
    await _db.setSessionStarted(id, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<Session?> getSession(int id) async {
    final row = await _db.findSessionRow(id);
    return row == null ? null : _toSession(row);
  }

  @override
  Future<void> endSession(int id) async {
    final row = await _db.findSessionRow(id);
    if (row == null || row.startedAtMs == null || row.endedAtMs != null) {
      return; // missing, never started, or already ended
    }
    await _db.setSessionEnded(id, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<void> deleteSession(int id) => _db.deleteSessionWithMarks(id);

  @override
  Future<void> updateSessionDelay(int id, int seconds) =>
      _db.setSessionDelay(id, seconds);

  @override
  Future<void> updateMarkTag(int markId, String tag) =>
      _db.setMarkTag(markId, tag);

  @override
  Future<void> setVideo(int id, String? fileName) =>
      _db.setSessionVideo(id, fileName);

  @override
  Future<void> deleteMark(int markId) => _db.deleteMarkRow(markId);

  @override
  Future<void> addMark({
    required int sessionId,
    required int atMs,
    required String tag,
  }) {
    return _db.insertMark(sessionId: sessionId, atMs: atMs, tag: tag);
  }

  @override
  Future<List<Mark>> getMarks(int sessionId) async {
    final rows = await _db.findMarkRows(sessionId);
    return rows.map(_toMark).toList(growable: false);
  }

  // Database rows -> domain models. The rest of the app never sees rows.

  DateTime? _fromMs(int? ms) =>
      ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);

  Session _toSession(SessionRow r) {
    return Session(
      id: r.id,
      title: r.title,
      createdAt: DateTime.fromMillisecondsSinceEpoch(r.createdAtMs),
      startedAt: _fromMs(r.startedAtMs),
      endedAt: _fromMs(r.endedAtMs),
      delaySeconds: r.delaySeconds,
      videoFile: r.videoFile,
    );
  }

  Mark _toMark(MarkRow r) {
    return Mark(id: r.id, sessionId: r.sessionId, atMs: r.atMs, tag: r.tag);
  }
}
