import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../data/repositories/export_repository.dart';
import '../../../data/repositories/entitlement_repository.dart';
import '../../../data/repositories/session_repository.dart';
import '../../../data/repositories/video_repository.dart';
import '../../../data/services/video_info_service.dart';
import '../../../domain/clip_planner.dart';
import '../../../domain/export_planner.dart';
import '../../../domain/models/export_limits.dart';
import '../../../domain/models/session.dart';

enum ExportPhase { ready, running, done }

enum ClipStatus { waiting, cutting, done, failed, cancelled }

class ClipExport {
  const ClipExport({
    required this.clip,
    this.status = ClipStatus.waiting,
    this.progress = 0.0,
    this.outputPath,
    this.savedToGallery = false,
    this.error,
  });

  final PlannedClip clip;
  final ClipStatus status;
  final double progress;
  final String? outputPath;
  final bool savedToGallery;
  final String? error;

  ClipExport copyWith({
    ClipStatus? status,
    double? progress,
    String? outputPath,
    bool? savedToGallery,
    String? error,
  }) {
    return ClipExport(
      clip: clip,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      outputPath: outputPath ?? this.outputPath,
      savedToGallery: savedToGallery ?? this.savedToGallery,
      error: error ?? this.error,
    );
  }
}

class ExportViewModel extends ChangeNotifier {
  ExportViewModel({
    required SessionRepository sessionRepository,
    required VideoRepository videoRepository,
    required ExportRepository exportRepository,
    required EntitlementRepository entitlementRepository,
    required this.sessionId,
  })  : _sessionRepo = sessionRepository,
        _videoRepo = videoRepository,
        _exportRepo = exportRepository,
        _entitlementRepo = entitlementRepository;

  final SessionRepository _sessionRepo;
  final VideoRepository _videoRepo;
  final ExportRepository _exportRepo;
  final EntitlementRepository _entitlementRepo;
  final int sessionId;

  Session? _session;
  List<PlannedClip> _clips = const [];
  File? _video;
  VideoInfo? _videoInfo;
  ExportLimits _limits = ExportLimits.free;
  bool _loading = true;
  bool _notFound = false;
  bool _noVideo = false;
  bool _noClips = false;
  ExportPhase _phase = ExportPhase.ready;
  List<ClipExport> _clipExports = const [];
  double _overallProgress = 0.0;
  bool _galleryAllowed = false;
  String? _error;

  bool get isLoading => _loading;
  bool get notFound => _notFound;
  bool get noVideo => _noVideo;
  bool get noClips => _noClips;
  ExportPhase get phase => _phase;
  List<ClipExport> get clipExports => _clipExports;
  double get overallProgress => _overallProgress;
  bool get galleryAllowed => _galleryAllowed;
  ExportLimits get limits => _limits;
  String? get errorMessage => _error;

