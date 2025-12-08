import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  late final Stream<Map<String, dynamic>?> _profileStream;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _profileStream = _authService.watchCurrentUserProfile();
  }

  Future<void> _logout(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _authService.signOut();
      messenger.showSnackBar(const SnackBar(content: Text('ログアウトしました')));
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('ログアウトに失敗しました')));
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _isDeleting = true);
    try {
      await _authService.deleteAccount();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('アカウントを削除しました')),
      );
      navigator.popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      final code = e.code;
      final message =
          e.message ?? 'アカウント削除に失敗しました（再度ログインが必要な場合があります）';
      messenger.showSnackBar(
        SnackBar(content: Text('[$code] $message')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('アカウント削除に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
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

  Future<void> _confirmAndDelete(BuildContext context) async {
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: const Text('アカウントを削除しますか？この操作は元に戻せません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  '削除する',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!context.mounted || !shouldDelete) return;

    await _deleteAccount(context);
  }

  Widget _buildProfileAvatar(String? photoUrl, String fallbackInitial) {
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    return CircleAvatar(
      radius: 32,
      backgroundColor: Theme.of(context).colorScheme.primary,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              fallbackInitial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final fallbackName = user?.displayName ?? 'お客さま';
    final fallbackEmail = user?.email ?? '未ログイン';
    final String initial =
        fallbackName.isNotEmpty ? fallbackName.substring(0, 1) : '?';

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<Map<String, dynamic>?>(
              stream: _profileStream,
              builder: (context, snapshot) {
                final data = snapshot.data;
                final name = (data?['name'] as String?) ?? fallbackName;
                final email = (data?['email'] as String?) ?? fallbackEmail;
                final photoUrl =
                    (data?['photoUrl'] as String?) ?? user?.photoURL;
                return Row(
                  children: [
                    _buildProfileAvatar(photoUrl, initial),
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
                );
              },
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
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _isDeleting ? null : () => _confirmAndDelete(context),
              icon: const Icon(Icons.delete_forever),
              label: const Text('アカウント削除'),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
