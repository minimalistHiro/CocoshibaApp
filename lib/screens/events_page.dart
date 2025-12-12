import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../services/event_interest_service.dart';
import '../services/event_service.dart';
import '../services/firebase_auth_service.dart';
import 'event_detail_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final EventService _eventService = EventService();
  final EventInterestService _interestService = EventInterestService();
  final FirebaseAuthService _authService = FirebaseAuthService();

  late final Stream<List<CalendarEvent>> _allEventsStream =
      _eventService.watchUpcomingEvents(from: DateTime.now(), limit: 0);

  late final Stream<List<CalendarEvent>> _reservedEventsStream;
  late final Stream<Set<String>> _interestIdsStream;

  String? get _userId => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (_userId == null) {
      _reservedEventsStream =
          Stream<List<CalendarEvent>>.value(const <CalendarEvent>[]);
      _interestIdsStream = Stream<Set<String>>.value(const <String>{});
    } else {
      _reservedEventsStream = _eventService.watchReservedEvents(_userId!);
      _interestIdsStream = _interestService.watchInterestedEventIds(_userId!);
    }
  }

  void _openEventDetail(CalendarEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(event: event),
      ),
    );
  }

  Future<void> _toggleInterest(CalendarEvent event, bool isInterested) async {
    final userId = _userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('気になる機能を使うにはログインしてください')),
      );
      return;
    }
    try {
      await _interestService.toggleInterest(
        userId: userId,
        event: event,
        isInterested: isInterested,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('気になるの更新に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('イベント'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '気になる'),
              Tab(text: '予約済み'),
              Tab(text: 'イベント一覧'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _InterestedEventsTab(
              eventsStream: _allEventsStream,
              interestedIdsStream: _interestIdsStream,
              reservedEventsStream: _reservedEventsStream,
              onTapEvent: _openEventDetail,
              onToggleInterest: _toggleInterest,
            ),
            _ReservedEventsTab(
              reservedEventsStream: _reservedEventsStream,
              interestedIdsStream: _interestIdsStream,
              onTapEvent: _openEventDetail,
              onToggleInterest: _toggleInterest,
            ),
            _AllEventsTab(
              eventsStream: _allEventsStream,
              interestedIdsStream: _interestIdsStream,
              reservedEventsStream: _reservedEventsStream,
              onTapEvent: _openEventDetail,
              onToggleInterest: _toggleInterest,
            ),
          ],
        ),
      ),
    );
  }
}

class _InterestedEventsTab extends StatelessWidget {
  const _InterestedEventsTab({
    required this.eventsStream,
    required this.interestedIdsStream,
    required this.reservedEventsStream,
    required this.onTapEvent,
    required this.onToggleInterest,
  });

