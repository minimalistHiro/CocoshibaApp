import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await FirebaseAuthService().signOut();
      messenger.showSnackBar(const SnackBar(content: Text('ログアウトしました')));
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('ログアウトに失敗しました')));
    }
  }

  Future<void> _confirmAndLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: const Text('ログアウトしますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('ログアウト'),
              ),
            ],
          ),
        ) ??
        false;

    if (!context.mounted) return;

    if (shouldLogout) {
      await _logout(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuthService().currentUser;
    final name = user?.displayName ?? 'お客さま';
    final email = user?.email ?? '未ログイン';
    final photoUrl = user?.photoURL;
    final String initial = name.isNotEmpty ? name.substring(0, 1) : '?';

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
                  backgroundImage:
                      (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl)
                          : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                          ),
                        )
                      : null,
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
              onPressed: () => _confirmAndLogout(context),
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
