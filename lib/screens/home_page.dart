import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/calendar_event.dart';
import '../models/campaign.dart';
import '../models/home_page_content.dart';
import '../services/event_service.dart';
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
  final NotificationService _notificationService = NotificationService();
  final HomePageContentService _homePageContentService =
      HomePageContentService();
  final CampaignService _campaignService = CampaignService();
  static final Uri _bookOrderFormUri = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSda9VfM-EMborsiY-h11leW1uXgNUPdwv3RFb4_I1GjwFSoOQ/viewform?pli=1',
  );
  late Future<int> _pointsFuture;
  late final Stream<List<CalendarEvent>> _upcomingEventsStream;
  late final Stream<List<HomePageContent>> _homePageContentsStream;
  late final Stream<List<Campaign>> _activeCampaignsStream;

  @override
  void initState() {
    super.initState();
    _pointsFuture = _authService.fetchCurrentUserPoints();
    _upcomingEventsStream = _eventService.watchUpcomingEvents(limit: 7);
    _homePageContentsStream = _homePageContentService.watchContents();
    _activeCampaignsStream = _campaignService.watchActiveCampaigns();
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
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error),
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
            builder: (context, snapshot) {
              final campaigns = snapshot.data ?? const <Campaign>[];
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;

              if (isLoading && campaigns.isEmpty) {
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
                  _CampaignCarousel(campaigns: campaigns),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<CalendarEvent>>(
            stream: _upcomingEventsStream,
            builder: (context, snapshot) {
              final upcomingEvents = (snapshot.data ?? const <CalendarEvent>[])
                  .take(7)
                  .toList(growable: false);

              if (snapshot.connectionState == ConnectionState.waiting &&
                  upcomingEvents.isEmpty) {
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

              if (upcomingEvents.isEmpty) {
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
                  _UpcomingEventsScroller(
                    events: upcomingEvents,
                    onEventTap: _openEventDetail,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          StreamBuilder<List<HomePageContent>>(
            stream: _homePageContentsStream,
            builder: (context, snapshot) {
              final isLoading =
                  snapshot.connectionState == ConnectionState.waiting;
              final contents = snapshot.data ?? const <HomePageContent>[];
              return _HomePageContentSection(
                contents: contents,
                isLoading: isLoading && contents.isEmpty,
              );
            },
          ),
          const SizedBox(height: 32),
          _BookOrderButton(onTap: _openBookOrderPage),
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

class _CampaignCarousel extends StatefulWidget {
  const _CampaignCarousel({required this.campaigns});

  final List<Campaign> campaigns;

  @override
  State<_CampaignCarousel> createState() => _CampaignCarouselState();
}

class _CampaignCarouselState extends State<_CampaignCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant _CampaignCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.campaigns.length != oldWidget.campaigns.length) {
      _currentPage = 0;
      _pageController.jumpToPage(0);
      _restartAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.campaigns.length <= 1) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || widget.campaigns.isEmpty) return;
      final nextPage = (_currentPage + 1) % widget.campaigns.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _restartAutoScroll() {
    _timer?.cancel();
    _startAutoScroll();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2 / 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.campaigns.length,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemBuilder: (context, index) {
                final campaign = widget.campaigns[index];
                return _CampaignSlide(campaign: campaign);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.campaigns.length, (index) {
            final isActive = index == _currentPage;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 12 : 8,
              height: isActive ? 12 : 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade400,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _CampaignSlide extends StatelessWidget {
  const _CampaignSlide({required this.campaign});

  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final hasImage = campaign.imageUrl != null && campaign.imageUrl!.isNotEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        hasImage
            ? Image.network(
                campaign.imageUrl!,
                fit: BoxFit.cover,
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        const horizontalPadding = 24 * 2;
        const crossAxisSpacing = 16;
        final availableWidth =
            (screenWidth - horizontalPadding - crossAxisSpacing)
                .clamp(0.0, double.infinity);
        final cardWidth = availableWidth / 2;
        const imageAspectRatio = 1;
        final imageHeight = cardWidth / imageAspectRatio;
        final totalHeight = imageHeight + 72;

        return SizedBox(
          height: totalHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final event = events[index];
              return SizedBox(
                width: cardWidth,
                child: EventCard(
                  event: event,
                  onTap: () => onEventTap(event),
                ),
              );
            },
          ),
        );
      },
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

class _HomePageContentSection extends StatelessWidget {
  const _HomePageContentSection({
    required this.contents,
    required this.isLoading,
  });

  final List<HomePageContent> contents;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget child;
    if (isLoading) {
      child = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (contents.isEmpty) {
      child = Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          'ホームページがまだ登録されていません',
          style:
              theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
        ),
      );
    } else {
      child = _HomePageContentGrid(contents: contents);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ホームページ',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _HomePageContentGrid extends StatelessWidget {
  const _HomePageContentGrid({required this.contents});

  final List<HomePageContent> contents;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: contents.length,
      itemBuilder: (context, index) {
        final content = contents[index];
        return _HomePageContentCard(
          content: content,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HomePageContentDetailPage(content: content),
              ),
            );
          },
        );
      },
    );
  }
}

class _HomePageContentCard extends StatelessWidget {
  const _HomePageContentCard({
    required this.content,
    required this.onTap,
  });

  final HomePageContent content;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = _buildMetadata(content);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: _HomePageContentImage(
                imageUrl: content.imageUrls.isNotEmpty
                    ? content.imageUrls.first
                    : null,
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
  const _HomePageContentImage({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
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
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const Center(child: CircularProgressIndicator());
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
