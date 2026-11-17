import 'dart:io';

import 'package:video_player/video_player.dart';

class VideoInfo {
  const VideoInfo({
    required this.durationMs,
    required this.width,
    required this.height,
  });

  final int durationMs;
  final int width;
  final int height;
}

class VideoInfoService {
  /// Reads video info using VideoPlayerController.
  /// The controller is disposed after reading.
  static Future<VideoInfo> read(File file) async {
    final controller = VideoPlayerController.file(file);
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      final size = controller.value.size;
      return VideoInfo(
        durationMs: duration.inMilliseconds,
        width: size.width.toInt(),
        height: size.height.toInt(),
      );
    } finally {
      await controller.dispose();
    }
  }
}
