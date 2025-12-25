import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import 'data_privacy_page.dart';
import 'existing_events_page.dart';
import 'login_info_update_page.dart';
import 'notification_settings_page.dart';
import 'closed_days_settings_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_chat_service.dart';
import 'owner_settings_page.dart';
import 'menu_management_page.dart';
import 'campaigns_page.dart';
import 'profile_edit_page.dart';
import 'support_help_page.dart';
import 'home_screen_editor_page.dart';
import 'user_chat_support_page.dart';
import 'data_deletion_requests_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final UserChatService _chatService = UserChatService();
  late final Stream<Map<String, dynamic>?> _profileStream;
  Stream<DateTime?>? _supportChatReadStream;
  Stream<bool>? _adminChatUnreadStream;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _profileStream = _authService.watchCurrentUserProfile();
    final userId = _authService.currentUser?.uid;
    if (userId != null) {
      _supportChatReadStream = _chatService.watchLastReadAt(
        threadId: userId,
        viewerId: userId,
      );
      _adminChatUnreadStream = _chatService.watchHasUnreadForOwner(userId);
    }
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

  Widget _buildSupportBadge() {
    final userId = _authService.currentUser?.uid;
    if (userId == null || _supportChatReadStream == null) {
      return const Icon(Icons.chevron_right);
    }

    return StreamBuilder<DateTime?>(
      stream: _supportChatReadStream,
      builder: (context, readSnapshot) {
        final lastRead = readSnapshot.data;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('userChats')
              .doc(userId)
              .snapshots(),
          builder: (context, metaSnapshot) {
            final data = metaSnapshot.data?.data();
            final lastMessageAt = data?['lastMessageAt'] as Timestamp?;
            final senderId = (data?['lastMessageSenderId'] as String?) ?? '';
            final hasUnread = lastMessageAt != null &&
                (lastRead == null ||
                    lastRead.isBefore(lastMessageAt.toDate())) &&
                senderId.isNotEmpty &&
                senderId != userId;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chevron_right),
                if (hasUnread) ...[
                  const SizedBox(width: 6),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAdminChatBadge() {
    if (_adminChatUnreadStream == null) {
      return const Icon(Icons.chevron_right);
    }
    return StreamBuilder<bool>(
      stream: _adminChatUnreadStream,
      builder: (context, snapshot) {
        final hasUnread = snapshot.data ?? false;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right),
            if (hasUnread) ...[
              const SizedBox(width: 6),
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        );
      },
    );
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
    Widget? trailing,
  }) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing ?? const Icon(Icons.chevron_right),
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
              subtitle: 'パスワードを更新',
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
            StreamBuilder<Map<String, dynamic>?>(
              stream: _profileStream,
              builder: (context, snapshot) {
                final isOwner = snapshot.data?['isOwner'] == true;
                if (isOwner) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    _buildSettingCard(
                      context: context,
                      icon: Icons.help_outline,
                      title: 'サポート・ヘルプ',
                      subtitle: 'お問い合わせ・FAQ・ポリシー',
                      trailing: _buildSupportBadge(),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SupportHelpPage(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            StreamBuilder<Map<String, dynamic>?>(
              stream: _profileStream,
              builder: (context, snapshot) {
                final isOwner = snapshot.data?['isOwner'] == true;
                if (!isOwner) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('管理者設定'),
                    _buildSettingCard(
                      context: context,
                      icon: Icons.support_agent_outlined,
                      title: 'ユーザーチャットサポート',
                      subtitle: 'ユーザーとのチャット履歴を確認',
                      trailing: isOwner ? _buildAdminChatBadge() : null,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserChatSupportPage(),
                        ),
                      ),
                    ),
                    _buildSettingCard(
                      context: context,
                      icon: Icons.dashboard_customize_outlined,
                      title: 'ホーム画面編集',
                      subtitle: 'ホームのページを追加・整理',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HomeScreenEditorPage(),
                        ),
                      ),
                    ),
                    _buildSettingCard(
                      context: context,
                      icon: Icons.local_offer_outlined,
                      title: 'キャンペーン編集',
                      subtitle: '掲載・開催期間を管理',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CampaignsPage(),
                        ),
                      ),
                    ),
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
                      icon: Icons.delete_forever_outlined,
                      title: 'データ削除申請者一覧',
                      subtitle: '削除申請をしたユーザーを確認',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DataDeletionRequestsPage(),
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
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => _confirmAndLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('ログアウト'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
