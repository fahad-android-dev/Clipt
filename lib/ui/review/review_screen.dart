import 'package:material_ui/material_ui.dart';

import '../../domain/models/mark.dart';
import '../../domain/models/mark_tags.dart';
import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_theme.dart';
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
            body: const Center(child: Text('This session no longer exists.')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(_vm.title)),
          body: _content(),
        );
      },
    );
  }

  Widget _content() {
    final marks = _vm.marks;
    final error = _vm.errorMessage;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: _VideoCard(
            viewModel: _vm,
            previewKey: _preview,
            onRemove: _confirmRemoveVideo,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _SummaryCard(length: _vm.length, markCount: marks.length),
              const SizedBox(height: 12),
              _DelayCard(viewModel: _vm),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error, style: const TextStyle(color: AppColors.accent)),
              ],
              const SizedBox(height: 24),
              const Text(
                'Marks',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              if (marks.isEmpty)
                const _EmptyMarks()
              else
                for (final m in marks)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MarkTile(
                      mark: m,
                      clipStartMs: _vm.clipStartMs(m),
                      onTagChanged: (tag) => _vm.changeTag(m.id, tag),
                      onDelete: () => _vm.deleteMark(m.id),
                      onPreview: _vm.hasVideo
                          ? () => _preview.currentState?.seekTo(
                                Duration(milliseconds: _vm.clipStartMs(m)),
                              )
                          : null,
                    ),
                  ),
            ],
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
    required this.viewModel,
    required this.previewKey,
    required this.onRemove,
  });

  final ReviewViewModel viewModel;
  final GlobalKey<VideoPreviewState> previewKey;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (viewModel.isImporting) {
      return const _Card(
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Adding your video. Long videos take a moment.')),
          ],
        ),
      );
    }

    final file = viewModel.video;
    if (file == null) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add your recording',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick the video you recorded during this session. Clipt uses '
              'your marks to find the clips.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: viewModel.addVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: const Text('Add video'),
            ),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        children: [
          VideoPreview(key: previewKey, file: file),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: viewModel.addVideo,
                child: const Text('Replace'),
              ),
              TextButton(onPressed: onRemove, child: const Text('Remove')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.length, required this.markCount});

  final Duration? length;
  final int markCount;

  @override
  Widget build(BuildContext context) {
    final played =
        length == null ? '--:--' : formatClock(length!.inMilliseconds);

    return _Card(
      child: Row(
        children: [
          Expanded(child: _Stat(label: 'Played', value: played)),
          Expanded(child: _Stat(label: 'Marks', value: '$markCount')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value, style: AppTheme.mono(size: 24, weight: FontWeight.w700)),
      ],
    );
  }
}

class _DelayCard extends StatelessWidget {
  const _DelayCard({required this.viewModel});

  final ReviewViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Reaction delay',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${viewModel.delaySeconds}s',
                style: AppTheme.mono(size: 16, weight: FontWeight.w700),
              ),
            ],
          ),
          Slider(
            value: viewModel.delaySeconds.toDouble(),
            min: 0,
            max: ReviewViewModel.maxDelay.toDouble(),
            divisions: ReviewViewModel.maxDelay,
            label: '${viewModel.delaySeconds}s',
            activeColor: AppColors.accent,
            onChanged: (v) => viewModel.previewDelay(v.round()),
            onChangeEnd: (_) => viewModel.saveDelay(),
          ),
          const Text(
            'Clips start this many seconds before each tap, because you '
            'always tap a moment after it happens.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _MarkTile extends StatelessWidget {
  const _MarkTile({
    required this.mark,
    required this.clipStartMs,
    required this.onTagChanged,
    required this.onDelete,
    required this.onPreview,
  });

  final Mark mark;
  final int clipStartMs;
  final ValueChanged<String> onTagChanged;
  final VoidCallback onDelete;

  /// Null when the session has no video yet.
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        children: [
          Text(
            formatClock(mark.atMs),
            style: AppTheme.mono(size: 18, weight: FontWeight.w700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: PopupMenuButton<String>(
                    onSelected: onTagChanged,
                    itemBuilder: (_) => [
                      for (final t in markTags)
                        PopupMenuItem(value: t, child: Text(t)),
                    ],
                    child: _TagPill(tag: mark.tag),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Clip starts at ${formatClock(clipStartMs)}',
                  style: AppTheme.mono(size: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (onPreview != null)
            IconButton(
              tooltip: 'Preview this clip',
              icon: const Icon(
                Icons.play_circle_outline,
                color: AppColors.accent,
              ),
              onPressed: onPreview,
            ),
          IconButton(
            tooltip: 'Delete mark',
            icon: const Icon(Icons.delete_outline, color: AppColors.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.ink,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tag,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more, size: 16, color: Colors.white),
        ],
      ),
    );
  }
}

class _EmptyMarks extends StatelessWidget {
  const _EmptyMarks();

  @override
  Widget build(BuildContext context) {
    return const _Card(
      child: Text(
        'No marks were saved in this session.',
        style: TextStyle(color: AppColors.muted),
      ),
    );
  }
}