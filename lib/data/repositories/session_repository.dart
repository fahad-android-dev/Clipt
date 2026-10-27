import '../../domain/models/mark.dart';
import '../../domain/models/session.dart';

/// Source of truth for sessions and their marks.
/// Abstract so tests (and a future cloud version) can swap implementations.
abstract class SessionRepository {
  /// Emits the full list (newest first) now, and again after every change.
  Stream<List<Session>> watchSessions();

  /// Creates a session in the "ready" state. The timer does not run yet.
  Future<Session> createSession(String title);

  /// Starts the timer. Does nothing if the session already started.
  Future<void> startSession(int id);

  Future<Session?> getSession(int id);

  /// Ends a live session. Does nothing if it isn't live.
  Future<void> endSession(int id);

  /// Deletes the session and all of its marks.
  Future<void> deleteSession(int id);

  Future<void> addMark({
    required int sessionId,
    required int atMs,
    required String tag,
  });

  Future<List<Mark>> getMarks(int sessionId);

  Future<void> updateSessionDelay(int id, int seconds);

  Future<void> updateMarkTag(int markId, String tag);

  Future<void> deleteMark(int markId);

  Future<void> setVideo(int id, String? fileName);
}