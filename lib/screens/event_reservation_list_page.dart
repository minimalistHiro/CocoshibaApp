import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/event_reservation_member.dart';
import '../services/event_service.dart';

class EventReservationListPage extends StatelessWidget {
  EventReservationListPage({super.key, required this.event});

  final CalendarEvent event;
  final EventService _eventService = EventService();

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    final year = dateTime.year;
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$year年$month月$day日 $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('予約者リスト'),
      ),
      body: StreamBuilder<List<EventReservationMember>>(
        stream: _eventService.watchEventReservations(event.id),
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

          final members = snapshot.data ?? const <EventReservationMember>[];
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
            itemCount: members.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '合計 ${members.length} 名',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                );
              }

              final member = members[index - 1];
              final subtitleLines = <String>[];
              if (member.area != null && member.area!.isNotEmpty) {
                subtitleLines.add('エリア: ${member.area}');
              }
              if (member.email != null && member.email!.isNotEmpty) {
                subtitleLines.add(member.email!);
              }
              final reservedLabel = _formatDateTime(member.reservedAt);
              if (reservedLabel.isNotEmpty) {
                subtitleLines.add('予約日時: $reservedLabel');
              }
              final avatarImage = (member.photoUrl != null &&
                      member.photoUrl!.isNotEmpty)
                  ? NetworkImage(member.photoUrl!)
                  : null;
              final initials = member.name.trim().isNotEmpty
                  ? member.name.trim().substring(0, 1)
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
                      backgroundImage: avatarImage,
                      child: avatarImage == null ? Text(initials) : null,
                    ),
                    title: Text(member.name),
                    subtitle: subtitleLines.isEmpty
                        ? null
                        : Text(subtitleLines.join('\n')),
                    isThreeLine: subtitleLines.length > 1,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
