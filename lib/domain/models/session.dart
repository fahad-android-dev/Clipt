/// One play session. Immutable: create a new instance to change it.
class Session {
  const Session({
    required this.id,
    required this.title,
    required this.startedAt,
    this.endedAt,
    this.delaySeconds = 8,
  });

  final int id;
  final String title;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// Seconds subtracted from each mark so clips start before the action.
  final int delaySeconds;

  bool get isActive => endedAt == null;
  Duration? get length => endedAt?.difference(startedAt);
}