  final Stream<List<CalendarEvent>> eventsStream;
  final Stream<Set<String>> interestedIdsStream;
  final Stream<List<CalendarEvent>> reservedEventsStream;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: interestedIdsStream,
      builder: (context, favoriteSnapshot) {
        final interestedIds = favoriteSnapshot.data ?? <String>{};
        final favoriteState = favoriteSnapshot.connectionState;
        return StreamBuilder<List<CalendarEvent>>(
          stream: eventsStream,
          builder: (context, eventsSnapshot) {
            if (favoriteState == ConnectionState.waiting ||
                eventsSnapshot.connectionState == ConnectionState.waiting) {
              return const _CenteredProgress();
            }

            if ((favoriteSnapshot.hasError || eventsSnapshot.hasError)) {
              return const _ErrorState(message: 'イベント情報を取得できませんでした');
            }

            final events = (eventsSnapshot.data ?? const <CalendarEvent>[])
                .where((event) => interestedIds.contains(event.id))
                .toList(growable: false);

            if (events.isEmpty) {
              return const _EmptyState(message: '気になるイベントはまだありません');
            }

            return StreamBuilder<List<CalendarEvent>>(
              stream: reservedEventsStream,
              builder: (context, reservedSnapshot) {
                final reservedIds =
                    (reservedSnapshot.data ?? const <CalendarEvent>[])
                        .map((event) => event.id)
                        .toSet();
                return _EventListView(
                  events: events,
                  interestedIds: interestedIds,
                  reservedIds: reservedIds,
                  onTapEvent: onTapEvent,
                  onToggleInterest: onToggleInterest,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ReservedEventsTab extends StatelessWidget {
  const _ReservedEventsTab({
    required this.reservedEventsStream,
    required this.interestedIdsStream,
    required this.onTapEvent,
    required this.onToggleInterest,
  });

  final Stream<List<CalendarEvent>> reservedEventsStream;
  final Stream<Set<String>> interestedIdsStream;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: reservedEventsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenteredProgress();
        }
        if (snapshot.hasError) {
          return const _ErrorState(message: '予約情報を取得できませんでした');
        }
        final events = snapshot.data ?? const <CalendarEvent>[];
        if (events.isEmpty) {
          return const _EmptyState(message: '予約済みのイベントはまだありません');
        }
        return StreamBuilder<Set<String>>(
          stream: interestedIdsStream,
          builder: (context, favoriteSnapshot) {
            final interestedIds = favoriteSnapshot.data ?? <String>{};
            return _EventListView(
              events: events,
              interestedIds: interestedIds,
              reservedIds: events.map((e) => e.id).toSet(),
              onTapEvent: onTapEvent,
              onToggleInterest: onToggleInterest,
              statusLabel: '予約済み',
            );
          },
        );
      },
    );
  }
}

class _AllEventsTab extends StatelessWidget {
  const _AllEventsTab({
    required this.eventsStream,
    required this.interestedIdsStream,
    required this.reservedEventsStream,
    required this.onTapEvent,
    required this.onToggleInterest,
  });

  final Stream<List<CalendarEvent>> eventsStream;
  final Stream<Set<String>> interestedIdsStream;
  final Stream<List<CalendarEvent>> reservedEventsStream;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CalendarEvent>>(
      stream: eventsStream,
      builder: (context, eventsSnapshot) {
        if (eventsSnapshot.connectionState == ConnectionState.waiting) {
          return const _CenteredProgress();
        }
        if (eventsSnapshot.hasError) {
          return const _ErrorState(message: 'イベント一覧を取得できませんでした');
        }

        final events = eventsSnapshot.data ?? const <CalendarEvent>[];
        if (events.isEmpty) {
          return const _EmptyState(message: '表示できるイベントがありません');
        }

        return StreamBuilder<Set<String>>(
          stream: interestedIdsStream,
          builder: (context, favoriteSnapshot) {
            final interestedIds = favoriteSnapshot.data ?? <String>{};
            return StreamBuilder<List<CalendarEvent>>(
              stream: reservedEventsStream,
              builder: (context, reservedSnapshot) {
                final reservedIds =
                    (reservedSnapshot.data ?? const <CalendarEvent>[])
                        .map((event) => event.id)
                        .toSet();
                return _EventListView(
                  events: events,
                  interestedIds: interestedIds,
                  reservedIds: reservedIds,
                  onTapEvent: onTapEvent,
                  onToggleInterest: onToggleInterest,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EventListView extends StatelessWidget {
  const _EventListView({
    required this.events,
    required this.interestedIds,
    required this.onTapEvent,
    required this.onToggleInterest,
    this.reservedIds = const <String>{},
    this.statusLabel,
  });

  final List<CalendarEvent> events;
  final Set<String> interestedIds;
  final Set<String> reservedIds;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;
  final String? statusLabel;

  String _formatDate(DateTime dateTime) {
    final y = dateTime.year;
    final m = dateTime.month.toString().padLeft(2, '0');
    final d = dateTime.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String _formatTimeRange(CalendarEvent event) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final start =
        '${twoDigits(event.startDateTime.hour)}:${twoDigits(event.startDateTime.minute)}';
    final end =
        '${twoDigits(event.endDateTime.hour)}:${twoDigits(event.endDateTime.minute)}';
    return '$start〜$end';
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final event = events[index];
        final isInterested = interestedIds.contains(event.id);
        final isReserved = reservedIds.contains(event.id);
        return Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTapEvent(event),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventThumbnail(
                    imageUrl: event.imageUrls.isNotEmpty
                        ? event.imageUrls.first
                        : null),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  event.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_formatDate(event.startDateTime)}  ${_formatTimeRange(event)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey.shade600),
                                ),
                                if (event.organizer.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      event.organizer,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Colors.grey.shade600),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          _InterestButton(
                            isInterested: isInterested,
                            onPressed: () =>
                                onToggleInterest(event, isInterested),
                          ),
                        ],
                      ),
                      if (statusLabel != null || isReserved)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              if (isReserved)
                                _StatusChip(
                                  label: statusLabel ?? '予約済み',
                                  color: Colors.green.shade600,
                                ),
                              if (statusLabel != null && !isReserved)
                                _StatusChip(
                                  label: statusLabel!,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemCount: events.length,
    );
  }
}

class _InterestButton extends StatelessWidget {
  const _InterestButton({
    required this.isInterested,
    required this.onPressed,
  });

  final bool isInterested;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isInterested ? Colors.pinkAccent : Colors.grey.shade500;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(
            isInterested ? Icons.favorite : Icons.favorite_border,
            color: color,
          ),
        ),
        Text(
          '気になる',
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _EventThumbnail extends StatelessWidget {
  const _EventThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: 160,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Icon(Icons.event, color: Colors.grey.shade500, size: 48),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return SizedBox(
      height: 160,
      child: Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        },
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _CenteredProgress extends StatelessWidget {
  const _CenteredProgress();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.red.shade400),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
