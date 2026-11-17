import 'dart:io';

import '../../domain/export_planner.dart';
import '../services/ffmpeg_service.dart';
import '../services/video_info_service.dart';

abstract class ExportRepository {
  Future<VideoInfo> readVideoInfo(File file);
  Future<String?> watermarkPath();
  Future<Directory> exportDir();
  Future<CutResult> cutClip({
    required String inputPath,
    required String outputPath,
    required int startMs,
    required int endMs,
    required OutputSize size,
    required int bitrateKbps,
    String? watermarkPath,
    void Function(double fraction)? onProgress,
  });
  Future<bool> ensureGalleryAccess();
  Future<void> saveToGallery(String path);
  Future<void> shareFiles(List<String> paths, {String? text});
  Future<void> cancel();
  Future<void> deleteFiles(List<String> paths);
}
