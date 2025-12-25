import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class DataPrivacyPage extends StatefulWidget {
  const DataPrivacyPage({super.key});

  @override
  State<DataPrivacyPage> createState() => _DataPrivacyPageState();
}

class _DataPrivacyPageState extends State<DataPrivacyPage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isSubmitting = false;

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _confirmDeletionRequest(BuildContext context) async {
    if (_isSubmitting) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('データ削除の申請'),
        content: const Text(
          '削除申請を送信するとログアウトされます。申請を続けますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _submitDeletionRequest(context);
    }
  }

  Future<void> _submitDeletionRequest(BuildContext context) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final user = _authService.currentUser;
      if (user == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ログイン情報が確認できませんでした')),
        );
        return;
      }
      await FirebaseFirestore.instance
          .collection('data_deletion_requests')
          .add({
        'userId': user.uid,
        'email': user.email,
        'displayName': user.displayName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'requested',
      });
      await _authService.signOut();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('削除申請を受け付けました')),
      );
      navigator.popUntil((route) => route.isFirst);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('削除申請に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('データとプライバシー'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ココシバアプリで保存されるデータの確認や管理を行えます。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: const Text('保有データの確認'),
                  subtitle: const Text('プロフィール情報・参加イベント履歴などをチェック'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ダミー: データ確認をリクエストしました')),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('データをエクスポート'),
                  subtitle: const Text('CSV/JSON形式でメールへ送信'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ダミー: エクスポートメールを送信しました')),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('データ削除の申請'),
                  subtitle: const Text('退会後の記録削除やリセットをリクエスト'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isSubmitting
                      ? null
                      : () => _confirmDeletionRequest(context),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle(context, 'データの利用目的'),
              const Text(
                '・イベント運営の連絡や参加管理\n'
                '・コミュニティの安全性維持\n'
                '・新機能やキャンペーンのお知らせ\n'
                '・アプリ改善のための集計（匿名化）',
              ),
              const SizedBox(height: 16),
              _buildSectionTitle(context, 'プライバシーポリシー'),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ダミー: プライバシーポリシーを開きます')),
                  );
                },
                icon: const Icon(Icons.link),
                label: const Text('プライバシーポリシーを読む'),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ダミー: お問い合わせフォームへ移動します')),
                  );
                },
                icon: const Icon(Icons.support_agent),
                label: const Text('サポートへ問い合わせ'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