  Future<void> load() async {
    try {
      final session = await _sessionRepo.getSession(sessionId);
      if (session == null) {
        _notFound = true;
      } else {
        _session = session;
        final marks = await _sessionRepo.getMarks(sessionId);
        final edits = await _sessionRepo.getClipEdits(sessionId);
        final videoName = session.videoFile;
        if (videoName != null) {
          final file = await _videoRepo.resolve(videoName);
          if (await file.exists()) {
            _video = file;
            _videoInfo = await _exportRepo.readVideoInfo(file);
          }
        }
        _limits = await _entitlementRepo.exportLimits();

        final planned = planClips(
          marks: marks,
          edits: edits,
          syncOffsetMs: session.syncOffsetMs,
          delaySeconds: session.delaySeconds,
          videoDurationMs: _videoInfo?.durationMs,
        );
        _clips = planned.where((c) => c.included).toList();

        if (_video == null) {
          _noVideo = true;
        } else if (_clips.isEmpty) {
          _noClips = true;
        }
      }
    } catch (_) {
      _notFound = true;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> start() async {
    _phase = ExportPhase.running;
    _galleryAllowed = await _exportRepo.ensureGalleryAccess();
    _error = null;
    notifyListeners();

    if (_video == null || _clips.isEmpty) return;

    await WakelockPlus.enable();

    final exportDir = await _exportRepo.exportDir();
    final watermarkPath = _limits.watermark ? await _exportRepo.watermarkPath() : null;

    _clipExports = _clips
        .map((clip) => ClipExport(clip: clip))
        .toList(growable: false);
    notifyListeners();

    for (var i = 0; i < _clipExports.length; i++) {
      final clipExport = _clipExports[i];
      if (clipExport.status == ClipStatus.cancelled) continue;

      _clipExports[i] = clipExport.copyWith(status: ClipStatus.cutting);
      notifyListeners();

      final clip = clipExport.clip;
      final size = outputSize(
        width: _videoInfo!.width,
        height: _videoInfo!.height,
        maxShortSide: _limits.maxShortSide,
      );
      final bitrate = bitrateKbpsFor(size);
      final fileName = clipFileName(
        sessionTitle: _session!.title,
        index: i + 1,
        tag: clip.mark.tag,
      );
      final outputPath = '${exportDir.path}/$fileName';

      try {
        final result = await _exportRepo.cutClip(
          inputPath: _video!.path,
          outputPath: outputPath,
          startMs: clip.startMs,
          endMs: clip.endMs,
          size: size,
          bitrateKbps: bitrate,
          watermarkPath: watermarkPath,
          onProgress: (fraction) {
            _clipExports[i] = _clipExports[i].copyWith(progress: fraction);
            _overallProgress = (i + fraction) / _clipExports.length;
            notifyListeners();
          },
        );

        if (result.success) {
          var saved = false;
          if (_galleryAllowed) {
            try {
              await _exportRepo.saveToGallery(outputPath);
              saved = true;
            } catch (_) {
              // Gallery save failed, but export succeeded
            }
          }
          _clipExports[i] = _clipExports[i].copyWith(
            status: ClipStatus.done,
            outputPath: outputPath,
            savedToGallery: saved,
            progress: 1.0,
          );
        } else {
          _clipExports[i] = _clipExports[i].copyWith(
            status: ClipStatus.failed,
            error: 'Encoding failed',
          );
        }
      } catch (e) {
        _clipExports[i] = _clipExports[i].copyWith(
          status: ClipStatus.failed,
          error: 'Error: $e',
        );
      }

      _overallProgress = (i + 1) / _clipExports.length;
      notifyListeners();
    }

    await WakelockPlus.disable();
    _phase = ExportPhase.done;
    notifyListeners();
  }

  Future<void> cancel() async {
    await _exportRepo.cancel();
    for (var i = 0; i < _clipExports.length; i++) {
      if (_clipExports[i].status == ClipStatus.cutting ||
          _clipExports[i].status == ClipStatus.waiting) {
        _clipExports[i] = _clipExports[i].copyWith(status: ClipStatus.cancelled);
      }
    }
    notifyListeners();
  }

  Future<void> retryFailed() async {
    final failedIndices = <int>[];
    for (var i = 0; i < _clipExports.length; i++) {
      if (_clipExports[i].status == ClipStatus.failed) {
        failedIndices.add(i);
      }
    }

    if (failedIndices.isEmpty) return;

    _phase = ExportPhase.running;
    _error = null;
    notifyListeners();

    await WakelockPlus.enable();

    final exportDir = await _exportRepo.exportDir();
    final watermarkPath = _limits.watermark ? await _exportRepo.watermarkPath() : null;

    for (final i in failedIndices) {
      _clipExports[i] = _clipExports[i].copyWith(
        status: ClipStatus.cutting,
        progress: 0.0,
        error: null,
      );
      notifyListeners();

      final clip = _clipExports[i].clip;
      final size = outputSize(
        width: _videoInfo!.width,
        height: _videoInfo!.height,
        maxShortSide: _limits.maxShortSide,
      );
      final bitrate = bitrateKbpsFor(size);
      final fileName = clipFileName(
        sessionTitle: _session!.title,
        index: i + 1,
        tag: clip.mark.tag,
      );
      final outputPath = '${exportDir.path}/$fileName';

      try {
        final result = await _exportRepo.cutClip(
          inputPath: _video!.path,
          outputPath: outputPath,
          startMs: clip.startMs,
          endMs: clip.endMs,
          size: size,
          bitrateKbps: bitrate,
          watermarkPath: watermarkPath,
          onProgress: (fraction) {
            _clipExports[i] = _clipExports[i].copyWith(progress: fraction);
            notifyListeners();
          },
        );

        if (result.success) {
          var saved = false;
          if (_galleryAllowed) {
            try {
              await _exportRepo.saveToGallery(outputPath);
              saved = true;
            } catch (_) {}
          }
          _clipExports[i] = _clipExports[i].copyWith(
            status: ClipStatus.done,
            outputPath: outputPath,
            savedToGallery: saved,
            progress: 1.0,
          );
        } else {
          _clipExports[i] = _clipExports[i].copyWith(
            status: ClipStatus.failed,
            error: 'Encoding failed',
          );
        }
      } catch (e) {
        _clipExports[i] = _clipExports[i].copyWith(
          status: ClipStatus.failed,
          error: 'Error: $e',
        );
      }

      notifyListeners();
    }

    await WakelockPlus.disable();
    _phase = ExportPhase.done;
    notifyListeners();
  }

  Future<void> shareClip(int index) async {
    final clipExport = _clipExports[index];
    if (clipExport.outputPath == null) return;
    await _exportRepo.shareFiles([clipExport.outputPath!]);
  }

  Future<void> shareAll() async {
    final paths = <String>[];
    for (final clipExport in _clipExports) {
      if (clipExport.outputPath != null && clipExport.status == ClipStatus.done) {
        paths.add(clipExport.outputPath!);
      }
    }
    if (paths.isNotEmpty) {
      await _exportRepo.shareFiles(paths);
    }
  }

  void setDebugAsPro(bool value) {
    if (!kDebugMode) return;
    final stub = _entitlementRepo as StubEntitlementRepository;
    stub.debugPro = value;
    load();
  }

  @override
  void dispose() {
    super.dispose();
    // Clean up temp files
    final paths = <String>[];
    for (final clipExport in _clipExports) {
      if (clipExport.outputPath != null) {
        paths.add(clipExport.outputPath!);
      }
    }
    if (paths.isNotEmpty) {
      _exportRepo.deleteFiles(paths);
    }
  }
}
