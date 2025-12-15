import 'dart:async';

import 'package:flutter/material.dart';

import '../models/app_notification.dart';
import '../services/firebase_auth_service.dart';
import '../services/notification_service.dart';
import '../utils/relative_time_formatter.dart';
import '../widgets/notification_category_chip.dart';
import 'notification_create_page.dart';
import 'notification_detail_page.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({super.key});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final NotificationService _notificationService = NotificationService();
  final FirebaseAuthService _authService = FirebaseAuthService();

  late final Stream<Map<String, dynamic>?> _profileStream;
  late final Stream<Set<String>> _readNotificationIdsStream;

  @override
  void initState() {
    super.initState();
    _profileStream = _authService.watchCurrentUserProfile();
    _readNotificationIdsStream = _notificationService
        .watchReadNotificationIds(_authService.currentUser?.uid);
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NotificationCreatePage()),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お知らせを保存しました')),
      );
    }
  }

  void _openDetail(AppNotification notification, {required bool isOwner}) {
    unawaited(
      _notificationService.markAsRead(
        userId: _authService.currentUser?.uid,
        notificationId: notification.id,
      ),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailPage(
          notification: notification,
          isOwner: isOwner,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = _authService.currentUser?.uid;
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final isOwner = profile?['isOwner'] == true;
        return Scaffold(
          appBar: AppBar(
            title: const Text('お知らせ'),
            actions: isOwner
                ? [
                    IconButton(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add_circle_outline),
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: '新規お知らせ',
                    ),
                  ]
                : null,
          ),
          body: StreamBuilder<List<AppNotification>>(
            stream: _notificationService.watchNotifications(
              userId: userId,
              includeOwnerNotifications: isOwner,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'お知らせの取得に失敗しました。\n時間をおいて再度お試しください。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                );
              }
              final notifications = snapshot.data ?? [];
              if (notifications.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'まだお知らせがありません',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (isOwner) ...[
                        const SizedBox(height: 8),
                        Text(
                          '右上のプラスボタンから\n最初のお知らせを作成しましょう',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                );
              }
              return StreamBuilder<Set<String>>(
                stream: _readNotificationIdsStream,
                builder: (context, readSnapshot) {
                  final readIds = readSnapshot.data ?? const <String>{};
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        onTap: () => _openDetail(
                          notification,
                          isOwner: isOwner,
                        ),
                        isRead: readIds.contains(notification.id),
                      );
                    },
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.isRead,
  });

  final AppNotification notification;
  final VoidCallback onTap;
  final bool isRead;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      color: colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight:
                                isRead ? FontWeight.w600 : FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        NotificationCategoryChip(label: notification.category),
                        const SizedBox(height: 6),
                        Text(
                          notification.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: isRead
                              ? textTheme.bodyMedium
                                  ?.copyWith(color: Colors.grey.shade600)
                              : textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!isRead)
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 14),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                formatRelativeTime(notification.createdAt),
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
