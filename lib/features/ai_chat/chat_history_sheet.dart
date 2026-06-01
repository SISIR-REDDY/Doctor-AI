import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/patient_models.dart';
import '../../services/firebase/firestore_service.dart';
import '../../theme/app_theme.dart';

class ChatHistorySheet extends StatelessWidget {
  final String uid;
  final FirestoreService db;
  final ChatSession? currentSession;
  final VoidCallback onNewChat;
  final ValueChanged<ChatSession> onSelect;

  const ChatHistorySheet({
    super.key,
    required this.uid,
    required this.db,
    this.currentSession,
    required this.onNewChat,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.history_rounded,
                        color: AppTheme.primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Chat History', style: AppTheme.headingSmall),
                  ),
                  TextButton.icon(
                    onPressed: onNewChat,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Chat'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppTheme.dividerColor),
            Expanded(
              child: StreamBuilder<List<ChatSession>>(
                stream: db.watchChatSessions(uid),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  final sessions = snap.data ?? [];
                  if (sessions.isEmpty) return const _EmptyHistory();
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: sessions.length,
                    itemBuilder: (ctx, i) => _SessionTile(
                      session: sessions[i],
                      isActive: sessions[i].id == currentSession?.id,
                      onTap: () => onSelect(sessions[i]),
                      onDelete: () =>
                          _confirmDelete(context, sessions[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChatSession session) {
    final isCurrent = session.id == currentSession?.id;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: Text(
          isCurrent
              ? 'Delete this conversation? A new chat will be created.'
              : 'Delete "${session.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await db.deleteChatSession(uid, session.id);
              if (isCurrent) onNewChat();
            },
            style:
                TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Session tile ──────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primaryColor.withValues(alpha: 0.06)
            : AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : AppTheme.borderColor,
          width: isActive ? 1.2 : 0.8,
        ),
        boxShadow: isActive ? [] : AppTheme.cardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient:
                        isActive ? AppTheme.primaryGradient : null,
                    color: isActive ? null : AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: isActive
                        ? Colors.white
                        : AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isActive
                              ? AppTheme.primaryColor
                              : AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (session.lastMessage.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          session.lastMessage,
                          style: AppTheme.bodySmall
                              .copyWith(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(session.updatedAt),
                        style: AppTheme.labelSmall.copyWith(
                            color: isActive
                                ? AppTheme.primaryColor
                                    .withValues(alpha: 0.7)
                                : AppTheme.textTertiary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20),
                  color: AppTheme.textTertiary,
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(date).inDays;
    if (diff == 0) return 'Today · ${DateFormat.jm().format(dt)}';
    if (diff == 1) return 'Yesterday · ${DateFormat.jm().format(dt)}';
    if (diff < 7) return DateFormat.EEEE().format(dt);
    return DateFormat.MMMd().format(dt);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                size: 34, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 16),
          Text('No chat history yet',
              style: AppTheme.headingSmall),
          const SizedBox(height: 6),
          Text(
            'Your conversations will appear here',
            style: AppTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
