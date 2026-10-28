import '../../domain/models/folder.dart';
import '../../domain/models/mark.dart';
import '../../domain/models/session.dart';

/// Source of truth for sessions and their marks.
/// Abstract so tests (and a future cloud version) can swap implementations.
abstract class SessionRepository {
  /// Emits the full list (newest first) now, and again after every change.
  Stream<List<Session>> watchSessions();

  /// Emits the full list of folders (sorted by name, case-insensitive).
  Stream<List<Folder>> watchFolders();

  /// Creates a session in the "ready" state. The timer does not run yet.
  Future<Session> createSession(String title, {int? folderId});

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

  /// Creates a new folder.
  Future<Folder> createFolder(String name);

  /// Renames an existing folder.
  Future<void> renameFolder(int id, String name);

  /// Deletes a folder, its sessions, and their marks.
  Future<void> deleteFolder(int id);

  /// Gets all sessions in a specific folder.
  Future<List<Session>> getSessionsInFolder(int folderId);

  /// Moves a session to a different folder (or unfiled with null).
  Future<void> moveSession(int sessionId, int? folderId);
}