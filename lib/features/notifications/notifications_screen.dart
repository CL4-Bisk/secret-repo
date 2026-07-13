import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../dashboard/dashboard_repository.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(notificationHistoryProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => context.go('/dashboard'),
            child: const Text('Dashboard'),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(notificationHistoryProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: history.when(
          data: (value) => _NotificationsContent(history: value),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Card(
                  elevation: 0,
                  color: colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Notifications failed to load\n$error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onErrorContainer),
                    ),
                  ),
                ),
              ),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _NotificationsContent extends ConsumerWidget {
  const _NotificationsContent({required this.history});

  final NotificationHistory history;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Notification history',
                style: Theme.of(
                  context,
                ).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Review apartment activity without crowding the dashboard.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                color: colorScheme.tertiaryContainer,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Notifications',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Chip(
                            label: Text('${history.unreadCount} unread'),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (history.hasUnread)
                            TextButton.icon(
                              key: const Key('notifications-mark-all-read'),
                              onPressed: () async {
                                await ref
                                    .read(dashboardRepositoryProvider)
                                    .markAllNotificationsRead();
                                ref.invalidate(notificationHistoryProvider);
                                ref.invalidate(dashboardSummaryProvider);
                              },
                              icon: const Icon(Icons.done_all),
                              label: const Text('Mark all as read'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (history.notifications.isEmpty)
                        Text(
                          'No notifications yet.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        )
                      else
                        for (final (index, notification)
                            in history.notifications.indexed) ...[
                          if (index > 0) const Divider(height: 24),
                          _NotificationHistoryTile(notification: notification),
                        ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationHistoryTile extends ConsumerWidget {
  const _NotificationHistoryTile({required this.notification});

  final DashboardNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.primary,
          child: Icon(
            notification.isUnread
                ? Icons.notifications_active_outlined
                : Icons.notifications_none_outlined,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                notification.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Chip(
                    label: Text(notification.statusLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  Chip(
                    label: Text(notification.createdAtLabel),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (notification.isUnread)
                    TextButton.icon(
                      key: Key('notification-mark-read-${notification.id}'),
                      onPressed: () async {
                        await ref
                            .read(dashboardRepositoryProvider)
                            .markNotificationRead(
                              notificationId: notification.id,
                            );
                        ref.invalidate(notificationHistoryProvider);
                        ref.invalidate(dashboardSummaryProvider);
                      },
                      icon: const Icon(Icons.done),
                      label: const Text('Mark as read'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
