import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/existing_event.dart';
import '../services/event_favorite_service.dart';
import '../services/event_interest_service.dart';
import '../services/event_service.dart';
import '../services/existing_event_service.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/event_list_card.dart';
import 'event_detail_page.dart';
import 'existing_event_schedule_page.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final EventService _eventService = EventService();
  final EventInterestService _interestService = EventInterestService();
  final EventFavoriteService _favoriteService = EventFavoriteService();
  final ExistingEventService _existingEventService = ExistingEventService();
  final FirebaseAuthService _authService = FirebaseAuthService();

  late final Stream<List<CalendarEvent>> _allEventsStream =
      _eventService.watchUpcomingEvents(from: DateTime.now(), limit: 0);

  late final Stream<List<CalendarEvent>> _reservedEventsStream;
  late final Stream<Set<String>> _interestIdsStream;
  late final Stream<List<FavoriteEventReference>> _favoriteRefsStream;
  late final Stream<Set<String>> _favoriteIdsStream;
  late final Stream<Set<String>> _existingEventIdsStream;
  late final Stream<List<ExistingEvent>> _existingEventsStream;

  String? get _userId => _authService.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _existingEventsStream = _existingEventService.watchExistingEvents();
    _existingEventIdsStream = _existingEventsStream
        .map((events) => events.map((event) => event.id).toSet());
    if (_userId == null) {
      _reservedEventsStream =
          Stream<List<CalendarEvent>>.value(const <CalendarEvent>[]);
      _interestIdsStream = Stream<Set<String>>.value(const <String>{});
      _favoriteRefsStream = Stream<List<FavoriteEventReference>>.value(
          const <FavoriteEventReference>[]);
      _favoriteIdsStream = Stream<Set<String>>.value(const <String>{});
    } else {
      _reservedEventsStream = _eventService.watchReservedEvents(_userId!);
      _interestIdsStream = _interestService.watchInterestedEventIds(_userId!);
      _favoriteRefsStream = _favoriteService.watchFavoriteReferences(_userId!);
      _favoriteIdsStream = _favoriteRefsStream.map((refs) {
        final ids = <String>{};
        for (final ref in refs) {
          ids.add(ref.targetId);
          final existingId = ref.existingEventId;
          final eventId = ref.eventId;
          if (existingId != null && existingId.isNotEmpty) {
            ids.add(existingId);
          }
          if (eventId != null && eventId.isNotEmpty) {
            ids.add(eventId);
          }
        }
        return ids;
      });
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
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('イベント'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'お気に入り'),
              Tab(text: '気になる'),
              Tab(text: '予約済み'),
              Tab(text: 'イベント一覧'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ExistingEventsTab(
              existingEventsStream: _existingEventsStream,
              favoriteIdsStream: _favoriteIdsStream,
              onToggleFavorite: _toggleExistingFavorite,
            ),
            _InterestedEventsTab(
              eventsStream: _allEventsStream,
              interestedIdsStream: _interestIdsStream,
              reservedEventsStream: _reservedEventsStream,
              onTapEvent: _openEventDetail,
              onToggleInterest: _toggleInterest,
              favoriteIdsStream: _favoriteIdsStream,
              onToggleFavorite: _toggleFavorite,
              existingEventIdsStream: _existingEventIdsStream,
            ),
            _ReservedEventsTab(
              reservedEventsStream: _reservedEventsStream,
              interestedIdsStream: _interestIdsStream,
              onTapEvent: _openEventDetail,
              onToggleInterest: _toggleInterest,
              favoriteIdsStream: _favoriteIdsStream,
              onToggleFavorite: _toggleFavorite,
              existingEventIdsStream: _existingEventIdsStream,
            ),
            _AllEventsTab(
              eventsStream: _allEventsStream,
              interestedIdsStream: _interestIdsStream,
              reservedEventsStream: _reservedEventsStream,
              onTapEvent: _openEventDetail,
              onToggleInterest: _toggleInterest,
              favoriteIdsStream: _favoriteIdsStream,
              onToggleFavorite: _toggleFavorite,
              existingEventIdsStream: _existingEventIdsStream,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(CalendarEvent event, bool isFavorite) async {
    final userId = _userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お気に入り機能を使うにはログインしてください')),
      );
      return;
    }
    try {
      await _favoriteService.toggleFavorite(
        userId: userId,
        event: event,
        isFavorite: isFavorite,
      );
      final message = isFavorite ? 'お気に入りを解除しました' : 'お気に入りに追加しました';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お気に入りの更新に失敗しました: $e')),
      );
    }
  }

  Future<void> _toggleExistingFavorite(
    ExistingEvent existingEvent,
    bool isFavorite,
  ) async {
    final userId = _userId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お気に入り機能を使うにはログインしてください')),
      );
      return;
    }
    try {
      await _favoriteService.toggleFavoriteForExistingEvent(
        userId: userId,
        existingEvent: existingEvent,
        isFavorite: isFavorite,
      );
      final message = isFavorite ? 'お気に入りを解除しました' : 'お気に入りに追加しました';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('お気に入りの更新に失敗しました: $e')),
      );
    }
  }
}

