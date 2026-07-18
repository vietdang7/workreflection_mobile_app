// Notifications inbox screen — Phase 4 Task 4.
//
// Schema note: cc_notifications has no user_id column; rows are targeted by
// target_type ("admin"|"enterprise"). Read state: read_by string[].
// Mobile users see whatever Supabase RLS exposes (may be empty for regular
// users). Empty state is handled gracefully.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/models/notification_model.dart';
import '../../../core/theme/wr_colors.dart';
import '../../../core/theme/wr_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../notification_providers.dart'; // currentUserIdProvider, notificationsProvider

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final notificationsAsync = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: WrColors.white,
      appBar: AppBar(
        backgroundColor: WrColors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: WrColors.navy),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.notificationsTitle, style: WrTextStyles.hMedium),
        actions: [
          notificationsAsync.maybeWhen(
            data: (notifications) {
              final uid = ref.watch(currentUserIdProvider);
              final hasUnread =
                  notifications.any((n) => !n.isReadBy(uid));
              if (!hasUnread) return const SizedBox.shrink();
              return TextButton(
                key: const Key('markAllReadBtn'),
                onPressed: () =>
                    ref.read(notificationsProvider.notifier).markAllRead(),
                child: Text(
                  l10n.notificationsMarkAllRead,
                  style: const TextStyle(
                    color: WrColors.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: notificationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          onRetry: () => ref.read(notificationsProvider.notifier).refresh(),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return _EmptyState();
          }
          return _NotificationsList(notifications: notifications);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications list
// ---------------------------------------------------------------------------

class _NotificationsList extends ConsumerWidget {
  const _NotificationsList({required this.notifications});

  final List<CcNotification> notifications;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: notifications.length,
      separatorBuilder: (_, __) => const Divider(
        height: 1,
        indent: 16,
        endIndent: 16,
        color: WrColors.cream,
      ),
      itemBuilder: (context, index) {
        return _NotificationRow(notification: notifications[index]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Single notification row
// ---------------------------------------------------------------------------

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({required this.notification});

  final CcNotification notification;

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'vừa xong';
    if (diff.inHours < 1) return '${diff.inMinutes}m trước';
    if (diff.inDays < 1) return '${diff.inHours}h trước';
    if (diff.inDays < 7) return '${diff.inDays}d trước';
    return DateFormat('dd/MM/yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserIdProvider);
    final isRead = notification.isReadBy(uid);

    return InkWell(
      key: Key('notification_row_${notification.id}'),
      onTap: () {
        if (!isRead) {
          ref
              .read(notificationsProvider.notifier)
              .markRead(notification.id);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread indicator dot
            if (!isRead)
              Container(
                key: const Key('unreadDot'),
                margin: const EdgeInsets.only(top: 6, right: 10),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: WrColors.coral,
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 18), // same space, no dot

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isRead ? FontWeight.w400 : FontWeight.w700,
                      color: WrColors.dark,
                      height: 1.4,
                    ),
                  ),
                  if (notification.description != null &&
                      notification.description!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.description!,
                      style: WrTextStyles.body.copyWith(
                        fontSize: 13,
                        color: WrColors.muted,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(notification.createdAt),
                    style: WrTextStyles.body.copyWith(
                      fontSize: 11,
                      color: WrColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.notifications_none_outlined,
              size: 64,
              color: WrColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.notificationsEmpty,
              key: const Key('notifications_empty'),
              style: WrTextStyles.body.copyWith(color: WrColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: WrColors.coral, size: 48),
          const SizedBox(height: 16),
          TextButton(
            onPressed: onRetry,
            child: Text(l10n.homeRetry),
          ),
        ],
      ),
    );
  }
}
