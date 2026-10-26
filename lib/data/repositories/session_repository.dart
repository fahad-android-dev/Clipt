import '../../domain/models/mark.dart';
import '../../domain/models/session.dart';

/// Source of truth for sessions and their marks.
/// Abstract so tests (and a future cloud version) can swap implementations.
abstract class SessionRepository {
  Stream<List<Session>> watchSessions();

  Future<Session> startSession(String title);

  Future<Session?> getSession(int id);

  Future<void> endSession(int id);

  Future<void> addMark({
    required int sessionId,
    required int atMs,
    required String tag,
  });

  Future<List<Mark>> getMarks(int sessionId);
}