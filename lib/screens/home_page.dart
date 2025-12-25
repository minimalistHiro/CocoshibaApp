import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/calendar_event.dart';
import '../services/event_service.dart';
import '../services/firebase_auth_service.dart';
import '../services/notification_service.dart';
import '../services/new_user_coupon_service.dart';
import '../widgets/point_card.dart';
import '../widgets/event_card.dart';
import 'menu_list_page.dart';
import 'home_page_reservation_history_page.dart';
import 'notification_page.dart';
import 'point_history_page.dart';
import 'event_detail_page.dart';
import 'events_page.dart';
import 'new_user_coupon_page.dart';

class HomePageController {
  VoidCallback? _onRefresh;

  void attach(VoidCallback onRefresh) {
    _onRefresh = onRefresh;
  }

  void detach(VoidCallback onRefresh) {
    if (_onRefresh == onRefresh) {
      _onRefresh = null;
    }
  }

  void refreshUserInfo() {
    _onRefresh?.call();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.controller});

  final HomePageController? controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final EventService _eventService = EventService();
  final NotificationService _notificationService = NotificationService();
  final NewUserCouponService _newUserCouponService = NewUserCouponService();
  static final Uri _bookOrderFormUri = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSda9VfM-EMborsiY-h11leW1uXgNUPdwv3RFb4_I1GjwFSoOQ/viewform?pli=1',
  );
  late Future<int> _pointsFuture;
  late final Stream<List<CalendarEvent>> _reservedEventsStream;
  late final Stream<List<CalendarEvent>> _upcomingEventsStream;
  late final VoidCallback _externalRefresh;

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
    _externalRefresh = () {
      _reloadPoints(showMessage: false);
    };
    widget.controller?.attach(_externalRefresh);
    _pointsFuture = _authService.fetchCurrentUserPoints();
    final currentUser = _authService.currentUser;
    final reservedStream = currentUser == null
        ? _singleValueStream<List<CalendarEvent>>(const [])
        : _eventService
            .watchReservedEvents(currentUser.uid)
            .map((events) => events.take(7).toList(growable: false));
    _reservedEventsStream = reservedStream
        .distinct((a, b) => _sameBySignature(a, b, _eventSignature));

    final upcomingEventsSource = _eventService
        .watchUpcomingEvents(limit: 30)
        .distinct((a, b) => _sameBySignature(a, b, _eventSignature));
    _upcomingEventsStream = _shareReplayLatest(upcomingEventsSource);

  }

  @override
  void didUpdateWidget(covariant HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_externalRefresh);
      widget.controller?.attach(_externalRefresh);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(_externalRefresh);
    super.dispose();
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

  Future<void> _reloadPoints({required bool showMessage}) async {
    final future = _authService.fetchCurrentUserPoints();
    setState(() {
      _pointsFuture = future;
    });
    try {
      await future;
      if (!mounted || !showMessage) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ポイントを更新しました')));
    } catch (e) {
      if (!mounted || !showMessage) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ポイントの取得に失敗しました')));
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

  void _openNewUserCouponPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const NewUserCouponPage(),
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
                              _reloadPoints(showMessage: true);
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
                  StreamBuilder<bool>(
                    stream: _authService.currentUser == null
                        ? const Stream<bool>.empty()
                        : _newUserCouponService
                            .watchIsUsed(_authService.currentUser!.uid),
                    builder: (context, snapshot) {
                      final canShow = snapshot.hasData && snapshot.data == false;
                      if (!canShow) return const SizedBox.shrink();
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          Material(
                            color: Colors.transparent,
                            elevation: 2,
                            shadowColor: Colors.black.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(24),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _openNewUserCouponPage,
                              child: SizedBox(
                                height: 140,
                                child: Image.asset(
                                  'assets/images/new_user_coupon.png',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey.shade200,
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(16),
                                      child: Text(
                                        '画像を読み込めませんでした',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.grey.shade700,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 32),
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
                ],
              ),
            ),
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
