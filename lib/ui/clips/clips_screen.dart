import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../../domain/clip_planner.dart';
import '../../routing/routes.dart';
import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_theme.dart';
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

  ClipsViewModel get _vm => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _vm.load();
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
            appBar: AppBar(title: const Text('Edit clips')),
            body: const Center(child: Text('This session no longer exists.')),
          );
        }
        if (_vm.video == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Edit clips')),
            body: const Center(
              child: Text('No video linked to this session.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Edit clips')),
          body: _content(),
        );
      },
    );
  }

  Widget _content() {
    final clips = _vm.clips;
    final error = _vm.errorMessage;

    return Column(
      children: [
        // Fixed top section
        Container(
          color: AppColors.paper,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _VideoCard(
                  file: _vm.video!,
                  previewKey: _preview,
                  onReady: _vm.setVideoDuration,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: _SummaryRow(viewModel: _vm),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text(error, style: const TextStyle(color: AppColors.accent)),
                ),
            ],
          ),
        ),
        // Scrollable clip list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              if (clips.isEmpty)
                const _EmptyClips()
              else
                for (final clip in clips)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ClipCard(
                      clip: clip,
                      previewKey: _preview,
                      onTrimChanged: (start, end) =>
                          _vm.previewTrim(clip.mark.id, start, end),
                      onTrimSaved: () => _vm.saveTrim(clip.mark.id),
                      onPreview: () => _preview.currentState?.playRange(
                            Duration(milliseconds: clip.startMs),
                            Duration(milliseconds: clip.endMs),
                          ),
                      onIncludedChanged: (included) =>
                          _vm.setIncluded(clip.mark.id, included),
                      onReset: () => _vm.resetClip(clip.mark.id),
                    ),
                  ),
            ],
          ),
        ),
        if (_vm.includedCount > 0)
          Padding(
            padding: const EdgeInsets.all(20),
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () => context.push(Routes.exportPath(_vm.sessionId)),
              child: Text('Export ${_vm.includedCount} clip${_vm.includedCount == 1 ? "" : "s"}'),
            ),
          ),
      ],
    );
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

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.file,
    required this.previewKey,
    required this.onReady,
  });

  final File file;
  final GlobalKey<VideoPreviewState> previewKey;
  final void Function(Duration) onReady;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: VideoPreview(
        key: previewKey,
        file: file,
        onReady: onReady,
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.viewModel});

  final ClipsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final included = viewModel.includedCount;
    final total = viewModel.totalClips;
    final length = formatClock(viewModel.includedLengthMs);

    return Text(
      '$included of $total clips · $length total',
      style: const TextStyle(color: AppColors.muted, fontSize: 14),
    );
  }
}

class _ClipCard extends StatelessWidget {
  const _ClipCard({
    required this.clip,
    required this.previewKey,
    required this.onTrimChanged,
    required this.onTrimSaved,
    required this.onPreview,
    required this.onIncludedChanged,
    required this.onReset,
  });

  final PlannedClip clip;
  final GlobalKey<VideoPreviewState> previewKey;
  final void Function(int startMs, int endMs) onTrimChanged;
  final VoidCallback onTrimSaved;
  final VoidCallback onPreview;
  final ValueChanged<bool> onIncludedChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final dimmed = !clip.included;

    return Opacity(
      opacity: dimmed ? 0.5 : 1.0,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TagPill(tag: clip.mark.tag),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${formatClock(clip.startMs)} – ${formatClock(clip.endMs)}',
                    style: AppTheme.mono(size: 13, color: AppColors.muted),
                  ),
                ),
                Text(
                  '${(clip.lengthMs / 1000).toStringAsFixed(1)} s',
                  style: AppTheme.mono(size: 13, weight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            RangeSlider(
              values: RangeValues(
                clip.startMs.toDouble(),
                clip.endMs.toDouble(),
              ),
              min: clip.windowStartMs.toDouble(),
              max: clip.windowEndMs.toDouble(),
              divisions: 200,
              labels: RangeLabels(
                formatClock(clip.startMs),
                formatClock(clip.endMs),
              ),
              activeColor: AppColors.accent,
              onChanged: (values) => onTrimChanged(
                values.start.round(),
                values.end.round(),
              ),
              onChangeEnd: (_) => onTrimSaved(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Preview this clip',
                  icon: const Icon(
                    Icons.play_circle_outline,
                    color: AppColors.accent,
                  ),
                  onPressed: onPreview,
                ),
                const SizedBox(width: 8),
                const Text('Include'),
                const SizedBox(width: 4),
                Switch(
                  value: clip.included,
                  onChanged: onIncludedChanged,
                  activeTrackColor: AppColors.accent,
                ),
                const Spacer(),
                if (clip.isCustom)
                  TextButton(
                    onPressed: onReset,
                    child: const Text('Reset'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyClips extends StatelessWidget {
  const _EmptyClips();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Text(
        'No marks in this session.',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}
