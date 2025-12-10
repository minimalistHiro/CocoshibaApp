import 'package:flutter/material.dart';

import '../models/existing_event.dart';
import '../services/existing_event_service.dart';
import 'existing_event_create_page.dart';
import 'existing_event_edit_page.dart';

class ExistingEventsPage extends StatefulWidget {
  const ExistingEventsPage({super.key});

  @override
  State<ExistingEventsPage> createState() => _ExistingEventsPageState();
}

class _ExistingEventsPageState extends State<ExistingEventsPage> {
  final ExistingEventService _existingEventService = ExistingEventService();
  late final Stream<List<ExistingEvent>> _existingEventsStream =
      _existingEventService.watchExistingEvents();

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ExistingEventCreatePage()),
    );
  }

  void _openEdit(ExistingEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ExistingEventEditPage(event: event)),
    );
  }

  String _buildSubtitle(ExistingEvent event) {
    final organizer = event.organizer.isEmpty ? '主催者未設定' : '主催: ${event.organizer}';
    final capacity = event.capacity > 0 ? '定員: ${event.capacity}人' : '定員未設定';
    return '$organizer / $capacity';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('既存イベント編集'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<ExistingEvent>>(
                stream: _existingEventsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _StateMessage(
                      message: '既存イベントを読み込めませんでした: ${snapshot.error}',
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final events = snapshot.data ?? const <ExistingEvent>[];
                  if (events.isEmpty) {
                    return const _StateMessage(
                      message: '登録されている既存イベントがありません',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: event.color.withOpacity(0.2),
                          child: Icon(Icons.event_note, color: event.color),
                        ),
                        title: Text(
                          event.name.isEmpty ? '無題のイベント' : event.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          _buildSubtitle(event),
                          maxLines: 2,
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openEdit(event),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('新規既存イベントを作成'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
