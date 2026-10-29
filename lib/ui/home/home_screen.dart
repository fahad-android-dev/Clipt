import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/models/folder.dart';
import '../../routing/routes.dart';
import '../core/themes/app_colors.dart';
import '../core/themes/app_theme.dart';
import '../core/widgets/confirm_dialog.dart';
import '../core/widgets/name_dialog.dart';
import '../core/widgets/session_tile.dart';
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
          appBar: AppBar(
            title: const Text('Clipt'),
            actions: kDebugMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.science_outlined),
                      tooltip: 'FFmpeg lab',
                      onPressed: () => context.push('/dev/ffmpeg'),
                    ),
                  ]
                : null,
          ),
          body: Column(
            children: [
              _SearchBar(viewModel: viewModel),
              Expanded(child: _body(context)),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
            elevation: 0,
            onPressed: () => _newFolder(context),
            icon: const Icon(Icons.add),
            label: const Text('New folder'),
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
        child: Text('Couldn\'t load your data. Restart the app.'),
      );
    }

    if (viewModel.isSearching) {
      return _SearchResults(viewModel: viewModel);
    }

    return _FolderList(viewModel: viewModel);
  }

  Future<void> _newFolder(BuildContext context) async {
    final name = await showNameDialog(
      context,
      title: 'New folder',
      hint: 'Ranked matches',
      confirmLabel: 'Create',
    );
    if (name == null) return;
    await viewModel.createFolder(name);
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: TextField(
          decoration: InputDecoration(
            hintText: 'Search folders and sessions',
            hintStyle: const TextStyle(color: AppColors.muted),
            prefixIcon: const Icon(Icons.search, color: AppColors.muted),
            suffixIcon: viewModel.query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: AppColors.muted),
                    onPressed: () => viewModel.setQuery(''),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          onChanged: viewModel.setQuery,
        ),
      ),
    );
  }
}

class _FolderList extends StatelessWidget {
  const _FolderList({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final folders = viewModel.folders;
    final unfiledCount = viewModel.unfiledCount;

    if (folders.isEmpty && unfiledCount == 0) {
      return const _EmptyState();
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      itemCount: folders.length + (unfiledCount > 0 ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i < folders.length) {
          return _FolderTile(
            folder: folders[i].folder,
            onRename: () => _renameFolder(context, folders[i].folder),
            onDelete: () => _confirmDeleteFolder(context, folders[i].folder),
          );
        } else {
          return _UnfiledTile(count: unfiledCount);
        }
      },
    );
  }

  Future<void> _renameFolder(BuildContext context, Folder folder) async {
    final name = await showNameDialog(
      context,
      title: 'Rename folder',
      hint: folder.name,
      confirmLabel: 'Rename',
      initialText: folder.name,
    );
    if (name == null) return;
    await viewModel.renameFolder(folder, name);
  }

  Future<void> _confirmDeleteFolder(BuildContext context, Folder folder) async {
    final count = await viewModel.getSessionCountInFolder(folder.id);
    if (!context.mounted) return;
    final ok = await confirmDelete(
      context,
      title: 'Delete folder?',
      message:
          '"${folder.name}" and its $count session(s) '
          '(with marks and videos) will be deleted. This can\'t be undone.',
    );
    if (ok) await viewModel.deleteFolder(folder);
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({
    required this.folder,
    required this.onRename,
    required this.onDelete,
  });

  final Folder folder;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
          leading: const Icon(Icons.folder, color: AppColors.muted),
          title: Text(
            folder.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.muted),
            onSelected: (action) {
              if (action == 'rename') {
                onRename();
              } else if (action == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
          onTap: () => context.push(Routes.folderPath(folder.id)),
        ),
      ),
    );
  }
}

class _UnfiledTile extends StatelessWidget {
  const _UnfiledTile({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
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
          leading: const Icon(Icons.inbox, color: AppColors.muted),
          title: const Text(
            'Unfiled',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '$count session(s)',
            style: AppTheme.mono(size: 12, color: AppColors.muted),
          ),
          onTap: () => context.push(Routes.unfiled),
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final results = viewModel.results;

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Nothing matches "${viewModel.query}".',
            style: const TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        if (results.folders.isNotEmpty) ...[
          const Text(
            'Folders',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          ...results.folders.map(
            (fs) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _FolderTile(
                folder: fs.folder,
                onRename: () {},
                onDelete: () {},
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (results.sessions.isNotEmpty) ...[
          const Text(
            'Sessions',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 8),
          ...results.sessions.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SessionTile(
                session: s,
                onOpen: () =>
                    context.push(Routes.openPath(id: s.id, ended: s.isEnded)),
                onDelete: () async {
                  final ok = await confirmDelete(
                    context,
                    title: 'Delete session?',
                    message:
                        '"${s.title}" and all its marks will be deleted. '
                        'This can\'t be undone.',
                  );
                  if (ok) await viewModel.deleteSession(s);
                },
                folderLabel: viewModel.folderLabelFor(s),
              ),
            ),
          ),
        ],
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
              'Create your first folder',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Folders help you organize your recording sessions. '
              'Create one to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
