import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/session.dart';
import '../../routing/routes.dart';
import '../../utils/formatters.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_theme.dart';
import 'home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Clipt')),
          body: _body(context),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            onPressed: () => _newSession(context),
            icon: const Icon(Icons.add),
            label: const Text('New session'),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (viewModel.hasFailed) {
      return const Center(
        child: Text('Couldn\'t load your sessions. Restart the app.'),
      );
    }
    final sessions = viewModel.sessions;
    if (sessions.isEmpty) return const _EmptyState();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final session = sessions[i];
        return _SessionTile(
          session: session,
          onOpen: () => context.push(
            session.isEnded
                ? Routes.reviewPath(session.id)
                : Routes.sessionPath(session.id),
          ),
          onDelete: () => _confirmDelete(context, session),
        );
      },
    );
  }

  Future<void> _newSession(BuildContext context) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _NewSessionDialog(),
    );
    if (title == null) return; // cancelled

    await viewModel.createSession(title);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session created. Tap it when you\'re ready to start.'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Session session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session?'),
        content: Text(
          '"${session.title}" and all its marks will be deleted. '
          'This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await viewModel.deleteSession(session);
  }
}

enum _TileAction { delete }

class _SessionTile extends StatelessWidget {
  const _SessionTile({
    required this.session,
    required this.onOpen,
    required this.onDelete,
  });

  final Session session;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;

  String get _subtitle {
    if (session.isReady) return 'Ready to start';
    if (session.isLive) return 'In progress. Tap to resume.';
    final started = session.startedAt!;
    final length = session.length;
    return '${formatDateTime(started)}  ·  '
        '${formatClock(length?.inMilliseconds ?? 0)}';
  }

  Widget? get _leading {
    if (session.isLive) {
      return const Icon(Icons.circle, size: 12, color: AppColors.accent);
    }
    if (session.isReady) {
      return const Icon(
        Icons.circle_outlined,
        size: 12,
        color: AppColors.muted,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('session-${session.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppColors.accent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: ListTile(
            leading: _leading,
            title: Text(
              session.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              _subtitle,
              style: AppTheme.mono(size: 12, color: AppColors.muted),
            ),
            // The menu is a second way to delete, for people who don't swipe.
            trailing: PopupMenuButton<_TileAction>(
              icon: const Icon(Icons.more_vert, color: AppColors.muted),
              onSelected: (_) => onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _TileAction.delete, child: Text('Delete')),
              ],
            ),
            onTap: onOpen,
          ),
        ),
      ),
    );
  }
}

/// Owns its own text controller, so it is disposed safely with the dialog.
class _NewSessionDialog extends StatefulWidget {
  const _NewSessionDialog();

  @override
  State<_NewSessionDialog> createState() => _NewSessionDialogState();
}

class _NewSessionDialogState extends State<_NewSessionDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New session'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Valorant ranked'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Create your first session',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a session, then open it and press Start when you begin '
              'recording. Tap while you play and Clipt turns your taps into '
              'clips later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
