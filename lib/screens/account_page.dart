import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import 'data_privacy_page.dart';
import 'existing_events_page.dart';
import 'login_info_update_page.dart';
import 'notification_settings_page.dart';
import 'closed_days_settings_page.dart';
import 'owner_settings_page.dart';
import 'menu_management_page.dart';
import 'profile_edit_page.dart';
import 'support_help_page.dart';

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
      final message = e.message ?? 'アカウント削除に失敗しました（再度ログインが必要な場合があります）';
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
    final theme = Theme.of(context);
    final fallbackChild = Text(
      fallbackInitial,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 24,
      ),
    );

    return CircleAvatar(
      radius: 32,
      backgroundColor: theme.colorScheme.primary,
      child: hasPhoto
          ? ClipOval(
              child: Image.network(
                photoUrl!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallbackChild,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
            )
          : fallbackChild,
    );
  }

  void _showFeatureUnavailable(BuildContext context, String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName は準備中です')),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSettingCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right),
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
                final bio = (data?['bio'] as String?)?.trim();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProfileAvatar(photoUrl, initial),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
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
                        ),
                      ],
                    ),
                    if (bio != null && bio.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        child: Text(
                          bio,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('アカウント設定'),
            _buildSettingCard(
              context: context,
              icon: Icons.person_outline,
              title: 'プロフィール編集',
              subtitle: '名前・アイコン・自己紹介を編集',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ProfileEditPage(),
                ),
              ),
            ),
            _buildSettingCard(
              context: context,
              icon: Icons.lock_outline,
              title: 'ログイン情報変更',
              subtitle: 'メールアドレスやパスワードを更新',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LoginInfoUpdatePage(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('セキュリティと通知'),
            _buildSettingCard(
              context: context,
              icon: Icons.notifications_outlined,
              title: '通知設定',
              subtitle: 'プッシュ・メール通知の受信を管理',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsPage(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('データとサポート'),
            _buildSettingCard(
              context: context,
              icon: Icons.privacy_tip_outlined,
              title: 'データとプライバシー',
              subtitle: 'データの確認・エクスポート・削除',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DataPrivacyPage(),
                ),
              ),
            ),
            _buildSettingCard(
              context: context,
              icon: Icons.tune,
              title: 'アプリ設定',
              subtitle: '表示やテーマなどのカスタマイズ',
              onTap: () => _showFeatureUnavailable(context, 'アプリ設定'),
            ),
            _buildSettingCard(
              context: context,
              icon: Icons.help_outline,
              title: 'サポート・ヘルプ',
              subtitle: 'お問い合わせ・FAQ・ポリシー',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SupportHelpPage(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSectionHeader('管理者設定'),
            _buildSettingCard(
              context: context,
              icon: Icons.event_busy_outlined,
              title: '定休日設定',
              subtitle: '休業日をカレンダーで管理',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ClosedDaysSettingsPage(),
                ),
              ),
            ),
            _buildSettingCard(
              context: context,
              icon: Icons.admin_panel_settings_outlined,
              title: 'オーナー設定',
              subtitle: 'ポイント還元率・店舗情報の管理',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const OwnerSettingsPage(),
                ),
              ),
            ),
            _buildSettingCard(
              context: context,
              icon: Icons.restaurant_menu_outlined,
              title: 'メニュー管理',
              subtitle: 'メニュー一覧の編集・追加',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MenuManagementPage(),
                ),
              ),
            ),
            _buildSettingCard(
              context: context,
              icon: Icons.edit_calendar_outlined,
              title: '既存イベント編集',
              subtitle: '公開済みイベントの内容を変更',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ExistingEventsPage(),
                ),
              ),
            ),
            const SizedBox(height: 32),
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
