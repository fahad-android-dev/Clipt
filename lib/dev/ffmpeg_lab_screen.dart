import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../ui/core/themes/app_colors.dart';
import '../ui/core/themes/app_theme.dart';
import '../ui/core/widgets/video_preview.dart';
import 'ffmpeg_lab_service.dart';

class FfmpegLabScreen extends StatefulWidget {
  const FfmpegLabScreen({super.key});

  @override
  State<FfmpegLabScreen> createState() => _FfmpegLabScreenState();
}

class _FfmpegLabScreenState extends State<FfmpegLabScreen> {
  final _service = FfmpegLabService();
  final _startController = TextEditingController(text: '5');
  final _lengthController = TextEditingController(text: '10');

  List<PlatformFile>? _pickedFiles;
  List<FfmpegTestResult> _results = [];
  bool _running = false;
  String? _currentTest;
  File? _previewFile;

  @override
  void dispose() {
    _startController.dispose();
    _lengthController.dispose();
    super.dispose();
  }

  String get _platform => Platform.isIOS ? 'iOS' : 'Android';

  bool get _canRun =>
      _pickedFiles != null &&
      _pickedFiles!.isNotEmpty &&
      !_running &&
      _startController.text.isNotEmpty &&
      _lengthController.text.isNotEmpty;

  Future<void> _pickVideo() async {
    final result = await FilePicker.pickFiles(type: FileType.video);
    if (result.isEmpty) return;
    setState(() => _pickedFiles = result);
  }

  Future<void> _runAll() async {
    final start = double.tryParse(_startController.text);
    final length = double.tryParse(_lengthController.text);

    if (start == null || length == null || length <= 0 || start < 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid start or length values')),
      );
      return;
    }

    setState(() {
      _running = true;
      _results = [];
      _previewFile = null;
    });

    try {
      final inputPath = _pickedFiles!.first.path!;
      final results = await _service.runAll(
        inputPath: inputPath,
        startSeconds: start,
        lengthSeconds: length,
      );

      setState(() => _results = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _running = false);
    }
  }

  Future<void> _playResult(FfmpegTestResult result) async {
    if (result.outputPath == null) return;
    final file = File(result.outputPath!);
    if (await file.exists()) {
      setState(() => _previewFile = file);
    }
  }

  Future<void> _copyResults() async {
    final input = _pickedFiles?.first;
    String inputSize = 'N/A';
    if (input != null) {
      final size = await input.length();
      if (size != null) {
        inputSize = (size / (1024 * 1024)).toStringAsFixed(1);
      }
    }
    final start = _startController.text;
    final length = _lengthController.text;

    final buffer = StringBuffer();
    buffer.writeln('Platform: $_platform');
    buffer.writeln('Input file: ${input?.name ?? "N/A"} ($inputSize MB)');
    buffer.writeln('Start: $start seconds');
    buffer.writeln('Length: $length seconds');
    buffer.writeln();

    for (final result in _results) {
      buffer.writeln('Test: ${result.name}');
      buffer.writeln('Status: ${result.success ? "OK" : "FAILED"}');
      buffer.writeln('Time: ${(result.took.inMilliseconds / 1000).toStringAsFixed(1)} s');
      if (result.outputBytes != null) {
        buffer.writeln('Output size: ${(result.outputBytes! / (1024 * 1024)).toStringAsFixed(1)} MB');
      }
      if (result.outputSeconds != null) {
        buffer.writeln('Output length: ${result.outputSeconds!.toStringAsFixed(2)} s');
      }
      if (result.logTail != null) {
        buffer.writeln('Log tail:');
        buffer.writeln(result.logTail);
      }
      buffer.writeln();
    }

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Results copied to clipboard')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FFmpeg Lab')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Platform: $_platform',
                style: AppTheme.mono(size: 14, color: AppColors.muted)),
            const SizedBox(height: 16),
            _VideoPickerSection(
              pickedFiles: _pickedFiles,
              onPick: _pickVideo,
            ),
            const SizedBox(height: 16),
            _NumberFields(
              startController: _startController,
              lengthController: _lengthController,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _canRun ? _runAll : null,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_running
                  ? 'Running: $_currentTest'
                  : 'Run all 3 tests'),
            ),
            const SizedBox(height: 24),
            if (_previewFile != null) ...[
              const Text('Preview',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Card(
                child: VideoPreview(file: _previewFile!),
              ),
              const SizedBox(height: 24),
            ],
            ..._results.map((r) => _ResultCard(
                  result: r,
                  onPlay: () => _playResult(r),
                )),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _results.isNotEmpty ? _copyResults : null,
              icon: const Icon(Icons.copy),
              label: const Text('Copy results'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPickerSection extends StatelessWidget {
  const _VideoPickerSection({
    required this.pickedFiles,
    required this.onPick,
  });

  final List<PlatformFile>? pickedFiles;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final file = pickedFiles?.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ElevatedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.video_library_outlined),
          label: const Text('Pick video'),
        ),
        if (file != null) ...[
          const SizedBox(height: 8),
          Text('File: ${file.name}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          _FileSize(file: file),
        ],
      ],
    );
  }
}

class _FileSize extends StatelessWidget {
  const _FileSize({required this.file});

  final PlatformFile file;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int?>(
      future: file.length(),
      builder: (_, snapshot) {
        final size = snapshot.data;
        if (size == null) return const SizedBox.shrink();
        final sizeMB = (size / (1024 * 1024)).toStringAsFixed(1);
        return Text('Size: $sizeMB MB',
            style: AppTheme.mono(size: 12, color: AppColors.muted));
      },
    );
  }
}

class _NumberFields extends StatelessWidget {
  const _NumberFields({
    required this.startController,
    required this.lengthController,
  });

  final TextEditingController startController;
  final TextEditingController lengthController;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: startController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Start (seconds)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: lengthController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Length (seconds)',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onPlay,
  });

  final FfmpegTestResult result;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(result.name,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (result.success)
                  Text('OK',
                      style: const TextStyle(
                          color: Colors.green, fontWeight: FontWeight.w700))
                else
                  Text('FAILED',
                      style: const TextStyle(
                          color: AppColors.accent, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Time: ${(result.took.inMilliseconds / 1000).toStringAsFixed(1)} s',
                style: AppTheme.mono(size: 12, color: AppColors.muted)),
            if (result.outputBytes != null)
              Text('Size: ${(result.outputBytes! / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: AppTheme.mono(size: 12, color: AppColors.muted)),
            if (result.outputSeconds != null)
              Text('Length: ${result.outputSeconds!.toStringAsFixed(2)} s',
                  style: AppTheme.mono(size: 12, color: AppColors.muted)),
            if (result.logTail != null) ...[
              const SizedBox(height: 8),
              Container(
                height: 100,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(result.logTail!,
                      style: AppTheme.mono(size: 10)),
                ),
              ),
            ],
            if (result.success && result.outputPath != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
