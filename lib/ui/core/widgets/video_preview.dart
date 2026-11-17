import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../../utils/formatters.dart';
import '../themes/app_colors.dart';
import '../themes/app_theme.dart';

/// Plays a local video with a play/pause button and a scrubbable bar.
/// Other widgets can jump it to a position with a GlobalKey and [seekTo].
class VideoPreview extends StatefulWidget {
  const VideoPreview({
    super.key,
    required this.file,
    this.onReady,
  });

  final File file;
  final void Function(Duration duration)? onReady;

  @override
  State<VideoPreview> createState() => VideoPreviewState();
}

class VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  Duration? _stopAt;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.file.path != widget.file.path) _open();
  }

  Future<void> _open() async {
    final old = _controller;
    old?.removeListener(_onTick);
    await old?.dispose();

    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    _ready = false;
    _failed = false;
    _stopAt = null;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      if (mounted && _controller == controller) {
        setState(() => _ready = true);
        widget.onReady?.call(controller.value.duration);
      }
    } catch (_) {
      if (mounted && _controller == controller) {
        setState(() => _failed = true);
      }
    }
  }

  void _onTick() {
    if (!mounted) return;
    final c = _controller;
    if (c != null && _ready && _stopAt != null) {
      if (c.value.position >= _stopAt!) {
        c.pause();
        _stopAt = null;
      }
    }
    setState(() {});
  }

  /// Jumps to [position] and starts playing.
  Future<void> seekTo(Duration position) async {
    final c = _controller;
    if (c == null || !_ready) return;
    _stopAt = null;
    final end = c.value.duration;
    await c.seekTo(position > end ? end : position);
    await c.play();
  }

  /// Current playback position, or Duration.zero if not ready.
  Duration get position {
    final c = _controller;
    if (c == null || !_ready) return Duration.zero;
    return c.value.position;
  }

  /// Whether the video is currently playing.
  bool get isPlaying => _controller?.value.isPlaying ?? false;

  /// Starts playback from the current position.
  Future<void> play() async {
    final c = _controller;
    if (c == null || !_ready) return;
    await c.play();
  }

  /// Toggles between play and pause.
  Future<void> togglePlayPause() async {
    if (isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Pauses playback if playing.
  Future<void> pause() async {
    final c = _controller;
    if (c == null || !_ready) return;
    _stopAt = null;
    await c.pause();
  }

  /// Total video duration, or Duration.zero if not ready.
  Duration get duration {
    final c = _controller;
    if (c == null || !_ready) return Duration.zero;
    return c.value.duration;
  }

  /// Plays from start to end, pausing automatically at end.
  Future<void> playRange(Duration start, Duration end) async {
    final c = _controller;
    if (c == null || !_ready) return;
    _stopAt = end;
    await c.seekTo(start);
    await c.play();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (_failed) {
      return const _Message('Couldn\'t open this video.');
    }
    if (c == null || !_ready) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final value = c.value;
    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(c),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    iconSize: 32,
                    icon: Icon(
                      value.isPlaying ? Icons.pause : Icons.play_arrow,
                    ),
                    onPressed: () => value.isPlaying ? c.pause() : c.play(),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        VideoProgressIndicator(
          c,
          allowScrubbing: true,
          colors: const VideoProgressColors(
            playedColor: AppColors.accent,
            bufferedColor: AppColors.line,
            backgroundColor: AppColors.line,
          ),
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${formatClock(value.position.inMilliseconds)} / '
            '${formatClock(value.duration.inMilliseconds)}',
            style: AppTheme.mono(size: 12, color: AppColors.muted),
          ),
        ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(text, style: const TextStyle(color: AppColors.accent)),
      ),
    );
  }
}