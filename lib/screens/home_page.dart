import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import '../widgets/point_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuthService _authService = FirebaseAuthService();

  void _showNotification(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('お知らせは準備中です')),
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildHeader(context),
          const SizedBox(height: 32),
          PointCard(
            points: 3003,
            onRefresh: () => _showNotification(context),
          ),
          const SizedBox(height: 32),
          Text(
            'ショートカット',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MenuButton(icon: Icons.qr_code, label: 'QR コード'),
              _MenuButton(icon: Icons.send, label: '送る'),
              _MenuButton(icon: Icons.leaderboard_outlined, label: 'ランキング'),
              _MenuButton(icon: Icons.storefront_outlined, label: '本日の獲得'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 72) / 2,
      child: FilledButton.tonal(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label は準備中です')),
          );
        },
        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
        child: Column(
          children: [
            Icon(icon, size: 28),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
