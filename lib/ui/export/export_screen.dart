import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/export_planner.dart';
import '../core/themes/app_colors.dart';
import 'export_view_model.dart';

class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key, required this.viewModel});

  final ExportViewModel viewModel;

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  ExportViewModel get _vm => widget.viewModel;

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return Scaffold(
            appBar: AppBar(title: Text('Export')),
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_vm.notFound) {
          return Scaffold(
            appBar: AppBar(title: const Text('Export')),
            body: const Center(child: Text('This session no longer exists.')),
          );
        }
        if (_vm.noVideo) {
          return Scaffold(
            appBar: AppBar(title: const Text('Export')),
            body: const Center(child: Text('No video linked to this session.')),
          );
        }
        if (_vm.noClips) {
          return Scaffold(
            appBar: AppBar(title: const Text('Export')),
            body: const Center(child: Text('No clips to export.')),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Export')),
          body: _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    switch (_vm.phase) {
      case ExportPhase.ready:
        return _ReadyView(viewModel: _vm);
      case ExportPhase.running:
        return _RunningView(viewModel: _vm);
      case ExportPhase.done:
        return _DoneView(viewModel: _vm);
    }
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.viewModel});

  final ExportViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final limits = viewModel.limits;
    final clipCount = viewModel.clipExports.length;
    final resolution = limits.maxShortSide >= 1080 ? '1080p' : '720p';
    final watermark = limits.watermark ? 'Made with Clipt watermark' : 'no watermark';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$clipCount clips · $resolution · $watermark',
                style: const TextStyle(fontSize: 16),
              ),
              if (limits.watermark) ...[
                const SizedBox(height: 8),
                const Text(
                  'Pro: 1080p and no watermark.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: viewModel.start,
          child: const Text('Start export'),
        ),
        if (kDebugMode) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              const Text('Debug: act as Pro'),
              const SizedBox(width: 8),
              Switch(
                value: limits.maxShortSide >= 1080,
                onChanged: viewModel.setDebugAsPro,
                activeTrackColor: AppColors.accent,
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _RunningView extends StatelessWidget {
  const _RunningView({required this.viewModel});

  final ExportViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final clipExports = viewModel.clipExports;
    final total = clipExports.length;
    final current = clipExports.indexWhere((c) => c.status == ClipStatus.cutting);
    final currentClip = current >= 0 ? current + 1 : total;

    return Column(
      children: [
        LinearProgressIndicator(value: viewModel.overallProgress),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Clip $currentClip of $total'),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final clipExport in clipExports)
                _ClipProgressTile(clipExport: clipExport),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: TextButton(
            onPressed: viewModel.cancel,
            child: const Text('Cancel'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: Text(
            'Keep Clipt open until the export finishes.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.viewModel});

  final ExportViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final clipExports = viewModel.clipExports;
    final savedCount = clipExports.where((c) => c.savedToGallery).length;
    final totalCount = clipExports.where((c) => c.status == ClipStatus.done).length;
    final hasFailed = clipExports.any((c) => c.status == ClipStatus.failed);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _Card(
          child: Text(
            viewModel.galleryAllowed
                ? 'Saved $savedCount clips to your Photos in the Clipt album'
                : 'Exported $totalCount clips. Allow photo access to save them to your gallery.',
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed: viewModel.shareAll,
          child: const Text('Share all'),
        ),
        const SizedBox(height: 20),
        for (final clipExport in clipExports)
          _DoneClipTile(
            clipExport: clipExport,
            onShare: () => viewModel.shareClip(clipExports.indexOf(clipExport)),
          ),
        if (hasFailed) ...[
          const SizedBox(height: 20),
          FilledButton(
            onPressed: viewModel.retryFailed,
            child: const Text('Retry failed'),
          ),
        ],
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _ClipProgressTile extends StatelessWidget {
  const _ClipProgressTile({required this.clipExport});

  final ClipExport clipExport;

  @override
  Widget build(BuildContext context) {
    final status = clipExport.status;
    IconData icon;
    Color color;

    switch (status) {
      case ClipStatus.waiting:
        icon = Icons.hourglass_empty;
        color = AppColors.muted;
        break;
      case ClipStatus.cutting:
        icon = Icons.more_horiz;
        color = AppColors.accent;
        break;
      case ClipStatus.done:
        icon = Icons.check_circle;
        color = AppColors.accent;
        break;
      case ClipStatus.failed:
        icon = Icons.error;
        color = AppColors.accent;
        break;
      case ClipStatus.cancelled:
        icon = Icons.cancel;
        color = AppColors.muted;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clipFileName(
                    sessionTitle: 'Session',
                    index: 1,
                    tag: clipExport.clip.mark.tag,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
                if (status == ClipStatus.cutting)
                  LinearProgressIndicator(value: clipExport.progress),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneClipTile extends StatelessWidget {
  const _DoneClipTile({
    required this.clipExport,
    required this.onShare,
  });

  final ClipExport clipExport;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final clip = clipExport.clip;
    final status = clipExport.status;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    clipFileName(
                      sessionTitle: 'Session',
                      index: 1,
                      tag: clip.mark.tag,
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (status == ClipStatus.done)
                  IconButton(
                    icon: const Icon(Icons.share, color: AppColors.accent),
                    onPressed: onShare,
                  ),
              ],
            ),
            if (status == ClipStatus.failed && clipExport.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  clipExport.error!,
                  style: const TextStyle(color: AppColors.accent, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
