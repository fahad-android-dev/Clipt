/// Custom trim settings for a mark's clip.
class ClipEdit {
  const ClipEdit({
    required this.markId,
    required this.sessionId,
    this.startMs,
    this.endMs,
    this.included = true,
  });

  final int markId;
  final int sessionId;

  /// Null means automatic (based on sync, delay, and tail).
  final int? startMs;

  /// Null means automatic (based on tail).
  final int? endMs;

  /// Whether this clip should be included in exports.
  final bool included;
}
