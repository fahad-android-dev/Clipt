/// One tap during a session.
class Mark {
  const Mark({
    required this.id,
    required this.sessionId,
    required this.atMs,
    required this.tag,
  });

  final int id;
  final int sessionId;

  /// Raw milliseconds since the session started (delay is applied later).
  final int atMs;
  final String tag;
}