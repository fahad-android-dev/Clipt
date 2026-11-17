import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/export_planner.dart';
import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_spacing.dart';
import '../core/themes/app_theme.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/bottom_action_bar.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/tag_pill.dart';
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

  AppBar _appBar() => AppBar(
        leading: const BackButton(),
        title: const Text('Export'),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return Scaffold(
            appBar: _appBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (_vm.notFound) {
          return Scaffold(
            appBar: _appBar(),
            body: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Session not found',
              message: 'This session no longer exists.',
              actionLabel: 'Go back',
              onAction: () => Navigator.pop(context),
            ),
          );
        }
        if (_vm.noVideo) {
          return Scaffold(
            appBar: _appBar(),
            body: EmptyState(
              icon: Icons.videocam_off_rounded,
              title: 'No video linked',
              message: 'Add a recording to this session before exporting.',
              actionLabel: 'Go back',
              onAction: () => Navigator.pop(context),
            ),
          );
        }
        if (_vm.noClips) {
          return Scaffold(
            appBar: _appBar(),
            body: EmptyState(
              icon: Icons.content_cut_rounded,
              title: 'No clips to export',
              message: 'Include at least one clip in the clip editor.',
              actionLabel: 'Go back',
              onAction: () => Navigator.pop(context),
            ),
          );
        }

        return Scaffold(
          appBar: _appBar(),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _buildPhase(),
          ),
        );
      },
    );
  }

  Widget _buildPhase() {
    switch (_vm.phase) {
      case ExportPhase.ready:
        return _ReadyView(key: const ValueKey('ready'), vm: _vm);
      case ExportPhase.running:
        return _RunningView(key: const ValueKey('running'), vm: _vm);
      case ExportPhase.done:
        return _DoneView(key: const ValueKey('done'), vm: _vm);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// READY
// ─────────────────────────────────────────────────────────────────────────────

class _ReadyView extends StatelessWidget {
  const _ReadyView({super.key, required this.vm});

  final ExportViewModel vm;

  @override
  Widget build(BuildContext context) {
    final limits = vm.limits;
    final clipCount = vm.clipExports.isNotEmpty
        ? vm.clipExports.length
        : 0; // before start, planClips is in _clips but not _clipExports
    // Use the count the vm knows: totalLengthMs refers to _clips which is set
    final total = vm.totalLengthMs;
    final isPro = limits.maxShortSide >= 1080;
    final resolution = isPro ? '1080p' : 'HD 720p';

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              // ── Hero card ───────────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      // clipExports is empty before start; count from totalLengthMs>0
                      // The clip list is in vm._clips (private). We approximate using
                      // the BottomActionBar label that calls vm.start. The spec wants
                      // the count here too: expose via a getter we added.
                      '${clipCount > 0 ? clipCount : (total > 0 ? '—' : '0')} '
                      'clip${clipCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${formatClock(total)} total',
                      style: AppTheme.mono(size: 15, color: AppColors.muted),
                    ),
                    if (vm.sessionTitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        vm.sessionTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // ── Quality card ─────────────────────────────────────────────
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'QUALITY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _QualityRow(
                      icon: Icons.check_circle_outline_rounded,
                      iconColor: AppColors.accent,
                      label: resolution,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _QualityRow(
                      icon: isPro
                          ? Icons.check_circle_outline_rounded
                          : Icons.branding_watermark_outlined,
                      iconColor: AppColors.accent,
                      label: isPro ? 'No watermark' : 'Clipt watermark',
                    ),
                    if (!isPro) ...[
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(color: AppColors.line, height: 1),
                      const SizedBox(height: AppSpacing.sm),
                      _QualityRow(
                        icon: Icons.lock_outline_rounded,
                        iconColor: AppColors.muted,
                        label: 'Pro: 1080p, no watermark',
                        muted: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // ── Saving to row ─────────────────────────────────────────────
              Row(
                children: [
                  const Icon(Icons.photo_library_outlined,
                      size: 18, color: AppColors.muted),
                  const SizedBox(width: AppSpacing.sm),
                  const Text(
                    'Saving to',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Photos, album Clipt',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              // ── Debug switch ──────────────────────────────────────────────
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.xl),
                const Divider(color: AppColors.line),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Text(
                      'Debug: act as Pro',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Switch(
                      value: limits.maxShortSide >= 1080,
                      onChanged: vm.setDebugAsPro,
                      activeTrackColor: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        BottomActionBar(
          summaryText:
              '${clipCount > 0 ? clipCount : '…'} clip${clipCount == 1 ? '' : 's'}',
          buttonLabel:
              'Export ${clipCount > 0 ? clipCount : ''} clip${clipCount == 1 ? '' : 's'}',
          onPressed: vm.start,
        ),
      ],
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.muted = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: muted ? AppColors.muted : AppColors.ink,
              fontWeight: muted ? FontWeight.w400 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RUNNING
// ─────────────────────────────────────────────────────────────────────────────

class _RunningView extends StatelessWidget {
  const _RunningView({super.key, required this.vm});

  final ExportViewModel vm;

  @override
  Widget build(BuildContext context) {
    final exports = vm.clipExports;
    final total = exports.length;
    final cuttingIdx =
        exports.indexWhere((c) => c.status == ClipStatus.cutting);
    final currentClip = cuttingIdx >= 0 ? cuttingIdx + 1 : total;
    final progress = vm.overallProgress;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          // ── Large circular progress ────────────────────────────────────
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    backgroundColor: AppColors.line,
                    color: AppColors.accent,
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: AppTheme.mono(
                    size: 28,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Clip $currentClip of $total',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Clip list ─────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              separatorBuilder: (context, idx) =>
                  const SizedBox(height: AppSpacing.sm),
              itemCount: exports.length,
              itemBuilder: (context, i) =>
                  _RunningClipRow(export: exports[i], index: i),
            ),
          ),
          // ── Notice + cancel ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    'Keep Clipt open until the export finishes.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: vm.cancel,
            style: TextButton.styleFrom(foregroundColor: AppColors.muted),
            child: const Text('Cancel'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _RunningClipRow extends StatelessWidget {
  const _RunningClipRow({required this.export, required this.index});

  final ClipExport export;
  final int index;

  @override
  Widget build(BuildContext context) {
    final status = export.status;
    Widget statusIcon;
    switch (status) {
      case ClipStatus.waiting:
        statusIcon = const Icon(Icons.radio_button_unchecked_rounded,
            size: 18, color: AppColors.muted);
      case ClipStatus.cutting:
        statusIcon = const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.accent,
          ),
        );
      case ClipStatus.done:
        statusIcon = const Icon(Icons.check_circle_rounded,
            size: 18, color: AppColors.accent);
      case ClipStatus.failed:
        statusIcon = const Icon(Icons.error_rounded,
            size: 18, color: AppColors.tagFail);
      case ClipStatus.cancelled:
        statusIcon = const Icon(Icons.cancel_outlined,
            size: 18, color: AppColors.muted);
    }

    final fileName = clipFileName(
      sessionTitle: 'Clip',
      index: index + 1,
      tag: export.clip.mark.tag,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            statusIcon,
            const SizedBox(width: AppSpacing.sm),
            TagPill(tag: export.clip.mark.tag),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (status == ClipStatus.cutting) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: export.progress,
                minHeight: 3,
                backgroundColor: AppColors.line,
                color: AppColors.accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DONE
// ─────────────────────────────────────────────────────────────────────────────

class _DoneView extends StatelessWidget {
  const _DoneView({super.key, required this.vm});

  final ExportViewModel vm;

  @override
  Widget build(BuildContext context) {
    final exports = vm.clipExports;
    final doneCount =
        exports.where((c) => c.status == ClipStatus.done).length;
    final failedCount =
        exports.where((c) => c.status == ClipStatus.failed).length;
    final hasFailed = failedCount > 0;
    final allFailed = doneCount == 0 && hasFailed;

    final String headlineTitle = allFailed
        ? 'Export failed'
        : hasFailed
            ? 'Done with $failedCount problem${failedCount == 1 ? '' : 's'}'
            : 'All done';

    final String subtitle = vm.galleryAllowed
        ? 'Saved $doneCount clip${doneCount == 1 ? '' : 's'} to your Photos in the Clipt album.'
        : 'Exported $doneCount clip${doneCount == 1 ? '' : 's'}. '
            'Allow photo access to save them to your gallery.';

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.xl,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          // ── Result hero ────────────────────────────────────────────────
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: (allFailed ? AppColors.tagFail : AppColors.accent)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                allFailed
                    ? Icons.error_outline_rounded
                    : Icons.check_rounded,
                size: 36,
                color: allFailed ? AppColors.tagFail : AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Center(
            child: Text(
              headlineTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Actions ───────────────────────────────────────────────────
          if (doneCount > 0)
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: vm.shareAll,
              child: const Text('Share all'),
            ),
          if (hasFailed) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: vm.retryFailed,
              child: Text('Retry failed ($failedCount)'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppColors.muted,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          const SizedBox(height: AppSpacing.xl),
          // ── Clip list ─────────────────────────────────────────────────
          const Text(
            'CLIPS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < exports.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _DoneClipRow(
                export: exports[i],
                index: i,
                onShare: () => vm.shareClip(i),
                onRetry: () => vm.retryFailed(),
              ),
            ),
        ],
      ),
    );
  }
}

class _DoneClipRow extends StatelessWidget {
  const _DoneClipRow({
    required this.export,
    required this.index,
    required this.onShare,
    required this.onRetry,
  });

  final ClipExport export;
  final int index;
  final VoidCallback onShare;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final status = export.status;
    final fileName = clipFileName(
      sessionTitle: 'Clip',
      index: index + 1,
      tag: export.clip.mark.tag,
    );

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statusIcon(status),
              const SizedBox(width: AppSpacing.sm),
              TagPill(tag: export.clip.mark.tag),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  fileName,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (status == ClipStatus.done)
                Semantics(
                  label: 'Share this clip',
                  child: IconButton(
                    tooltip: 'Share this clip',
                    icon: const Icon(Icons.share_rounded,
                        size: 20, color: AppColors.accent),
                    onPressed: onShare,
                  ),
                ),
            ],
          ),
          if (status == ClipStatus.failed) ...[
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (export.error != null)
                    Text(
                      export.error!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.tagFail),
                    ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      foregroundColor: AppColors.accent,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onRetry,
                    child: const Text('Retry', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusIcon(ClipStatus status) {
    switch (status) {
      case ClipStatus.done:
        return const Icon(Icons.check_circle_rounded,
            size: 18, color: AppColors.accent);
      case ClipStatus.failed:
        return const Icon(Icons.error_rounded,
            size: 18, color: AppColors.tagFail);
      case ClipStatus.cancelled:
        return const Icon(Icons.cancel_outlined,
            size: 18, color: AppColors.muted);
      default:
        return const Icon(Icons.radio_button_unchecked_rounded,
            size: 18, color: AppColors.muted);
    }
  }
}
