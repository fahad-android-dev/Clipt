import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../domain/clip_planner.dart';
import '../../routing/routes.dart';
import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_spacing.dart';
import '../core/themes/app_theme.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/bottom_action_bar.dart';
import '../core/widgets/empty_state.dart';
import '../core/widgets/tag_pill.dart';
import '../core/widgets/video_preview.dart';
import 'clips_view_model.dart';

class ClipsScreen extends StatefulWidget {
  const ClipsScreen({super.key, required this.viewModel});

  final ClipsViewModel viewModel;

  @override
  State<ClipsScreen> createState() => _ClipsScreenState();
}

class _ClipsScreenState extends State<ClipsScreen> {
  final _preview = GlobalKey<VideoPreviewState>();
  final _stripController = ScrollController();

  ClipsViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.load();
  }

  @override
  void dispose() {
    _stripController.dispose();
    super.dispose();
  }

  void _selectAndPlay(int markId) {
    _vm.select(markId);
    HapticFeedback.selectionClick();
    final clips = _vm.clips;
    if (clips.isEmpty) return;
    final clip = clips.firstWhere(
      (c) => c.mark.id == markId,
      orElse: () => clips.first,
    );
    _preview.currentState?.playRange(
      Duration(milliseconds: clip.startMs),
      Duration(milliseconds: clip.endMs),
    );
    _scrollStripToSelected();
  }

  void _scrollStripToSelected() {
    final clips = _vm.clips;
    final idx = clips.indexWhere((c) => c.mark.id == _vm.selectedMarkId);
    if (idx < 0 || !_stripController.hasClients) return;
    const chipW = 104.0 + 8.0;
    final target = (idx * chipW) -
        (_stripController.position.viewportDimension / 2 - chipW / 2);
    _stripController.animateTo(
      target.clamp(0, _stripController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: const BackButton(),
      title: const Text('Edit clips'),
    );
  }

  Widget _buildBottomBar() {
    final included = _vm.includedCount;
    final total = _vm.totalClips;
    final lengthMs = _vm.includedLengthMs;
    final summary =
        '$included of $total clip${total == 1 ? '' : 's'} · ${formatClock(lengthMs)}';

    return BottomActionBar(
      summaryText: summary,
      buttonLabel: 'Export',
      onPressed: included > 0
          ? () => context.push(Routes.exportPath(_vm.sessionId))
          : null,
      disabledHint: 'Include at least one clip to export.',
    );
  }

  Widget _buildVideoArea() {
    final maxH = MediaQuery.sizeOf(context).height * 0.35;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxH),
          color: Colors.black,
          child: _buildVideoWithOverlay(),
        ),
      ),
    );
  }

  Widget _buildVideoWithOverlay() {
    return Stack(
      children: [
        GestureDetector(
          onTap: () => _preview.currentState?.togglePlayPause(),
          child: VideoPreview(
            key: _preview,
            file: _vm.video!,
            onReady: _vm.setVideoDuration,
          ),
        ),
        // Position chip: bottom-left
        Positioned(
          bottom: AppSpacing.sm,
          left: AppSpacing.sm,
          child: _PositionChip(previewKey: _preview, vm: _vm),
        ),
        // Large play icon fades when playing
        _PlayIconOverlay(previewKey: _preview),
      ],
    );
  }

  Widget _buildSelectedClipPanel() {
    final clips = _vm.clips;
    final markId = _vm.selectedMarkId;
    if (markId == null || clips.isEmpty) return const SizedBox.shrink();

    final idx = clips.indexWhere((c) => c.mark.id == markId);
    final clip = idx >= 0 ? clips[idx] : clips.first;
    final realIdx = idx >= 0 ? idx : 0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: _ClipDetailPanel(
        key: ValueKey(clip.mark.id),
        clip: clip,
        index: realIdx,
        total: clips.length,
        previewKey: _preview,
        vm: _vm,
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(
            AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.base, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.tagFail.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border:
              Border.all(color: AppColors.tagFail.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 18, color: AppColors.tagFail),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _vm.errorMessage!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.tagFail),
              ),
            ),
            GestureDetector(
              onTap: _vm.dismissError,
              child: const Icon(Icons.close,
                  size: 18, color: AppColors.tagFail),
            ),
          ],
        ),
      ),
    );
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
            appBar: _buildAppBar(),
            body: EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Session not found',
              message: 'This session no longer exists.',
              actionLabel: 'Go back',
              onAction: () => context.pop(),
            ),
          );
        }
        if (_vm.video == null) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: EmptyState(
              icon: Icons.videocam_off_rounded,
              title: 'Add your recording first',
              message: 'Link a video to this session before editing clips.',
              actionLabel: 'Back to review',
              onAction: () =>
                  context.push(Routes.reviewPath(_vm.sessionId)),
            ),
          );
        }
        if (_vm.clips.isEmpty) {
          return Scaffold(
            appBar: _buildAppBar(),
            body: EmptyState(
              icon: Icons.content_cut_rounded,
              title: 'No clips yet',
              message:
                  'Tap a moment during a session to create a clip mark.',
              actionLabel: 'Go back',
              onAction: () => context.pop(),
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildVideoArea(),
              const SizedBox(height: AppSpacing.sm),
              _ClipStrip(
                clips: _vm.clips,
                selectedMarkId: _vm.selectedMarkId,
                scrollController: _stripController,
                onSelect: _selectAndPlay,
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildSelectedClipPanel()),
              if (_vm.errorMessage != null) _buildErrorBanner(),
              _buildBottomBar(),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Position chip (shows clip-relative time)
// ─────────────────────────────────────────────────────────────────────────────

class _PositionChip extends StatelessWidget {
  const _PositionChip({required this.previewKey, required this.vm});

  final GlobalKey<VideoPreviewState> previewKey;
  final ClipsViewModel vm;

  @override
  Widget build(BuildContext context) {
    final state = previewKey.currentState;
    final markId = vm.selectedMarkId;
    if (state == null || markId == null) return const SizedBox.shrink();

    final clips = vm.clips;
    final idx = clips.indexWhere((c) => c.mark.id == markId);
    if (idx < 0) return const SizedBox.shrink();

    final clip = clips[idx];
    final pos = state.position;
    final clipPos = pos - Duration(milliseconds: clip.startMs);
    final clipLen = Duration(milliseconds: clip.lengthMs);
    final posStr =
        _fmtMinSec(clipPos.isNegative ? Duration.zero : clipPos);
    final lenStr = _fmtMinSec(clipLen);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$posStr / $lenStr',
        style: AppTheme.mono(size: 12, color: Colors.white),
      ),
    );
  }

  String _fmtMinSec(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Large play icon overlay — fades out when playing
// ─────────────────────────────────────────────────────────────────────────────

class _PlayIconOverlay extends StatelessWidget {
  const _PlayIconOverlay({required this.previewKey});

  final GlobalKey<VideoPreviewState> previewKey;

  @override
  Widget build(BuildContext context) {
    final playing = previewKey.currentState?.isPlaying ?? false;
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: playing ? 0.0 : 0.65,
          child: const Center(
            child: Icon(Icons.play_circle_fill_rounded,
                size: 56, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Clip strip
// ─────────────────────────────────────────────────────────────────────────────

class _ClipStrip extends StatelessWidget {
  const _ClipStrip({
    required this.clips,
    required this.selectedMarkId,
    required this.scrollController,
    required this.onSelect,
  });

  final List<PlannedClip> clips;
  final int? selectedMarkId;
  final ScrollController scrollController;
  final void Function(int markId) onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        separatorBuilder: (context, idx) => const SizedBox(width: 8),
        itemCount: clips.length,
        itemBuilder: (_, i) {
          final clip = clips[i];
          final selected = clip.mark.id == selectedMarkId;
          return _ClipChip(
            clip: clip,
            index: i,
            selected: selected,
            onTap: () => onSelect(clip.mark.id),
          );
        },
      ),
    );
  }
}

class _ClipChip extends StatelessWidget {
  const _ClipChip({
    required this.clip,
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final PlannedClip clip;
  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tagColor = AppColors.forTag(clip.mark.tag);
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: clip.included ? 1.0 : 0.45,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 104,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: selected ? AppColors.surfaceTint : AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.line,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: AppTheme.mono(
                      size: 13,
                      weight: FontWeight.w700,
                      color: selected ? AppColors.accent : AppColors.ink,
                    ),
                  ),
                  if (!clip.included) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.visibility_off_rounded,
                        size: 12, color: AppColors.muted),
                  ],
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: tagColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      clip.mark.tag,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              Text(
                '${(clip.lengthMs / 1000).toStringAsFixed(0)} s',
                style: AppTheme.mono(size: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Selected clip detail panel
// ─────────────────────────────────────────────────────────────────────────────

class _ClipDetailPanel extends StatelessWidget {
  const _ClipDetailPanel({
    super.key,
    required this.clip,
    required this.index,
    required this.total,
    required this.previewKey,
    required this.vm,
  });

  final PlannedClip clip;
  final int index;
  final int total;
  final GlobalKey<VideoPreviewState> previewKey;
  final ClipsViewModel vm;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(),
            const SizedBox(height: AppSpacing.base),
            _buildTrimControl(context),
            const SizedBox(height: AppSpacing.base),
            _buildFineTuneSection(),
            const SizedBox(height: AppSpacing.base),
            _buildActionsRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Row(
      children: [
        TagPill(tag: clip.mark.tag),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Clip ${index + 1} of $total',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Include',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(width: 4),
            Switch(
              value: clip.included,
              activeTrackColor: AppColors.accent,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                vm.setIncluded(clip.mark.id, v);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrimControl(BuildContext context) {
    final startSec = clip.startMs / 1000;
    final endSec = clip.endMs / 1000;
    final lengthSec = clip.lengthMs / 1000;
    final windowStart = clip.windowStartMs.toDouble();
    final windowEnd = clip.windowEndMs.toDouble();

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 10,
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.accent,
        rangeThumbShape: const RoundRangeSliderThumbShape(
          enabledThumbRadius: 14,
        ),
        rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
        rangeValueIndicatorShape:
            const PaddleRangeSliderValueIndicatorShape(),
        // ignore: deprecated_member_use
        showValueIndicator: ShowValueIndicator.always,
        valueIndicatorColor: AppColors.ink,
        valueIndicatorTextStyle: AppTheme.mono(
          size: 12,
          color: Colors.white,
        ),
        overlayColor: AppColors.accent.withValues(alpha: 0.15),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _fmtSec(startSec),
                style: AppTheme.mono(size: 20, weight: FontWeight.w600),
              ),
              Text(
                '${lengthSec.toStringAsFixed(1)} s',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _fmtSec(endSec),
                style: AppTheme.mono(size: 20, weight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RangeSlider(
            values: RangeValues(
              clip.startMs.toDouble(),
              clip.endMs.toDouble(),
            ),
            min: windowStart,
            max: windowEnd,
            labels: RangeLabels(
              formatClock(clip.startMs),
              formatClock(clip.endMs),
            ),
            onChanged: (values) => vm.previewTrim(
              clip.mark.id,
              values.start.round(),
              values.end.round(),
            ),
            onChangeEnd: (_) => vm.saveTrim(clip.mark.id),
          ),
        ],
      ),
    );
  }

  Widget _buildFineTuneSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Fine tune'),
        const SizedBox(height: AppSpacing.sm),
        _NudgeRow(
          label: 'Start',
          onMinus: () {
            HapticFeedback.lightImpact();
            vm.nudgeStart(clip.mark.id, -500);
          },
          onPlus: () {
            HapticFeedback.lightImpact();
            vm.nudgeStart(clip.mark.id, 500);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        _NudgeRow(
          label: 'End',
          onMinus: () {
            HapticFeedback.lightImpact();
            vm.nudgeEnd(clip.mark.id, -500);
          },
          onPlus: () {
            HapticFeedback.lightImpact();
            vm.nudgeEnd(clip.mark.id, 500);
          },
        ),
      ],
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              previewKey.currentState?.playRange(
                Duration(milliseconds: clip.startMs),
                Duration(milliseconds: clip.endMs),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_arrow_rounded, size: 18),
                SizedBox(width: 6),
                Text('Play clip'),
              ],
            ),
          ),
        ),
        if (clip.isCustom) ...[
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 48),
              foregroundColor: AppColors.muted,
            ),
            onPressed: () => vm.resetClip(clip.mark.id),
            child: const Text('Reset'),
          ),
        ],
      ],
    );
  }

  String _fmtSec(double sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '$m:${s.toStringAsFixed(1).padLeft(4, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fine-tune nudge row
// ─────────────────────────────────────────────────────────────────────────────

class _NudgeRow extends StatelessWidget {
  const _NudgeRow({
    required this.label,
    required this.onMinus,
    required this.onPlus,
  });

  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final btnStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 48),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      foregroundColor: AppColors.ink,
      side: const BorderSide(color: AppColors.line),
    );

    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton(
          style: btnStyle,
          onPressed: onMinus,
          child: const Text('−0.5 s'),
        ),
        const SizedBox(width: AppSpacing.sm),
        OutlinedButton(
          style: btnStyle,
          onPressed: onPlus,
          child: const Text('+0.5 s'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small all-caps section label
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.muted,
      ),
    );
  }
}
