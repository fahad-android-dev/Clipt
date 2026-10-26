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
    return _db
        .watchSessionRows()
        .map((rows) => rows.map(_toSession).toList(growable: false));
  }

  @override
  Future<Session> startSession(String title) async {
    final startedAt = DateTime.now();
    final id = await _db.insertSession(
      title: title,
      startedAtMs: startedAt.millisecondsSinceEpoch,
    );
    return Session(id: id, title: title, startedAt: startedAt);
  }

  @override
  Future<Session?> getSession(int id) async {
    final row = await _db.findSessionRow(id);
    return row == null ? null : _toSession(row);
  }

  @override
  Future<void> endSession(int id) async {
    final row = await _db.findSessionRow(id);
    if (row == null || row.endedAtMs != null) return; // missing or already ended
    await _db.setSessionEnded(id, DateTime.now().millisecondsSinceEpoch);
  }

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

  Session _toSession(SessionRow r) {
    return Session(
      id: r.id,
      title: r.title,
      startedAt: DateTime.fromMillisecondsSinceEpoch(r.startedAtMs),
      endedAt: r.endedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.endedAtMs!),
      delaySeconds: r.delaySeconds,
    );
  }

  Mark _toMark(MarkRow r) {
    return Mark(
      id: r.id,
      sessionId: r.sessionId,
      atMs: r.atMs,
      tag: r.tag,
    );
  }
}