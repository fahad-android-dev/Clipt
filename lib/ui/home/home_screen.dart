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
          body: _body(),
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

  Widget _body() {
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
      itemBuilder: (context, i) => _SessionTile(session: sessions[i]),
    );
  }

  Future<void> _newSession(BuildContext context) async {
    final title = await showDialog<String>(
      context: context,
      builder: (_) => const _NewSessionDialog(),
    );
    if (title == null) return; // cancelled

    final id = await viewModel.startSession(title);
    if (!context.mounted) return;
    context.push(Routes.sessionPath(id));
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final length = session.length;
    final subtitle = length == null
        ? 'In progress. Tap to resume.'
        : '${formatDateTime(session.startedAt)}  ·  '
            '${formatClock(length.inMilliseconds)}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          leading: session.isActive
              ? const Icon(Icons.circle, size: 12, color: AppColors.accent)
              : null,
          title: Text(
            session.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            subtitle,
            style: AppTheme.mono(size: 12, color: AppColors.muted),
          ),
          onTap: session.isActive
              ? () => context.push(Routes.sessionPath(session.id))
              : null,
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
          child: const Text('Start'),
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
              'Start your first session',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap while you play. Clipt turns your taps into clips later.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}