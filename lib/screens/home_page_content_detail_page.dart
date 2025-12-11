import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/home_page_content.dart';
import '../services/firebase_auth_service.dart';
import '../services/home_page_order_service.dart';
import '../services/home_page_reservation_service.dart';
import '../services/notification_service.dart';
import 'home_page_reservation_page.dart';

class HomePageContentDetailPage extends StatefulWidget {
  const HomePageContentDetailPage({super.key, required this.content});

  final HomePageContent content;

  @override
  State<HomePageContentDetailPage> createState() =>
      _HomePageContentDetailPageState();
}

class _HomePageContentDetailPageState
    extends State<HomePageContentDetailPage> {
  late final PageController _pageController;
  int _currentPage = 0;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final HomePageReservationService _reservationService =
      HomePageReservationService();
  final HomePageOrderService _orderService = HomePageOrderService();
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<String?>? _reservationSubscription;
  StreamSubscription<String?>? _orderSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;
  String? _reservationId;
  String? _orderId;
  bool _isOrderProcessing = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _userId = _authService.currentUser?.uid;
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((user) {
      final newUserId = user?.uid;
      if (newUserId == _userId) {
        return;
      }
      _userId = newUserId;
      _handleAuthUserChanged();
    });
    _handleAuthUserChanged();
  }

  void _handleAuthUserChanged() {
    _reservationSubscription?.cancel();
    _orderSubscription?.cancel();
    _reservationSubscription = null;
    _orderSubscription = null;
    _reservationId = null;
    _orderId = null;
    if (!mounted) {
      return;
    }
    setState(() {});
    final userId = _userId;
    if (userId == null) {
      return;
    }
    _subscribeActionState(userId);
  }

  void _subscribeActionState(String userId) {
    switch (widget.content.buttonType) {
      case HomePageButtonType.reserve:
        _listenReservationState(userId);
        break;
      case HomePageButtonType.order:
        _orderSubscription = _orderService
            .watchOrderId(contentId: widget.content.id, userId: userId)
            .listen((id) {
          setState(() => _orderId = id);
        });
        break;
    }
  }

  void _listenReservationState(String userId) {
    _reservationSubscription?.cancel();
    _reservationSubscription = _reservationService
        .watchReservationId(contentId: widget.content.id, userId: userId)
        .listen((id) {
      if (!mounted) return;
      setState(() => _reservationId = id);
    });
  }

  void _handleButtonTap(HomePageButtonType type) {
    if (type == HomePageButtonType.reserve) {
      if (_reservationId != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('すでに予約済みです。解除すると再度予約できます。')),
        );
        return;
      }
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (_) => HomePageReservationPage(content: widget.content),
        ),
      )
          .then((result) {
        final userId = _userId;
        if (userId == null) {
          return;
        }
        if (result == true || _reservationSubscription == null) {
          _listenReservationState(userId);
        }
      });
      return;
    }
    if (_orderId != null || _isOrderProcessing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('すでに注文済みです。解除してから再度実行してください。')),
      );
      return;
    }
    _placeOrder();
  }

  @override
  void dispose() {
    _reservationSubscription?.cancel();
    _orderSubscription?.cancel();
    _authSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    final user = _authService.currentUser;
    final messenger = ScaffoldMessenger.of(context);
    if (user == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('注文するにはログインしてください')),
      );
      return;
    }
    setState(() => _isOrderProcessing = true);
    try {
      await _orderService.createOrder(
        contentId: widget.content.id,
        contentTitle: widget.content.title,
        userId: user.uid,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('注文が完了しました')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('注文の保存に失敗しました。もう一度お試しください')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOrderProcessing = false);
      }
    }
  }

  Future<void> _cancelReservation() async {
    final reservationId = _reservationId;
    final userId = _userId;
    if (reservationId == null || userId == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: const Text('この予約を解除しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  '解除する',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _reservationService.cancelReservation(reservationId);
      await _notificationService.createPersonalNotification(
        userId: userId,
        title: '予約を解除しました',
        body: '${widget.content.title} の予約を解除しました。',
        category: '予約',
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('予約を解除しました')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('予約の解除に失敗しました')),
      );
    }
  }

  Future<void> _cancelOrder() async {
    final orderId = _orderId;
    if (orderId == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: const Text('この注文を取り消しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  '取り消す',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _orderService.cancelOrder(orderId);
      messenger.showSnackBar(
        const SnackBar(content: Text('注文を取り消しました')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('注文の取り消しに失敗しました')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = widget.content;
    final images = content.imageUrls;

    return Scaffold(
      appBar: AppBar(
        title: Text(content.title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (images.isNotEmpty)
            Column(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    itemBuilder: (context, index) {
                      final imageUrl = images[index];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                                child: CircularProgressIndicator());
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey.shade500,
                              size: 48,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (images.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      images.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: _currentPage == index ? 16 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(28),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_outlined,
                  color: Colors.grey.shade500,
                  size: 48,
                ),
              ),
            ),
          const SizedBox(height: 24),
          Text(
            content.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Chip(
                label: Text(content.genre.label),
                backgroundColor: Colors.grey.shade200,
              ),
              if (content.createdAt != null)
                Chip(
                  label: Text('更新: ${_formatDate(content.updatedAt ?? content.createdAt!)}'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (_buildMetadata(content) != null) ...[
            Text(
              _buildMetadata(content)!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 16),
          ],
          if (content.body.isNotEmpty)
            Text(
              content.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: (_isOrderProcessing &&
                        content.buttonType == HomePageButtonType.order) ||
                    _actionAlreadyCompleted(content.buttonType)
                ? null
                : () => _handleButtonTap(content.buttonType),
            child: _buildPrimaryButtonChild(content.buttonType),
          ),
          if (_actionAlreadyCompleted(content.buttonType)) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: content.buttonType == HomePageButtonType.reserve
                  ? _cancelReservation
                  : _cancelOrder,
              child: Text(content.buttonType == HomePageButtonType.reserve
                  ? '予約を解除する'
                  : '注文を取り消す'),
            ),
          ],
        ],
      ),
    );
  }

  bool _actionAlreadyCompleted(HomePageButtonType type) {
    switch (type) {
      case HomePageButtonType.reserve:
        return _reservationId != null;
      case HomePageButtonType.order:
        return _orderId != null;
    }
  }

  Widget _buildPrimaryButtonChild(HomePageButtonType type) {
    switch (type) {
      case HomePageButtonType.reserve:
        return Text(_reservationId != null ? '予約済み' : type.label);
      case HomePageButtonType.order:
        if (_isOrderProcessing) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          );
        }
        return Text(_orderId != null ? '注文済み' : type.label);
    }
  }

  String? _buildMetadata(HomePageContent content) {
    switch (content.genre) {
      case HomePageGenre.sales:
        final price = content.price;
        if (price == null) return null;
        return '販売価格: ¥${_formatNumber(price)}';
      case HomePageGenre.event:
        final date = content.eventDate;
        if (date == null) return null;
        final start = content.startTimeLabel ?? '--:--';
        final end = content.endTimeLabel ?? '--:--';
        return '開催日: ${_formatDate(date)}   $start〜$end';
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
