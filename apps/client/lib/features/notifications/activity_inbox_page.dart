import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../auth/session_repository.dart';
import 'push_notifications_service.dart';

final notificationsProvider = FutureProvider<List<HouseholdCollectionItem>>(
  (ref) => ref.read(sessionRepositoryProvider).notifications(),
);

class ActivityInboxPage extends ConsumerStatefulWidget {
  const ActivityInboxPage({super.key});

  @override
  ConsumerState<ActivityInboxPage> createState() => _ActivityInboxPageState();
}

class _ActivityInboxPageState extends ConsumerState<ActivityInboxPage> {
  final _markingRead = <String>{};
  var _enablingDeviceNotifications = false;

  Future<void> _refresh() async {
    ref.invalidate(notificationsProvider);
    await ref.read(notificationsProvider.future);
  }

  Future<void> _markRead(HouseholdCollectionItem item) async {
    final id = item.string('id');
    if (id == null ||
        _markingRead.contains(id) ||
        item.values['readAt'] != null) {
      return;
    }
    setState(() => _markingRead.add(id));
    try {
      await ref.read(sessionRepositoryProvider).markNotificationRead(id);
      ref.invalidate(notificationsProvider);
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not mark this update as read. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _markingRead.remove(id));
    }
  }

  Future<void> _enableDeviceNotifications() async {
    setState(() => _enablingDeviceNotifications = true);
    try {
      final enabled = await ref
          .read(pushNotificationsProvider)
          .requestAndRegister();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? 'Device notifications are on for household updates.'
                : 'Notifications were not enabled. You can change this in Android settings.',
          ),
        ),
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not enable device notifications. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enablingDeviceNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity inbox'),
        actions: [
          IconButton(
            tooltip: 'Enable device notifications',
            onPressed: _enablingDeviceNotifications
                ? null
                : _enableDeviceNotifications,
            icon: _enablingDeviceNotifications
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.notifications_active_outlined),
          ),
          IconButton(
            tooltip: 'Refresh activity inbox',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _InboxError(onRetry: _refresh),
        data: (items) => items.isEmpty
            ? RefreshIndicator(onRefresh: _refresh, child: const _InboxEmpty())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final id = item.string('id');
                    return _NotificationCard(
                      item: item,
                      markingRead: id != null && _markingRead.contains(id),
                      onRead: () => _markRead(item),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.markingRead,
    required this.onRead,
  });

  final HouseholdCollectionItem item;
  final bool markingRead;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) {
    final read = item.values['readAt'] != null;
    final title = item.string('title') ?? 'Household update';
    final body =
        item.string('body') ?? 'Open this update for the latest detail.';
    final stateLabel = read ? 'Read' : 'Unread';
    return Semantics(
      button: !read,
      enabled: !markingRead,
      label: '$stateLabel household update: $title. $body',
      hint: read
          ? 'Already read.'
          : markingRead
          ? 'Marking as read.'
          : 'Double tap to mark as read.',
      child: Card(
        child: ListTile(
          enabled: !markingRead,
          onTap: read || markingRead ? null : onRead,
          minVerticalPadding: 12,
          leading: CircleAvatar(
            backgroundColor: read
                ? Colors.transparent
                : PantryPalTheme.tomato.withValues(alpha: 0.14),
            child: markingRead
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    read
                        ? Icons.notifications_none
                        : Icons.notifications_active_outlined,
                    color: read
                        ? Theme.of(context).colorScheme.outline
                        : PantryPalTheme.tomato,
                  ),
          ),
          title: Text(title),
          subtitle: Text(body),
          trailing: Icon(
            read ? Icons.done : Icons.mark_email_unread_outlined,
            semanticLabel: stateLabel,
          ),
        ),
      ),
    );
  }
}

class _InboxError extends StatelessWidget {
  const _InboxError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load household updates',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Check your connection, then refresh the inbox.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh inbox'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _InboxEmpty extends StatelessWidget {
  const _InboxEmpty();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: constraints.maxHeight,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Semantics(
              liveRegion: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 48,
                    color: PantryPalTheme.tomato,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No household updates yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cook handoffs, shopping-date changes, and pantry rechecks appear here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
