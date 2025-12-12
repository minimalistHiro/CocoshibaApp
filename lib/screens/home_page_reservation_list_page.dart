import 'package:flutter/material.dart';

import '../models/home_page_content.dart';
import '../models/home_page_reservation_member.dart';
import '../services/home_page_reservation_service.dart';
import '../services/notification_service.dart';

class HomePageReservationListPage extends StatelessWidget {
  HomePageReservationListPage({super.key, required this.content});

  final HomePageContent content;
  final HomePageReservationService _reservationService =
      HomePageReservationService();
  final NotificationService _notificationService = NotificationService();
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '$year年$month月$day日';
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('予約者一覧'),
      ),
      body: StreamBuilder<List<HomePageReservationMember>>(
        stream: _reservationService.watchContentReservations(content.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                '予約者の取得に失敗しました',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          final members = snapshot.data ?? const <HomePageReservationMember>[];
          final orderedMembers = List<HomePageReservationMember>.from(members)
            ..sort((a, b) {
              if (a.isCompleted == b.isCompleted) {
                final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
                return bTime.compareTo(aTime);
              }
              return a.isCompleted ? 1 : -1;
            });
          if (members.isEmpty) {
            return Center(
              child: Text(
                '現在予約者はいません',
                style: theme.textTheme.bodyLarge,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orderedMembers.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '合計 ${orderedMembers.length} 件',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              }

              final member = orderedMembers[index - 1];
              final subtitleLines = <String>[];
              if (member.userEmail?.isNotEmpty ?? false) {
                subtitleLines.add(member.userEmail!);
              }
              final reservedLabel = _formatDateTime(member.reservedDate);
              final reservedTime = _formatTime(member.reservedDate);
              final pickupLabel = _formatDateTime(member.pickupDate);
              final pickupTime = _formatTime(member.pickupDate);
              if (reservedLabel.isNotEmpty) {
                subtitleLines.add(
                    '予約日: $reservedLabel${reservedTime.isNotEmpty ? ' $reservedTime' : ''}');
              }
              if (pickupLabel.isNotEmpty) {
                subtitleLines.add(
                    '受け取り日: $pickupLabel${pickupTime.isNotEmpty ? ' $pickupTime' : ''}');
              }
              subtitleLines.add('個数: ${member.quantity}');
              final initials = (member.userName?.trim() ?? '').isNotEmpty
                  ? member.userName!.trim().substring(0, 1)
                  : '?';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      child: Text(initials),
                    ),
                    title: Text(
                      member.userName?.isNotEmpty == true
                          ? member.userName!
                          : '予約者',
                      style: member.isCompleted
                          ? theme.textTheme.titleMedium
                              ?.copyWith(color: Colors.grey.shade600)
                          : null,
                    ),
                    subtitle: Text(
                      subtitleLines.join('\n'),
                      style: member.isCompleted
                          ? theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey.shade600)
                          : null,
                    ),
                    isThreeLine: subtitleLines.length > 1,
                    tileColor:
                        member.isCompleted ? Colors.grey.shade100 : null,
                    trailing: member.isCompleted
                        ? Text(
                            '完了済み',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.grey.shade600),
                          )
                        : FilledButton(
                            onPressed: () => _confirmComplete(context, member),
                            child: const Text('完了'),
                          ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmComplete(
    BuildContext context,
    HomePageReservationMember member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: const Text('この予約を完了済みにしますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('完了'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _reservationService.markReservationCompleted(
        contentId: content.id,
        reservationId: member.id,
        isCompleted: true,
      );
      if (member.userId?.isNotEmpty == true) {
        await _notificationService.createPersonalNotification(
          userId: member.userId!,
          title: '受け取りが完了しました',
          body: '${content.title} の受け取りが完了しました。ありがとうございました。',
          category: '予約',
        );
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('予約を完了済みにしました')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('完了の更新に失敗しました')),
      );
    }
  }
}
