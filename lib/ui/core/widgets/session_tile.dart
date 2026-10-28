import 'package:material_ui/material_ui.dart';

import '../../../domain/models/session.dart';
import '../../../utils/formatters.dart';
import '../themes/app_colors.dart';
import '../themes/app_theme.dart';

enum _TileAction { move, delete }

class SessionTile extends StatelessWidget {
  const SessionTile({
    super.key,
    required this.session,
    required this.onOpen,
    required this.onDelete,
    this.onMove,
    this.folderLabel,
  });

  final Session session;
  final VoidCallback onOpen;
  final Future<void> Function() onDelete;
  final VoidCallback? onMove;
  final String? folderLabel;

  String get _subtitle {
    if (session.isReady) return 'Ready to start';
    if (session.isLive) return 'In progress. Tap to resume.';
    final started = session.startedAt;
    final length = session.length;
    final status = '${formatDateTime(started!)}  ·  '
        '${formatClock(length?.inMilliseconds ?? 0)}';
    return folderLabel != null ? '$folderLabel  ·  $status' : status;
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
            trailing: PopupMenuButton<_TileAction>(
              icon: const Icon(Icons.more_vert, color: AppColors.muted),
              onSelected: (action) {
                if (action == _TileAction.move && onMove != null) {
                  onMove!();
                } else if (action == _TileAction.delete) {
                  onDelete();
                }
              },
              itemBuilder: (_) {
                final items = <PopupMenuItem<_TileAction>>[];
                if (onMove != null) {
                  items.add(
                    const PopupMenuItem(
                      value: _TileAction.move,
                      child: Text('Move to folder'),
                    ),
                  );
                }
                items.add(
                  const PopupMenuItem(
                    value: _TileAction.delete,
                    child: Text('Delete'),
                  ),
                );
                return items;
              },
            ),
            onTap: onOpen,
          ),
        ),
      ),
    );
  }
}
