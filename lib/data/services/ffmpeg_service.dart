import 'dart:async';
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';

import '../../domain/export_planner.dart';

class CutResult {
  const CutResult({
    required this.success,
    this.logTail,
    required this.encoder,
  });

  final bool success;
  final String? logTail;
  final String encoder;
}

class FfmpegService {
  Future<CutResult> cutClip({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required OutputSize size,
    required int bitrateKbps,
    String? watermarkPath,
    void Function(double fraction)? onProgress,
  }) async {
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    final lengthMs = endMs - startMs;
    final startSeconds = startMs / 1000;
    final lengthSeconds = lengthMs / 1000;

    String format(double n) => n.toStringAsFixed(3).replaceAll(',', '.');

    final startArg = format(startSeconds);
    final lengthArg = format(lengthSeconds);
    final width = size.width;
    final height = size.height;
    final bitrateArg = '${bitrateKbps}k';

    // Try hardware encoder first
    final encoder = Platform.isIOS ? 'h264_videotoolbox' : 'h264_mediacodec';
    final result = await _tryCut(
      inputPath: inputPath,
      outputPath: outputPath,
      startArg: startArg,
      lengthArg: lengthArg,
      width: width,
      height: height,
      bitrateArg: bitrateArg,
      encoder: encoder,
      watermarkPath: watermarkPath,
      onProgress: onProgress,
      clipLengthMs: lengthMs,
    );

    if (result.success) return result;

    // Fallback to software encoder
    return await _tryCut(
      inputPath: inputPath,
      outputPath: outputPath,
      startArg: startArg,
      lengthArg: lengthArg,
      width: width,
      height: height,
      bitrateArg: bitrateArg,
      encoder: 'mpeg4',
      watermarkPath: watermarkPath,
      onProgress: onProgress,
      clipLengthMs: lengthMs,
      isSoftware: true,
    );
  }

  Future<CutResult> _tryCut({
    required String inputPath,
    required String outputPath,
    required String startArg,
    required String lengthArg,
    required int width,
    required int height,
    required String bitrateArg,
    required String encoder,
    String? watermarkPath,
    void Function(double fraction)? onProgress,
    required int clipLengthMs,
    bool isSoftware = false,
  }) async {
    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    String command;
    if (watermarkPath != null) {
      // With watermark overlay
      final watermarkWidth = ((width * 0.32).round() / 2 * 2);
      command =
          '-y -ss $startArg -i "$inputPath" -i "$watermarkPath" -t $lengthArg '
          '-filter_complex "[0:v]scale=$width:$height[base];[1:v]scale=$watermarkWidth:-1[wm];[base][wm]overlay=main_w-overlay_w-24:main_h-overlay_h-24[v]" '
          '-map "[v]" -map 0:a:0? '
          '-c:v $encoder -b:v $bitrateArg -pix_fmt yuv420p '
          '-c:a aac -b:a 128k -movflags +faststart "$outputPath"';
    } else {
      // Without watermark
      if (isSoftware) {
        command =
            '-y -ss $startArg -i "$inputPath" -t $lengthArg '
            '-vf "scale=$width:$height" '
            '-c:v mpeg4 -q:v 3 '
            '-map 0:v:0 -map 0:a:0? '
            '-c:a aac -b:a 128k -movflags +faststart "$outputPath"';
      } else {
        command =
            '-y -ss $startArg -i "$inputPath" -t $lengthArg '
            '-vf "scale=$width:$height" '
            '-c:v $encoder -b:v $bitrateArg -pix_fmt yuv420p '
            '-map 0:v:0 -map 0:a:0? '
            '-c:a aac -b:a 128k -movflags +faststart "$outputPath"';
      }
    }

    try {
      final completer = Completer<CutResult>();
      await FFmpegKit.executeAsync(
        command,
        (session) async {
          final returnCode = await session.getReturnCode();
          if (ReturnCode.isSuccess(returnCode)) {
            completer.complete(CutResult(
              success: true,
              encoder: encoder,
            ));
          } else {
            // Get log tail
            final logs = await session.getLogs();
            final lines = <String>[];
            for (final log in logs) {
              lines.add(log.getMessage().toString());
            }
            final tail = lines.length > 20 ? lines.sublist(lines.length - 20) : lines;
            // Delete partial output
            if (await outputFile.exists()) {
              await outputFile.delete();
            }
            completer.complete(CutResult(
              success: false,
              logTail: tail.join('\n'),
              encoder: encoder,
            ));
          }
        },
        null, // log callback
        (statistics) {
          if (onProgress != null) {
            final time = statistics.getTime();
            final fraction = (time / clipLengthMs).clamp(0.0, 1.0);
            onProgress(fraction);
          }
        },
      );
      return await completer.future;
    } catch (e) {
      if (await outputFile.exists()) {
        await outputFile.delete();
      }
      return CutResult(
        success: false,
        logTail: 'Exception: $e',
        encoder: encoder,
      );
    }
  }

  Future<void> cancel() async {
    await FFmpegKit.cancel();
  }
}
