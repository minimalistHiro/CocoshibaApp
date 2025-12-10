import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import '../widgets/point_card.dart';
import 'notification_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  late Future<int> _pointsFuture;

  @override
  void initState() {
    super.initState();
    _pointsFuture = _authService.fetchCurrentUserPoints();
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
        ],
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
