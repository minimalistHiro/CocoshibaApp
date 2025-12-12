import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/home_page_content.dart';
import '../services/firebase_auth_service.dart';
import '../services/home_page_order_service.dart';
import 'home_page_reservation_list_page.dart';
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
  final HomePageOrderService _orderService = HomePageOrderService();
  late final Stream<bool> _ownerStream;
  StreamSubscription<String?>? _orderSubscription;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;
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
    _ownerStream = _authService.watchCurrentUserProfile().map(
          (profile) =>
              (profile?['isOwner'] == true) || (profile?['isSubOwner'] == true),
        );
    _handleAuthUserChanged();
  }

  void _handleAuthUserChanged() {
    _orderSubscription?.cancel();
    _orderSubscription = null;
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
    if (widget.content.buttonType == HomePageButtonType.order) {
      _orderSubscription = _orderService
          .watchOrderId(contentId: widget.content.id, userId: userId)
          .listen((id) {
        setState(() => _orderId = id);
      });
    }
  }

  void _handleButtonTap(HomePageButtonType type) {
    if (type == HomePageButtonType.reserve) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HomePageReservationPage(content: widget.content),
        ),
      );
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

  void _openReservationList() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HomePageReservationListPage(content: widget.content),
      ),
    );
  }

  @override
  void dispose() {
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
          StreamBuilder<bool>(
            stream: _ownerStream,
            builder: (context, snapshot) {
              if (snapshot.data != true) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _openReservationList,
                      icon: const Icon(Icons.list_alt),
                      label: const Text('予約者一覧'),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
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
                        content.buttonType == HomePageButtonType.order)
                ? null
                : () => _handleButtonTap(content.buttonType),
            child: _buildPrimaryButtonChild(content.buttonType),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButtonChild(HomePageButtonType type) {
    switch (type) {
      case HomePageButtonType.reserve:
        return Text(type.label);
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
