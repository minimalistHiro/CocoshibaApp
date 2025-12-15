import 'package:flutter/material.dart';

import '../models/existing_event.dart';
import '../services/existing_event_service.dart';
import '../services/firebase_auth_service.dart';
import 'existing_event_create_page.dart';
import 'existing_event_edit_page.dart';

class ExistingEventsPage extends StatefulWidget {
  const ExistingEventsPage({super.key});

  @override
  State<ExistingEventsPage> createState() => _ExistingEventsPageState();
}

class _ExistingEventsPageState extends State<ExistingEventsPage> {
  final ExistingEventService _existingEventService = ExistingEventService();
  final FirebaseAuthService _authService = FirebaseAuthService();
  late final Stream<List<ExistingEvent>> _existingEventsStream =
      _existingEventService.watchExistingEvents();
  late final Stream<Map<String, dynamic>?> _profileStream =
      _authService.watchCurrentUserProfile();

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

  Widget _buildEventCard(ExistingEvent event) {
    final imageUrl = event.imageUrls.isNotEmpty ? event.imageUrls.first : null;
    return Card(
      child: ListTile(
        onTap: () => _openEdit(event),
        leading: _ExistingEventThumbnail(
          imageUrl: imageUrl,
          color: event.color,
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
        trailing: PopupMenuButton<_ExistingEventAction>(
          onSelected: (action) {
            switch (action) {
              case _ExistingEventAction.edit:
                _openEdit(event);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _ExistingEventAction.edit,
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('編集'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profileStream,
      builder: (context, profileSnapshot) {
        final profile = profileSnapshot.data;
        final isOwner = profile?['isOwner'] == true;

        return Scaffold(
          appBar: AppBar(
            title: const Text('既存イベント編集'),
            actions: isOwner
                ? [
                    IconButton(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add_circle_outline),
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: '新規既存イベント',
                    ),
                  ]
                : null,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 24),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _buildEventCard(events[index]),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

class _ExistingEventThumbnail extends StatelessWidget {
  const _ExistingEventThumbnail({this.imageUrl, required this.color});

  final String? imageUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: AspectRatio(
          aspectRatio: 1,
          child: imageUrl == null || imageUrl!.isEmpty
              ? Container(
                  color: color.withOpacity(0.15),
                  child: Icon(
                    Icons.event_note,
                    color: color,
                  ),
                )
              : Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: color.withOpacity(0.15),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: color,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

enum _ExistingEventAction { edit }
