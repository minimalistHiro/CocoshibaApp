import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseAuthService().signOut();
      messenger.showSnackBar(const SnackBar(content: Text('ログアウトしました')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('ログアウトに失敗しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService().currentUser;
    final name = user?.displayName ?? 'お客さま';
    final email = user?.email ?? '未ログイン';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: Text(
                    name.isNotEmpty ? name.substring(0, 1) : '?',
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(email),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            Card(
              child: ListTile(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('プロフィール編集は準備中です')),
                ),
                title: const Text('プロフィール編集'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
