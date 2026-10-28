import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/session.dart';
import '../../routing/routes.dart';
import '../core/themes/app_colors.dart';
import '../core/widgets/confirm_dialog.dart';
import '../core/widgets/name_dialog.dart';
import '../core/widgets/session_tile.dart';
import 'folder_view_model.dart';

class FolderScreen extends StatelessWidget {
  const FolderScreen({super.key, required this.viewModel});

  final FolderViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) {
        if (viewModel.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (viewModel.notFound) {
          return Scaffold(
            appBar: AppBar(title: Text(viewModel.title)),
            body: const Center(child: Text('This folder no longer exists.')),
          );
        }
        return Scaffold(
          appBar: AppBar(title: Text(viewModel.title)),
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
    final sessions = viewModel.sessions;
    if (sessions.isEmpty) {
      return const _EmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: sessions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final session = sessions[i];
        return SessionTile(
          session: session,
          onOpen: () => context.push(Routes.openPath(
            id: session.id,
            ended: session.isEnded,
          )),
          onDelete: () => _confirmDelete(context, session),
          onMove: () => _showMoveDialog(context, session),
        );
      },
    );
  }

  Future<void> _newSession(BuildContext context) async {
    final title = await showNameDialog(
      context,
      title: 'New session',
      hint: 'Valorant ranked',
      confirmLabel: 'Create',
      initialText: '',
      allowEmpty: true,
    );
    if (title == null) return;

    await viewModel.createSession(title);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session created. Tap it when you\'re ready to start.'),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Session session) async {
    final ok = await confirmDelete(
      context,
      title: 'Delete session?',
      message: '"${session.title}" and all its marks will be deleted. '
          'This can\'t be undone.',
    );
    if (ok) await viewModel.deleteSession(session);
  }

  Future<void> _showMoveDialog(BuildContext context, Session session) async {
    final targets = viewModel.moveTargets;
    final result = await showDialog<_MoveChoice>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Move to folder'),
        children: [
          if (viewModel.canMoveToUnfiled)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, const _MoveChoice(null)),
              child: const Text('Unfiled'),
            ),
          for (final folder in targets)
            SimpleDialogOption(
              onPressed: () =>
                  Navigator.pop(context, _MoveChoice(folder.id)),
              child: Text(folder.name),
            ),
        ],
      ),
    );
    if (result != null) {
      await viewModel.moveSession(session, result.folderId);
    }
  }
}

class _MoveChoice {
  const _MoveChoice(this.folderId);

  final int? folderId;
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
              'No sessions yet',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create a session to start recording. Tap while you play and '
              'Clipt turns your taps into clips later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
