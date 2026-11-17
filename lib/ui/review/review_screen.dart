import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/mark.dart';
import '../../domain/models/mark_tags.dart';
import '../../routing/routes.dart';
import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_spacing.dart';
import '../core/themes/app_theme.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/tag_pill.dart';
import '../core/widgets/video_preview.dart';
import 'review_view_model.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.viewModel});

  final ReviewViewModel viewModel;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _preview = GlobalKey<VideoPreviewState>();

  ReviewViewModel get _vm => widget.viewModel;

  Future<void> _confirmRemoveVideo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove video?'),
        content: const Text(
          'The video is deleted from Clipt. Your marks are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok == true) await _vm.removeVideo();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) {
        if (_vm.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (_vm.notFound) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_off_rounded,
                      size: 48, color: AppColors.muted),
                  const SizedBox(height: AppSpacing.base),
                  const Text(
                    'Session not found',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('This session no longer exists.',
                      style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: AppSpacing.xl),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go back'),
                  ),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(_vm.title)),
          body: _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    final marks = _vm.marks;
    final error = _vm.errorMessage;

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        children: [
          // ── Stat chips ───────────────────────────────────────────────
          Row(
            children: [
              _StatChip(
                label: 'Played',
                value: _vm.length == null
                    ? '--:--'
                    : formatClock(_vm.length!.inMilliseconds),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatChip(
                label: 'Marks',
                value: '${marks.length}',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          // ── Video card ───────────────────────────────────────────────
          _VideoSection(
            vm: _vm,
            previewKey: _preview,
            onRemove: _confirmRemoveVideo,
          ),
          const SizedBox(height: AppSpacing.sm),
          // ── Edit clips CTA ───────────────────────────────────────────
          if (_vm.hasVideo && marks.isNotEmpty) ...[
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () =>
                  context.push(Routes.clipsPath(_vm.sessionId)),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit clips'),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${marks.length} mark${marks.length == 1 ? '' : 's'} found',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          // ── Error banner ─────────────────────────────────────────────
          if (error != null) ...[
            _ErrorBanner(message: error),
            const SizedBox(height: AppSpacing.sm),
          ],
          // ── Timing collapsible ────────────────────────────────────────
          _TimingCard(vm: _vm),
          const SizedBox(height: AppSpacing.xl),
          // ── Marks section ─────────────────────────────────────────────
          const Text(
            'MARKS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.muted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (marks.isEmpty)
            const _EmptyMarks()
          else
            for (final m in marks)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _MarkTile(
                  mark: m,
                  clipStartMs: _vm.clipStartMs(m),
                  hasVideo: _vm.hasVideo,
                  onTagChanged: (tag) => _vm.changeTag(m.id, tag),
                  onDelete: () => _vm.deleteMark(m.id),
                  onPreview: _vm.hasVideo
                      ? () => _preview.currentState?.seekTo(
                            Duration(milliseconds: _vm.clipStartMs(m)),
                          )
                      : null,
                  onMatch: _vm.hasVideo
                      ? () async {
                          final position =
                              _preview.currentState?.position;
                          if (position == null ||
                              position == Duration.zero) {
                            final ctx = context;
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Play the video first.'),
                                ),
                              );
                            }
                            return;
                          }
                          await _preview.currentState?.pause();
                          await _vm.matchMark(m, position);
                          final ctx = context;
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(
                                content: Text('Synced to this moment.'),
                              ),
                            );
                          }
                        }
                      : null,
                ),
              ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat chip (small pill with label + value)
// ─────────────────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.muted)),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            style: AppTheme.mono(
                size: 14, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Video section
// ─────────────────────────────────────────────────────────────────────────────

class _VideoSection extends StatelessWidget {
  const _VideoSection({
    required this.vm,
    required this.previewKey,
    required this.onRemove,
  });

  final ReviewViewModel vm;
  final GlobalKey<VideoPreviewState> previewKey;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (vm.isImporting) {
      return AppCard(
        child: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: AppSpacing.md),
            Expanded(
                child: Text('Adding your video…')),
          ],
        ),
      );
    }

    final file = vm.video;
    if (file == null) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add your recording',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Pick the video you recorded during this session. '
              'Clipt uses your marks to find the clips.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: vm.addVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Add video'),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: AppCard(
        padding: const EdgeInsets.all(0),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: VideoPreview(key: previewKey, file: file),
            ),
            const Divider(height: 1, color: AppColors.line),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: vm.addVideo,
                  child: const Text('Replace'),
                ),
                TextButton(
                  onPressed: onRemove,
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.muted),
                  child: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Collapsible timing card
// ─────────────────────────────────────────────────────────────────────────────

class _TimingCard extends StatefulWidget {
  const _TimingCard({required this.vm});

  final ReviewViewModel vm;

  @override
  State<_TimingCard> createState() => _TimingCardState();
}

