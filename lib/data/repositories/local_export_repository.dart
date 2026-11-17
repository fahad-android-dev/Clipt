import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/export_planner.dart';
import '../services/ffmpeg_service.dart';
import '../services/gallery_service.dart';
import '../services/share_service.dart';
import '../services/video_info_service.dart';
import 'export_repository.dart';

class LocalExportRepository implements ExportRepository {
  final FfmpegService _ffmpeg = FfmpegService();
  String? _cachedWatermarkPath;

  @override
  Future<VideoInfo> readVideoInfo(File file) async {
    return VideoInfoService.read(file);
  }

  @override
  Future<String?> watermarkPath() async {
    if (_cachedWatermarkPath != null) return _cachedWatermarkPath;

    try {
      final byteData = await rootBundle.load('assets/watermark.png');
      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(p.join(tempDir.path, 'watermark.png'));
      await file.writeAsBytes(bytes);
      _cachedWatermarkPath = file.path;
      return file.path;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Directory> exportDir() async {
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'clipt_export'));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<CutResult> cutClip({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required OutputSize size,
    required int bitrateKbps,
    String? watermarkPath,
    void Function(double fraction)? onProgress,
  }) {
    return _ffmpeg.cutClip(
      inputPath: inputPath,
      outputPath: outputPath,
      startMs: startMs,
      endMs: endMs,
      size: size,
      bitrateKbps: bitrateKbps,
      watermarkPath: watermarkPath,
      onProgress: onProgress,
    );
  }

  @override
  Future<bool> ensureGalleryAccess() async {
    return GalleryService.ensureAccess();
  }

  @override
  Future<void> saveToGallery(String path) async {
    await GalleryService.saveVideo(path);
  }

  @override
  Future<void> shareFiles(List<String> paths, {String? text}) async {
    await ShareService.shareFiles(paths, text: text);
  }

  @override
  Future<void> cancel() async {
    await _ffmpeg.cancel();
  }

  @override
  Future<void> deleteFiles(List<String> paths) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