class _InterestedEventsTab extends StatelessWidget {
  const _InterestedEventsTab({
    required this.eventsStream,
    required this.interestedIdsStream,
    required this.reservedEventsStream,
    required this.onTapEvent,
    required this.onToggleInterest,
    required this.favoriteIdsStream,
    required this.onToggleFavorite,
    required this.existingEventIdsStream,
  });

  final Stream<List<CalendarEvent>> eventsStream;
  final Stream<Set<String>> interestedIdsStream;
  final Stream<List<CalendarEvent>> reservedEventsStream;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;
  final Stream<Set<String>> favoriteIdsStream;
  final void Function(CalendarEvent event, bool isFavorite) onToggleFavorite;
  final Stream<Set<String>> existingEventIdsStream;

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
                return StreamBuilder<Set<String>>(
                  stream: favoriteIdsStream,
                  builder: (context, favoriteIdsSnapshot) {
                    final favoriteIds = favoriteIdsSnapshot.data ?? <String>{};
                    return _EventListView(
                      events: events,
                      interestedIds: interestedIds,
                      reservedIds: reservedIds,
                      onTapEvent: onTapEvent,
                      onToggleInterest: onToggleInterest,
                      favoriteIds: favoriteIds,
                      onToggleFavorite: onToggleFavorite,
                      existingEventIdsStream: existingEventIdsStream,
                      showFavoriteButton: false,
                    );
                  },
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
    required this.favoriteIdsStream,
    required this.onToggleFavorite,
    required this.existingEventIdsStream,
  });

  final Stream<List<CalendarEvent>> reservedEventsStream;
  final Stream<Set<String>> interestedIdsStream;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;
  final Stream<Set<String>> favoriteIdsStream;
  final void Function(CalendarEvent event, bool isFavorite) onToggleFavorite;
  final Stream<Set<String>> existingEventIdsStream;

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
            return StreamBuilder<Set<String>>(
              stream: favoriteIdsStream,
              builder: (context, favoriteIdsSnapshot) {
                final favoriteIds = favoriteIdsSnapshot.data ?? <String>{};
                return _EventListView(
                  events: events,
                  interestedIds: interestedIds,
                  reservedIds: events.map((e) => e.id).toSet(),
                  favoriteIds: favoriteIds,
                  onTapEvent: onTapEvent,
                  onToggleInterest: onToggleInterest,
                  onToggleFavorite: onToggleFavorite,
                  statusLabel: '予約済み',
                  existingEventIdsStream: existingEventIdsStream,
                  showFavoriteButton: false,
                );
              },
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
    required this.favoriteIdsStream,
    required this.onToggleFavorite,
    required this.existingEventIdsStream,
  });

  final Stream<List<CalendarEvent>> eventsStream;
  final Stream<Set<String>> interestedIdsStream;
  final Stream<List<CalendarEvent>> reservedEventsStream;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;
  final Stream<Set<String>> favoriteIdsStream;
  final void Function(CalendarEvent event, bool isFavorite) onToggleFavorite;
  final Stream<Set<String>> existingEventIdsStream;

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
                return StreamBuilder<Set<String>>(
                  stream: favoriteIdsStream,
                  builder: (context, favoriteSnapshot) {
                    final favoriteIds = favoriteSnapshot.data ?? <String>{};
                    return _EventListView(
                      events: events,
                      interestedIds: interestedIds,
                      reservedIds: reservedIds,
                      onTapEvent: onTapEvent,
                      onToggleInterest: onToggleInterest,
                      favoriteIds: favoriteIds,
                      onToggleFavorite: onToggleFavorite,
                      existingEventIdsStream: existingEventIdsStream,
                      showFavoriteButton: false,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _ExistingEventsTab extends StatelessWidget {
  const _ExistingEventsTab({
    required this.existingEventsStream,
    required this.favoriteIdsStream,
    required this.onToggleFavorite,
  });

  final Stream<List<ExistingEvent>> existingEventsStream;
  final Stream<Set<String>> favoriteIdsStream;
  final void Function(ExistingEvent event, bool isFavorite) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ExistingEvent>>(
      stream: existingEventsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _CenteredProgress();
        }
        if (snapshot.hasError) {
          return const _ErrorState(message: '既存イベントを取得できませんでした');
        }
        final events = snapshot.data ?? const <ExistingEvent>[];
        if (events.isEmpty) {
          return const _EmptyState(message: '登録されている既存イベントがありません');
        }
        return StreamBuilder<Set<String>>(
          stream: favoriteIdsStream,
          builder: (context, favoriteSnapshot) {
            final favoriteIds = favoriteSnapshot.data ?? const <String>{};
            final sortedEvents = List<ExistingEvent>.from(events)
              ..sort((a, b) {
                final aFav = favoriteIds.contains(a.id);
                final bFav = favoriteIds.contains(b.id);
                if (aFav == bFav) return 0;
                return aFav ? -1 : 1;
              });
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sortedEvents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final event = sortedEvents[index];
                final isFavorite = favoriteIds.contains(event.id);
                return Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => _openSchedule(context, event),
                    leading: _ExistingEventThumbnail(
                      imageUrl: event.imageUrls.isNotEmpty
                          ? event.imageUrls.first
                          : null,
                      color: Color(event.colorValue),
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
                          event.organizer.isEmpty ? '主催者未設定' : event.organizer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.capacity > 0
                              ? '定員: ${event.capacity}人'
                              : '定員未設定',
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      onPressed: () => onToggleFavorite(event, isFavorite),
                      icon: Icon(
                        isFavorite ? Icons.star : Icons.star_border,
                        color: isFavorite
                            ? Colors.amber.shade600
                            : Colors.grey.shade500,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _openSchedule(BuildContext context, ExistingEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExistingEventSchedulePage(existingEvent: event),
      ),
    );
  }
}

class _ExistingEventThumbnail extends StatelessWidget {
  const _ExistingEventThumbnail({
    this.imageUrl,
    required this.color,
  });

  final String? imageUrl;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 56,
      height: 56,
      color: color.withOpacity(0.15),
      alignment: Alignment.center,
      child: Icon(Icons.event_note, color: color),
    );
    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      ),
    );
  }
}

class _EventListView extends StatelessWidget {
  const _EventListView({
    required this.events,
    required this.interestedIds,
    required this.onTapEvent,
    required this.onToggleInterest,
    required this.favoriteIds,
    required this.onToggleFavorite,
    required this.existingEventIdsStream,
    this.showFavoriteButton = true,
    this.reservedIds = const <String>{},
    this.statusLabel,
  });

  final List<CalendarEvent> events;
  final Set<String> interestedIds;
  final Set<String> reservedIds;
  final Set<String> favoriteIds;
  final ValueChanged<CalendarEvent> onTapEvent;
  final void Function(CalendarEvent event, bool isInterested) onToggleInterest;
  final void Function(CalendarEvent event, bool isFavorite) onToggleFavorite;
  final Stream<Set<String>> existingEventIdsStream;
  final String? statusLabel;
  final bool showFavoriteButton;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Set<String>>(
      stream: existingEventIdsStream,
      builder: (context, snapshot) {
        final existingEventIds = snapshot.data ?? const <String>{};
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemBuilder: (context, index) {
            final event = events[index];
            final isInterested = interestedIds.contains(event.id);
            final isReserved = reservedIds.contains(event.id);
            final isFavorite = favoriteIds.contains(event.id) ||
                (event.existingEventId != null &&
                    favoriteIds.contains(event.existingEventId!));
            final canShowFavoriteButton = _canShowFavoriteButton(
              event,
              existingEventIds,
            );
            return EventListCard(
              event: event,
              onTap: () => onTapEvent(event),
              isInterested: isInterested,
              isReserved: isReserved,
              isFavorite: isFavorite,
              statusLabel: statusLabel,
              showFavoriteButton: showFavoriteButton && canShowFavoriteButton,
              canShowFavoriteButton: canShowFavoriteButton,
              onToggleInterest: () =>
                  onToggleInterest(event, isInterested),
              onToggleFavorite: showFavoriteButton && canShowFavoriteButton
                  ? () => onToggleFavorite(event, isFavorite)
                  : null,
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: events.length,
        );
      },
    );
  }

  bool _canShowFavoriteButton(
    CalendarEvent event,
    Set<String> existingEventIds,
  ) {
    final existingId = (event.existingEventId ?? '').trim();
    if (existingId.isEmpty) return false;
    if (existingEventIds.isEmpty) return true;
    return existingEventIds.contains(existingId);
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
