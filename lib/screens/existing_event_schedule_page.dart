import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/existing_event.dart';
import '../services/event_service.dart';
import 'event_detail_page.dart';

class ExistingEventSchedulePage extends StatelessWidget {
  ExistingEventSchedulePage({
    super.key,
    required this.existingEvent,
  });

  final ExistingEvent existingEvent;
  final EventService _eventService = EventService();

  String _formatDateTimeRange(CalendarEvent event) {
    final start = event.startDateTime;
    final end = event.endDateTime;
    return '${start.year}/${start.month.toString().padLeft(2, '0')}/${start.day.toString().padLeft(2, '0')} '
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}〜'
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(existingEvent.name.isNotEmpty ? existingEvent.name : '既存イベント'),
      ),
      body: StreamBuilder<List<CalendarEvent>>(
        stream: _eventService.watchEventsByExistingEventId(existingEvent.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'イベントの取得に失敗しました: ${snapshot.error}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          final events = snapshot.data ?? const <CalendarEvent>[];
          if (events.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('この既存イベントの開催予定はありません'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final event = events[index];
              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailPage(event: event),
                    ),
                  ),
                  title: Text(
                    event.name.isEmpty ? '無題のイベント' : event.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDateTimeRange(event),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                      ),
                      if (event.organizer.isNotEmpty)
                        Text(
                          event.organizer,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                        ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
