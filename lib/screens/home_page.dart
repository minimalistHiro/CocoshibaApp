import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/calendar_event.dart';
import '../models/campaign.dart';
import '../models/home_page_content.dart';
import '../services/event_service.dart';
import '../services/event_favorite_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/notification_service.dart';
import '../services/home_page_content_service.dart';
import '../services/campaign_service.dart';
import '../widgets/point_card.dart';
import '../widgets/event_card.dart';
import 'menu_list_page.dart';
import 'home_page_reservation_history_page.dart';
import 'notification_page.dart';
import 'point_history_page.dart';
import 'home_page_content_detail_page.dart';
import 'event_detail_page.dart';
import 'events_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final EventService _eventService = EventService();
  final EventFavoriteService _favoriteService = EventFavoriteService();
  final NotificationService _notificationService = NotificationService();
  final HomePageContentService _homePageContentService =
      HomePageContentService();
  final CampaignService _campaignService = CampaignService();
  List<Campaign> _cachedActiveCampaigns = const [];
  static final Uri _bookOrderFormUri = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSda9VfM-EMborsiY-h11leW1uXgNUPdwv3RFb4_I1GjwFSoOQ/viewform?pli=1',
  );
  late Future<int> _pointsFuture;
  late final Stream<List<CalendarEvent>> _reservedEventsStream;
  late final Stream<List<FavoriteEventReference>> _favoriteRefsStream;
  late final Stream<List<CalendarEvent>> _upcomingEventsStream;
  late final Stream<List<HomePageContent>> _homePageContentsStream;
  late final Stream<List<Campaign>> _activeCampaignsStream;

  Stream<T> _singleValueStream<T>(T value) {
    return Stream<T>.multi((controller) {
      controller.add(value);
      controller.close();
    });
  }

  Stream<T> _shareReplayLatest<T>(Stream<T> source) {
    final listeners = <MultiStreamController<T>>{};
    StreamSubscription<T>? subscription;
    T? latestValue;
    var hasLatestValue = false;
    var isDone = false;

    void ensureSubscribed() {
      if (subscription != null || isDone) return;
      subscription = source.listen(
        (value) {
          latestValue = value;
          hasLatestValue = true;
          for (final listener in listeners.toList(growable: false)) {
            listener.add(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          for (final listener in listeners.toList(growable: false)) {
            listener.addError(error, stackTrace);
          }
        },
        onDone: () {
          isDone = true;
          subscription = null;
          for (final listener in listeners.toList(growable: false)) {
            listener.close();
          }
          listeners.clear();
        },
      );
    }

    Future<void> maybeUnsubscribe() async {
      if (listeners.isNotEmpty) return;
      final current = subscription;
      subscription = null;
      await current?.cancel();
    }

    return Stream<T>.multi((controller) {
      if (hasLatestValue) {
        controller.add(latestValue as T);
      }
      if (isDone) {
        controller.close();
        return;
      }
      listeners.add(controller);
      ensureSubscribed();
      controller.onCancel = () async {
        listeners.remove(controller);
        await maybeUnsubscribe();
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _pointsFuture = _authService.fetchCurrentUserPoints();
    final currentUser = _authService.currentUser;
    final reservedStream = currentUser == null
        ? _singleValueStream<List<CalendarEvent>>(const [])
        : _eventService
            .watchReservedEvents(currentUser.uid)
            .map((events) => events.take(7).toList(growable: false));
    _reservedEventsStream = reservedStream
        .distinct((a, b) => _sameBySignature(a, b, _eventSignature));

    final favoriteRefsStream = currentUser == null
        ? _singleValueStream<List<FavoriteEventReference>>(const [])
        : _favoriteService.watchFavoriteReferences(currentUser.uid);
    _favoriteRefsStream = favoriteRefsStream
        .distinct((a, b) => _sameBySignature(a, b, _favoriteSignature));

    final upcomingEventsSource = _eventService
        .watchUpcomingEvents(limit: 30)
        .distinct((a, b) => _sameBySignature(a, b, _eventSignature));
    _upcomingEventsStream = _shareReplayLatest(upcomingEventsSource);

    _homePageContentsStream = _homePageContentService
        .watchContents()
        .distinct((a, b) => _sameBySignature(a, b, _homeContentSignature));

    _activeCampaignsStream = _campaignService
        .watchActiveCampaigns()
        .distinct((a, b) => _sameBySignature(a, b, _campaignSignature));
  }

  bool _sameBySignature<T>(
    List<T> a,
    List<T> b,
    String Function(T item) signature,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (signature(a[i]) != signature(b[i])) return false;
    }
    return true;
  }

  String _eventSignature(CalendarEvent event) {
    return '${event.id}/${event.startDateTime.millisecondsSinceEpoch}/${event.endDateTime.millisecondsSinceEpoch}/${event.imageUrls.length}';
  }

  String _favoriteSignature(FavoriteEventReference ref) {
    return '${ref.targetId}/${ref.eventId ?? ''}/${ref.existingEventId ?? ''}';
  }

  String _homeContentSignature(HomePageContent content) {
    final updated = content.updatedAt?.millisecondsSinceEpoch ?? 0;
    return '${content.id}/${content.displayOrder}/$updated/${content.imageUrls.length}';
  }

  String _campaignSignature(Campaign campaign) {
    final end = campaign.displayEnd?.millisecondsSinceEpoch ?? 0;
    final updated = campaign.updatedAt?.millisecondsSinceEpoch ?? 0;
    return '${campaign.id}/$end/$updated';
  }

  Campaign _selectPriorityCampaign(List<Campaign> campaigns) {
    if (campaigns.length == 1) return campaigns.first;
    return campaigns.reduce((a, b) {
      final aEnd = a.displayEnd ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bEnd = b.displayEnd ?? DateTime.fromMillisecondsSinceEpoch(0);
      if (aEnd.isBefore(bEnd)) return a;
      if (bEnd.isBefore(aEnd)) return b;
      final aCreated = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bCreated = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aCreated.isBefore(bCreated) ? a : b;
    });
  }

  void _showNotification(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NotificationPage(),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _authService.watchCurrentUserProfile(),
      builder: (context, snapshot) {
        final name = (snapshot.data?['name'] as String?) ?? 'お客さま';
        return Row(
          children: [
            Image.asset(
              'assets/images/cocoshiba_logo_g.png',
              height: 48,
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$name さん',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'ようこそ！',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(width: 16),
            StreamBuilder<bool>(
              stream: _notificationService.watchHasUnreadNotifications(
                _authService.currentUser?.uid,
                includeOwnerNotifications: snapshot.data?['isOwner'] == true,
              ),
              initialData: false,
              builder: (context, unreadSnapshot) {
                final hasUnread = unreadSnapshot.data ?? false;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      onPressed: () => _showNotification(context),
                      icon: const Icon(
                        Icons.notifications_outlined,
                        size: 30,
                      ),
                    ),
                    if (hasUnread)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _refreshPoints() async {
    final future = _authService.fetchCurrentUserPoints();
    setState(() {
      _pointsFuture = future;
    });
    try {
      await future;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ポイントを更新しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ポイントの取得に失敗しました')),
      );
    }
  }

  void _showShortcutMessage(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label は準備中です')),
    );
  }

  void _openPointHistoryPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PointHistoryPage(),
      ),
    );
  }

  void _openMenuList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MenuListPage(),
      ),
    );
  }

  void _openReservationHistory() {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('予約一覧を見るにはログインしてください')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomePageReservationHistoryPage(userId: user.uid),
      ),
    );
  }

  Future<void> _openBookOrderPage() async {
    if (!await launchUrl(
      _bookOrderFormUri,
      mode: LaunchMode.externalApplication,
    )) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('本の注文ページを開けませんでした')),
      );
    }
  }

  void _openEventsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const EventsPage(),
      ),
    );
  }

  void _openEventDetail(CalendarEvent event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventDetailPage(event: event),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  _buildHeader(context),
                  const SizedBox(height: 32),
                  FutureBuilder<int>(
                    future: _pointsFuture,
                    builder: (context, snapshot) {
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;
                      final points = snapshot.data ?? 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PointCard(
                            points: points,
                            isLoading: isLoading,
                            onRefresh: () {
                              _refreshPoints();
                            },
                          ),
                          if (snapshot.hasError && !isLoading)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                'ポイントの取得に失敗しました。更新ボタンをお試しください。',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Material(
                    color: Theme.of(context).colorScheme.primary,
                    elevation: 4,
                    shadowColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(36),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _ShortcutItem(
                              icon: Icons.event_available_outlined,
                              label: 'イベント',
                              onTap: _openEventsPage,
                            ),
                          ),
                          Expanded(
                            child: _ShortcutItem(
                              icon: Icons.restaurant_menu_outlined,
                              label: 'メニュー',
                              onTap: _openMenuList,
                            ),
                          ),
                          Expanded(
                            child: _ShortcutItem(
                              icon: Icons.assignment_turned_in_outlined,
                              label: '予約',
                              onTap: _openReservationHistory,
                            ),
                          ),
                          Expanded(
                            child: _ShortcutItem(
                              icon: Icons.history,
                              label: 'ポイント履歴',
                              onTap: _openPointHistoryPage,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  StreamBuilder<List<Campaign>>(
                    stream: _activeCampaignsStream,
                    initialData: _cachedActiveCampaigns,
                    builder: (context, snapshot) {
                      final campaigns = snapshot.data ?? const <Campaign>[];
                      if (campaigns.isNotEmpty) {
                        _cachedActiveCampaigns = campaigns;
                      }
                      final isLoading =
                          snapshot.connectionState == ConnectionState.waiting;

                      if (isLoading && campaigns.isEmpty) {
                        if (_cachedActiveCampaigns.isNotEmpty) {
                          return const SizedBox.shrink();
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }

                      if (campaigns.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      final priorityCampaign =
                          _selectPriorityCampaign(campaigns);
                      final screenWidth = MediaQuery.sizeOf(context).width;
                      final dpr = MediaQuery.of(context).devicePixelRatio;
                      final campaignWidth =
                          (screenWidth - 48).clamp(0.0, double.infinity);
                      final campaignHeight = campaignWidth / 2;
                      final campaignCacheWidth = (campaignWidth * dpr).round();
                      final campaignCacheHeight =
                          (campaignHeight * dpr).round();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'キャンペーン',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          AspectRatio(
                            aspectRatio: 2 / 1,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: _CampaignSlide(
                                campaign: priorityCampaign,
                                imageCacheWidth: campaignCacheWidth > 0
                                    ? campaignCacheWidth
                                    : null,
                                imageCacheHeight: campaignCacheHeight > 0
                                    ? campaignCacheHeight
                                    : null,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<List<CalendarEvent>>(
                    stream: _reservedEventsStream,
                    builder: (context, snapshot) {
                      final reservedEvents =
                          (snapshot.data ?? const <CalendarEvent>[])
                              .take(7)
                              .toList(growable: false);

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          reservedEvents.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _SectionHeader(title: '予約したイベント'),
                            SizedBox(height: 12),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ],
                        );
                      }

                      if (reservedEvents.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: '予約したイベント'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                '予約したイベントはまだありません',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(title: '予約したイベント'),
                          const SizedBox(height: 12),
                          _UpcomingEventsScroller(
                            events: reservedEvents,
                            onEventTap: _openEventDetail,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  StreamBuilder<List<FavoriteEventReference>>(
                    stream: _favoriteRefsStream,
                    builder: (context, favoriteSnapshot) {
                      final favoriteRefs = favoriteSnapshot.data ?? const [];
                      final favoriteExistingIds = favoriteRefs
                          .map((ref) => ref.existingEventId?.trim())
                          .where((id) => id != null && id!.isNotEmpty)
                          .cast<String>()
                          .toSet();

                      return StreamBuilder<List<CalendarEvent>>(
                        stream: _upcomingEventsStream,
                        builder: (context, eventSnapshot) {
                          final upcomingEvents =
                              eventSnapshot.data ?? const <CalendarEvent>[];
                          final favoriteEvents = upcomingEvents
                              .where(
                                (event) =>
                                    event.existingEventId != null &&
                                    favoriteExistingIds
                                        .contains(event.existingEventId),
                              )
                              .take(7)
                              .toList(growable: false);

                          final isLoading = favoriteSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              eventSnapshot.connectionState ==
                                  ConnectionState.waiting;

                          if (isLoading && favoriteEvents.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                _SectionHeader(title: 'お気に入りのイベント'),
                                SizedBox(height: 12),
                                Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 32),
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ],
                            );
                          }

                          if (favoriteEvents.isEmpty) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader(title: 'お気に入りのイベント'),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Text(
                                    'お気に入りのイベントはまだありません',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Colors.grey.shade600),
                                  ),
                                ),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader(title: 'お気に入りのイベント'),
                              const SizedBox(height: 12),
                              _UpcomingEventsScroller(
                                events: favoriteEvents,
                                onEventTap: _openEventDetail,
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  StreamBuilder<List<CalendarEvent>>(
                    stream: _upcomingEventsStream,
                    builder: (context, snapshot) {
                      final upcomingEvents =
                          (snapshot.data ?? const <CalendarEvent>[])
                              .take(7)
                              .toList(growable: false);

                      if (snapshot.connectionState == ConnectionState.waiting &&
                          upcomingEvents.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            _SectionHeader(title: '直近のイベント'),
                            SizedBox(height: 12),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          ],
                        );
                      }

                      if (upcomingEvents.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader(title: '直近のイベント'),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Text(
                                '直近のイベントはまだありません',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Colors.grey.shade600),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(title: '直近のイベント'),
                          const SizedBox(height: 12),
                          _UpcomingEventsScroller(
                            events: upcomingEvents,
                            onEventTap: _openEventDetail,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'ホームページ',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          StreamBuilder<List<HomePageContent>>(
            stream: _homePageContentsStream,
            builder: (context, snapshot) {
              final contents = snapshot.data ?? const <HomePageContent>[];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final theme = Theme.of(context);
              final screenWidth = MediaQuery.sizeOf(context).width;
              final dpr = MediaQuery.of(context).devicePixelRatio;
              final tileWidth =
                  ((screenWidth - 48 - 16) / 2).clamp(0.0, double.infinity);
              final tileCacheWidth = (tileWidth * dpr).round();
              final tileCacheHeight = (tileWidth * dpr).round();

              if (isLoading && contents.isEmpty) {
                return const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                );
              }

              if (contents.isEmpty) {
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Text(
                        'ホームページがまだ登録されていません',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final content = contents[index];
                      return RepaintBoundary(
                        child: _HomePageContentCard(
                          content: content,
                          imageCacheWidth:
                              tileCacheWidth > 0 ? tileCacheWidth : null,
                          imageCacheHeight:
                              tileCacheHeight > 0 ? tileCacheHeight : null,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    HomePageContentDetailPage(content: content),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    childCount: contents.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverToBoxAdapter(
              child: _BookOrderButton(onTap: _openBookOrderPage),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _CampaignSlide extends StatelessWidget {
  const _CampaignSlide({
    required this.campaign,
    this.imageCacheWidth,
    this.imageCacheHeight,
  });

  final Campaign campaign;
  final int? imageCacheWidth;
  final int? imageCacheHeight;
  static const bool _disableNetworkImages =
      bool.fromEnvironment('DISABLE_NETWORK_IMAGES');

  @override
  Widget build(BuildContext context) {
    final hasImage = campaign.imageUrl != null && campaign.imageUrl!.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_disableNetworkImages)
          Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_outlined, size: 48),
          )
        else
          hasImage
              ? Image.network(
                  campaign.imageUrl!,
                  fit: BoxFit.cover,
                  cacheWidth: imageCacheWidth,
                  cacheHeight: imageCacheHeight,
                  filterQuality: FilterQuality.none,
                  isAntiAlias: false,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined, size: 48),
                  ),
                )
              : Container(
                  color: Colors.grey.shade200,
                  child: Center(
                    child: Icon(
                      Icons.local_offer_outlined,
                      size: 48,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.55),
                Colors.black.withOpacity(0.1),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                campaign.title.isEmpty ? 'キャンペーン' : campaign.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                campaign.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UpcomingEventsScroller extends StatelessWidget {
  const _UpcomingEventsScroller({
    required this.events,
    required this.onEventTap,
  });

  final List<CalendarEvent> events;
  final ValueChanged<CalendarEvent> onEventTap;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final screenWidth = MediaQuery.sizeOf(context).width;
    const horizontalPadding = 24 * 2;
    const double crossAxisSpacing = 16;
    final availableWidth = (screenWidth - horizontalPadding - crossAxisSpacing)
        .clamp(0.0, double.infinity);
    final cardWidth = availableWidth / 2;
    const imageAspectRatio = 1;
    final imageHeight = cardWidth / imageAspectRatio;
    final imageCacheWidth = (cardWidth * dpr).round();
    final imageCacheHeight = (imageHeight * dpr).round();
    // Extra height to accommodate the additional date line on the card text.
    final totalHeight = imageHeight + 84;

    return SizedBox(
      height: totalHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        primary: false,
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: events.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: crossAxisSpacing),
        itemBuilder: (context, index) {
          final event = events[index];
          return SizedBox(
            width: cardWidth,
            child: RepaintBoundary(
              child: EventCard(
                event: event,
                onTap: () => onEventTap(event),
                imageCacheWidth: imageCacheWidth > 0 ? imageCacheWidth : null,
                imageCacheHeight:
                    imageCacheHeight > 0 ? imageCacheHeight : null,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ShortcutItem extends StatelessWidget {
  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: textStyle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BookOrderButton extends StatelessWidget {
  const _BookOrderButton({required this.onTap});

  static const _backgroundAssetPath = 'assets/images/book_order_button_bg.jpg';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderRadius = BorderRadius.circular(32);
    return Material(
      elevation: 4,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      shadowColor: theme.colorScheme.secondary.withOpacity(0.4),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          image: const DecorationImage(
            image: ExactAssetImage(_backgroundAssetPath),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black54,
              BlendMode.darken,
            ),
          ),
        ),
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.auto_stories, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  '本の注文はこちら',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomePageContentCard extends StatelessWidget {
  const _HomePageContentCard({
    required this.content,
    required this.onTap,
    this.imageCacheWidth,
    this.imageCacheHeight,
  });

  final HomePageContent content;
  final VoidCallback onTap;
  final int? imageCacheWidth;
  final int? imageCacheHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = _buildMetadata(content);
    const radius = Radius.circular(20);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(radius),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: radius),
              child: AspectRatio(
                aspectRatio: 1,
                child: _HomePageContentImage(
                  imageUrl: content.imageUrls.isNotEmpty
                      ? content.imageUrls.first
                      : null,
                  imageCacheWidth: imageCacheWidth,
                  imageCacheHeight: imageCacheHeight,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (metadata != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      metadata,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _buildMetadata(HomePageContent content) {
    switch (content.genre) {
      case HomePageGenre.sales:
        final price = content.price;
        if (price == null) return null;
        return '¥${_formatNumber(price)}';
      case HomePageGenre.event:
        final date = content.eventDate;
        if (date == null) return null;
        final start = content.startTimeLabel ?? '--:--';
        final end = content.endTimeLabel ?? '--:--';
        return '${_formatDate(date)}  $start〜$end';
      case HomePageGenre.news:
        return null;
    }
  }

  String _formatNumber(int value) {
    final digits = value.toString().split('').reversed.toList();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i != 0 && i % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
    }
    return buffer.toString().split('').reversed.join();
  }

  String _formatDate(DateTime date) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }
}

class _HomePageContentImage extends StatelessWidget {
  const _HomePageContentImage({
    this.imageUrl,
    this.imageCacheWidth,
    this.imageCacheHeight,
  });

  static const bool _disableNetworkImages =
      bool.fromEnvironment('DISABLE_NETWORK_IMAGES');
  final String? imageUrl;
  final int? imageCacheWidth;
  final int? imageCacheHeight;

  @override
  Widget build(BuildContext context) {
    if (_disableNetworkImages) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey.shade500,
        ),
      );
    }
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.image_outlined,
          color: Colors.grey.shade500,
        ),
      );
    }

    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      cacheWidth: imageCacheWidth,
      cacheHeight: imageCacheHeight,
      filterQuality: FilterQuality.none,
      isAntiAlias: false,
      gaplessPlayback: true,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: Colors.grey.shade200,
          alignment: Alignment.center,
          child: Icon(
            Icons.image_outlined,
            color: Colors.grey.shade400,
          ),
        );
      },
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}
