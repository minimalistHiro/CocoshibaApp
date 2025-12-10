import 'dart:async';

import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../services/firebase_auth_service.dart';
import '../services/event_service.dart';
import '../widgets/point_card.dart';
import 'notification_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final EventService _eventService = EventService();
  late Future<int> _pointsFuture;
  late final Stream<List<CalendarEvent>> _upcomingEventsStream;

  @override
  void initState() {
    super.initState();
    _pointsFuture = _authService.fetchCurrentUserPoints();
    _upcomingEventsStream = _eventService.watchUpcomingEvents(limit: 5);
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
            IconButton(
              onPressed: () => _showNotification(context),
              icon: const Icon(Icons.notifications_outlined),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          FutureBuilder<int>(
            future: _pointsFuture,
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
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
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
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
            shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            borderRadius: BorderRadius.circular(36),
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _ShortcutItem(
                      icon: Icons.qr_code,
                      label: 'QRコード',
                      onTap: () => _showShortcutMessage('QRコード'),
                    ),
                  ),
                  Expanded(
                    child: _ShortcutItem(
                      icon: Icons.send,
                      label: '送る',
                      onTap: () => _showShortcutMessage('送る'),
                    ),
                  ),
                  Expanded(
                    child: _ShortcutItem(
                      icon: Icons.leaderboard_outlined,
                      label: 'ランキング',
                      onTap: () => _showShortcutMessage('ランキング'),
                    ),
                  ),
                  Expanded(
                    child: _ShortcutItem(
                      icon: Icons.storefront_outlined,
                      label: '本日の獲得',
                      onTap: () => _showShortcutMessage('本日の獲得'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          StreamBuilder<List<CalendarEvent>>(
            stream: _upcomingEventsStream,
            builder: (context, snapshot) {
              final events = (snapshot.data ?? const <CalendarEvent>[])
                  .where((event) => event.imageUrls.isNotEmpty)
                  .take(5)
                  .toList(growable: false);

              if (snapshot.connectionState == ConnectionState.waiting &&
                  events.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _UpcomingEventsHeader(),
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

              if (events.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _UpcomingEventsHeader(),
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
                  const _UpcomingEventsHeader(),
                  const SizedBox(height: 12),
                  _UpcomingEventCarousel(events: events),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpcomingEventsHeader extends StatelessWidget {
  const _UpcomingEventsHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      '直近のイベント',
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _UpcomingEventCarousel extends StatefulWidget {
  const _UpcomingEventCarousel({required this.events});

  final List<CalendarEvent> events;

  @override
  State<_UpcomingEventCarousel> createState() => _UpcomingEventCarouselState();
}

class _UpcomingEventCarouselState extends State<_UpcomingEventCarousel> {
  late final PageController _controller;
  Timer? _autoScrollTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _UpcomingEventCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.events.length != widget.events.length) {
      _currentPage = 0;
      if (_controller.hasClients) {
        _controller.jumpToPage(0);
      }
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    if (widget.events.length < 2) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_controller.hasClients) return;
      _currentPage = (_currentPage + 1) % widget.events.length;
      _controller.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dateTime) {
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    return '${dateTime.year}/$month/$day';
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: PageView.builder(
        controller: _controller,
        itemCount: widget.events.length,
        onPageChanged: (index) => _currentPage = index,
        itemBuilder: (context, index) {
          final event = widget.events[index];
          final imageUrl = event.imageUrls.first;
          final dateLabel = _formatDate(event.startDateTime);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Icon(Icons.image_not_supported_outlined,
                            size: 48, color: Colors.black38),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.2),
                            Colors.black.withOpacity(0.6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          event.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
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
