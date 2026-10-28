enum SessionStatus { ready, live, ended }

/// One play session. Immutable: create a new instance to change it.
///
/// Lifecycle: created (ready) -> started (live) -> ended.
class Session {
  const Session({
    required this.id,
    required this.title,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.delaySeconds = 8,
    this.videoFile,
    this.folderId,
  });

  final int id;
  final String title;
  final DateTime createdAt;

  /// Null until the user presses Start.
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// Seconds subtracted from each mark so clips start before the action.
  final int delaySeconds;

  /// Name of the linked video inside app storage (not a full path).
  final String? videoFile;

  /// Optional folder membership. Null = "Unfiled".
  final int? folderId;

  SessionStatus get status {
    if (startedAt == null) return SessionStatus.ready;
    if (endedAt == null) return SessionStatus.live;
    return SessionStatus.ended;
  }

  bool get isReady => status == SessionStatus.ready;
  bool get isLive => status == SessionStatus.live;
  bool get isEnded => status == SessionStatus.ended;
  bool get hasVideo => videoFile != null;

  /// Total play time. Only known once the session has ended.
  Duration? get length {
    final start = startedAt;
    final end = endedAt;
    if (start == null || end == null) return null;
    return end.difference(start);
  }
}