class _TimingCardState extends State<_TimingCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _controller;
  late final Animation<double> _sizeFactor;

  ReviewViewModel get _vm => widget.vm;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _sizeFactor = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  String _summary() {
    final sync = formatSignedSeconds(_vm.syncOffsetMs);
    final delay = '${_vm.delaySeconds} s';
    return 'Sync $sync · Lead-in $delay';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row (always visible)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: _toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.base,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  const Text(
                    'Timing',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _summary(),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more_rounded,
                        size: 20, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
          // Expandable body
          SizeTransition(
            sizeFactor: _sizeFactor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: AppColors.line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.base,
                    AppSpacing.md,
                    AppSpacing.base,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Sync slider ─────────────────────────────────
                      if (_vm.hasVideo) ...[
                        _SliderRow(
                          label: 'Video sync',
                          value: formatSignedSeconds(_vm.syncOffsetMs),
                        ),
                        Slider(
                          value: (_vm.syncOffsetMs / 1000)
                              .clamp(-60, 60)
                              .toDouble(),
                          min: -60,
                          max: 60,
                          divisions: 240,
                          label: formatSignedSeconds(_vm.syncOffsetMs),
                          activeColor: AppColors.accent,
                          onChanged: (v) =>
                              _vm.previewSync((v * 1000).round()),
                          onChangeEnd: (_) => _vm.saveSync(),
                        ),
                        Row(
                          children: [
                            _NudgeButton(
                              label: '−0.5 s',
                              onPressed: () => _vm.nudgeSync(-500),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            _NudgeButton(
                              label: '+0.5 s',
                              onPressed: () => _vm.nudgeSync(500),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        const Text(
                          'Offset between when you pressed Start and when recording began.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.muted),
                        ),
                        const SizedBox(height: AppSpacing.base),
                      ],
                      // ── Delay slider ────────────────────────────────
                      _SliderRow(
                        label: 'Lead-in',
                        value: '${_vm.delaySeconds} s',
                      ),
                      Slider(
                        value: _vm.delaySeconds.toDouble(),
                        min: 0,
                        max: ReviewViewModel.maxDelay.toDouble(),
                        divisions: ReviewViewModel.maxDelay,
                        label: '${_vm.delaySeconds}s',
                        activeColor: AppColors.accent,
                        onChanged: (v) => _vm.previewDelay(v.round()),
                        onChangeEnd: (_) => _vm.saveDelay(),
                      ),
                      const Text(
                        'Clips start this many seconds before each tap.',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ),
        Text(value,
            style: AppTheme.mono(size: 14, weight: FontWeight.w700)),
      ],
    );
  }
}

class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(60, 36),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.line),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mark tile
// ─────────────────────────────────────────────────────────────────────────────

class _MarkTile extends StatelessWidget {
  const _MarkTile({
    required this.mark,
    required this.clipStartMs,
    required this.hasVideo,
    required this.onTagChanged,
    required this.onDelete,
    required this.onPreview,
    required this.onMatch,
  });

  final Mark mark;
  final int clipStartMs;
  final bool hasVideo;
  final ValueChanged<String> onTagChanged;
  final VoidCallback onDelete;
  final VoidCallback? onPreview;
  final VoidCallback? onMatch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Tag dot ─────────────────────────────────────────────────
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.forTag(mark.tag),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // ── Time + clip start ────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatClock(mark.atMs),
                  style: AppTheme.mono(
                      size: 16, weight: FontWeight.w700),
                ),
                Text(
                  'clip starts ${formatClock(clipStartMs)}',
                  style: AppTheme.mono(
                      size: 11, color: AppColors.muted),
                ),
              ],
            ),
          ),
          // ── Play button ──────────────────────────────────────────────
          if (onPreview != null)
            Semantics(
              label: 'Preview clip',
              child: IconButton(
                tooltip: 'Preview clip',
                icon: const Icon(Icons.play_circle_outline_rounded,
                    size: 22, color: AppColors.accent),
                onPressed: onPreview,
              ),
            ),
          // ── Overflow menu ────────────────────────────────────────────
          PopupMenuButton<_MarkAction>(
            tooltip: 'Mark options',
            icon: const Icon(Icons.more_vert_rounded,
                size: 20, color: AppColors.muted),
            onSelected: (action) =>
                _handleAction(context, action),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: _MarkAction.changeTag,
                child: const Text('Change tag'),
              ),
              if (hasVideo)
                PopupMenuItem(
                  value: _MarkAction.matchHere,
                  child: const Text('Match video here'),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _MarkAction.delete,
                child: const Text('Delete mark',
                    style: TextStyle(color: AppColors.tagFail)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleAction(BuildContext context, _MarkAction action) {
    switch (action) {
      case _MarkAction.changeTag:
        _showTagPicker(context);
      case _MarkAction.matchHere:
        onMatch?.call();
      case _MarkAction.delete:
        onDelete();
    }
  }

  void _showTagPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.base),
            const Text(
              'Change tag',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final tag in markTags)
              ListTile(
                leading: TagPill(tag: tag),
                onTap: () {
                  onTagChanged(tag);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

enum _MarkAction { changeTag, matchHere, delete }

// ─────────────────────────────────────────────────────────────────────────────
// Error banner
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.tagFail.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border:
            Border.all(color: AppColors.tagFail.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.tagFail),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style:
                  const TextStyle(fontSize: 13, color: AppColors.tagFail),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty marks
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyMarks extends StatelessWidget {
  const _EmptyMarks();

  @override
  Widget build(BuildContext context) {
    return const AppCard(
      child: Text(
        'No marks were saved in this session.',
        style: TextStyle(fontSize: 13, color: AppColors.muted),
      ),
    );
  }
}
