import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class FfmpegTestResult {
  const FfmpegTestResult({
    required this.name,
    required this.success,
    required this.took,
    this.outputBytes,
    this.outputSeconds,
    this.logTail,
    this.outputPath,
  });

  final String name;
  final bool success;
  final Duration took;
  final int? outputBytes;
  final double? outputSeconds;
  final String? logTail;
  final String? outputPath;
}

class FfmpegLabService {
  /// Length of a media file in seconds, read with FFprobe. Null if unknown.
  /// (Not session.getDuration(): that is how long the FFprobe job itself took.)
  Future<double?> _readSeconds(String path) async {
    final session = await FFprobeKit.getMediaInformation(path);
    final info = session.getMediaInformation();
    if (info == null) return null;

    final text = info.getDuration();
    if (text != null) return double.tryParse(text);

    final format = info.getAllProperties()?['format'];
    if (format is Map) return double.tryParse('${format['duration']}');
    return null;
  }

  Future<FfmpegTestResult> run({
    required String name,
    required String command,
    required String outputPath,
  }) async {
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final stopwatch = Stopwatch()..start();
    try {
      final session = await FFmpegKit.execute(command);
      stopwatch.stop();

      final returnCode = await session.getReturnCode();
      if (ReturnCode.isSuccess(returnCode)) {
        return FfmpegTestResult(
          name: name,
          success: true,
          took: stopwatch.elapsed,
          outputBytes: await outputFile.length(),
          outputSeconds: await _readSeconds(outputPath),
          outputPath: outputPath,
        );
      }

      // FFmpeg prints the real error at the end, so keep the LAST 20 lines.
      final logs = await session.getLogs();
      final lines = <String>[];
      for (final log in logs) {
        lines.add(log.getMessage().toString());
      }
      final tail = lines.length > 20 ? lines.sublist(lines.length - 20) : lines;
      return FfmpegTestResult(
        name: name,
        success: false,
        took: stopwatch.elapsed,
        logTail: tail.join('\n'),
      );
    } catch (e) {
      stopwatch.stop();
      return FfmpegTestResult(
        name: name,
        success: false,
        took: stopwatch.elapsed,
        logTail: 'Exception: $e',
      );
    }
  }

  Future<List<FfmpegTestResult>> runAll({
    required String inputPath,
    required double startSeconds,
    required double lengthSeconds,
  }) async {
    // One folder, reused every run, so old test files don't pile up.
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'ffmpeg_lab'));
    await dir.create(recursive: true);

    String format(double n) => n.toStringAsFixed(3).replaceAll(',', '.');
    final startArg = format(startSeconds);
    final lengthArg = format(lengthSeconds);
    final results = <FfmpegTestResult>[];

    // Test A: fast cut. Copies the data without re-encoding.
    final fastPath = p.join(dir.path, 'lab_fast.mp4');
    results.add(
      await run(
        name: 'Fast cut (stream copy)',
        command:
            '-y -ss $startArg -i "$inputPath" -t $lengthArg -c copy '
            '-avoid_negative_ts make_zero -movflags +faststart "$fastPath"',
        outputPath: fastPath,
      ),
    );

    // Test B: precise cut with the phone's hardware video encoder.
    final precisePath = p.join(dir.path, 'lab_precise.mp4');
    final encoder = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    results.add(
      await run(
        name: 'Precise cut (hardware encoder)',
        command:
            '-y -ss $startArg -i "$inputPath" -t $lengthArg '
            '-c:v $encoder -b:v 8M -pix_fmt yuv420p -c:a aac -b:a 128k '
            '-movflags +faststart "$precisePath"',
        outputPath: precisePath,
      ),
    );

    // Test C: precise cut with the built-in software encoder (fallback).
    final softwarePath = p.join(dir.path, 'lab_software.mp4');
    results.add(
      await run(
        name: 'Precise cut (software mpeg4 fallback)',
        command:
            '-y -ss $startArg -i "$inputPath" -t $lengthArg '
            '-c:v mpeg4 -q:v 3 -c:a aac -b:a 128k '
            '-movflags +faststart "$softwarePath"',
        outputPath: softwarePath,
      ),
    );

    return results;
  }
}
