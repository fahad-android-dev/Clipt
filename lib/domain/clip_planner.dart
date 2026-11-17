import 'models/clip_edit.dart';
import 'models/mark.dart';

/// A planned clip with calculated timing.
class PlannedClip {
  const PlannedClip({
    required this.mark,
    required this.startMs,
    required this.endMs,
    required this.autoStartMs,
    required this.autoEndMs,
    required this.included,
    required this.isCustom,
  });

  final Mark mark;
  final int startMs;
  final int endMs;
  final int autoStartMs;
  final int autoEndMs;
  final bool included;
  final bool isCustom;

  int get lengthMs => endMs - startMs;
  int get windowStartMs => (autoStartMs - trimWindowMs).clamp(0, autoEndMs);
  int get windowEndMs => autoEndMs + trimWindowMs;
}

const int defaultTailMs = 5000;
const int minClipMs = 1000;
const int maxClipMs = 120000;
const int trimWindowMs = 20000;

/// Plans clips from marks and edits.
List<PlannedClip> planClips({
  required List<Mark> marks,
  required List<ClipEdit> edits,
  required int syncOffsetMs,
  required int delaySeconds,
  int? videoDurationMs,
  int tailMs = defaultTailMs,
}) {
  // Sort marks by their tap time
  final sortedMarks = List<Mark>.from(marks)..sort((a, b) => a.atMs.compareTo(b.atMs));

  // Build a map of markId -> edit for quick lookup
  final editMap = <int, ClipEdit>{};
  for (final edit in edits) {
    editMap[edit.markId] = edit;
  }

  final result = <PlannedClip>[];

  for (final mark in sortedMarks) {
    final tap = mark.atMs + syncOffsetMs;
    var autoStart = (tap - delaySeconds * 1000).clamp(0, tap);
    var autoEnd = tap + tailMs;

    if (videoDurationMs != null) {
      autoEnd = autoEnd.clamp(0, videoDurationMs);
      autoStart = autoStart.clamp(0, (autoEnd - minClipMs).clamp(0, autoEnd));
    }

    final edit = editMap[mark.id];
    final start = edit?.startMs ?? autoStart;
    final end = edit?.endMs ?? autoEnd;
    final isCustom = edit?.startMs != null || edit?.endMs != null;
    final included = edit?.included ?? true;

    // Calculate window
    final windowStart = (autoStart - trimWindowMs).clamp(0, autoEnd);
    final windowEnd = videoDurationMs != null
        ? (autoEnd + trimWindowMs).clamp(0, videoDurationMs)
        : autoEnd + trimWindowMs;

    // Clamp start and end into window
    var clampedStart = start.clamp(windowStart, windowEnd);
    var clampedEnd = end.clamp(windowStart, windowEnd);

    // Ensure minimum and maximum length
    final length = clampedEnd - clampedStart;
    if (length < minClipMs) {
      clampedEnd = (clampedStart + minClipMs).clamp(clampedStart, windowEnd);
    }
    if (clampedEnd - clampedStart > maxClipMs) {
      clampedEnd = clampedStart + maxClipMs;
    }

    result.add(PlannedClip(
      mark: mark,
      startMs: clampedStart,
      endMs: clampedEnd,
      autoStartMs: autoStart,
      autoEndMs: autoEnd,
      included: included,
      isCustom: isCustom,
    ));
  }

  return result;
}
