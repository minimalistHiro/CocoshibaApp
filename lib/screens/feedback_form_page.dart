import 'package:flutter/material.dart';

import '../services/feedback_service.dart';

class FeedbackFormPage extends StatefulWidget {
  const FeedbackFormPage({super.key});

  @override
  State<FeedbackFormPage> createState() => _FeedbackFormPageState();
}

class _FeedbackFormPageState extends State<FeedbackFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _detailController = TextEditingController();
  final _contactController = TextEditingController();
  final _feedbackService = FeedbackService();

  String _category = 'アプリの不具合';
  bool _includeDeviceInfo = true;
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _detailController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, {int min = 5}) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return '入力してください';
    }
    if (trimmed.length < min) {
      return '$min文字以上で入力してください';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.[a-zA-Z]{2,}$'); // 簡易チェック
    if (!emailRegex.hasMatch(trimmed)) {
      return 'メールアドレスの形式が正しくありません';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _feedbackService.submitFeedback(
        category: _category,
        title: _titleController.text,
        detail: _detailController.text,
        contactEmail: _contactController.text.trim().isEmpty
            ? null
            : _contactController.text.trim(),
        includeDeviceInfo: _includeDeviceInfo,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('フィードバックを送信しました。ありがとうございます！')),
      );
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('送信に失敗しました。時間をおいて再度お試しください')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _confirmAndSubmit() async {
    if (_isSending) return;
    if (!_formKey.currentState!.validate()) return;

    final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('フィードバックを送信しますか？'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('カテゴリ: $_category'),
                const SizedBox(height: 8),
                Text('概要: ${_titleController.text.trim()}'),
                if (_includeDeviceInfo) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '診断情報を含めて送信します。',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('送信する'),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldSend) {
      await _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('フィードバックを送信'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'アプリ改善のための気づきをお寄せください。内容を詳しく書いていただけると、より早く対応できます。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'アプリの不具合',
                      child: Text('アプリの不具合'),
                    ),
                    DropdownMenuItem(
                      value: '要望・機能追加',
                      child: Text('要望・機能追加'),
                    ),
                    DropdownMenuItem(
                      value: '使い方の質問',
                      child: Text('使い方の質問'),
                    ),
                    DropdownMenuItem(
                      value: 'その他',
                      child: Text('その他'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _category = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '概要 (必須)',
                    hintText: '例: イベント一覧が開けない',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 80,
                  validator: (value) => _validateRequired(value, min: 5),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _detailController,
                  decoration: const InputDecoration(
                    labelText: '詳細・再現手順 (必須)',
                    hintText: 'いつ/どこで発生したか、表示されたメッセージなど',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 8,
                  minLines: 5,
                  maxLength: 1200,
                  validator: (value) => _validateRequired(value, min: 10),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: '返信先メールアドレス (任意)',
                    hintText: '回答が必要な場合にご入力ください',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  title: const Text('診断情報を含める'),
                  subtitle: const Text('端末情報や動作状況を匿名で添付し、原因調査に役立てます'),
                  contentPadding: EdgeInsets.zero,
                  value: _includeDeviceInfo,
                  onChanged: (value) {
                    setState(() => _includeDeviceInfo = value);
                  },
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _isSending ? null : _confirmAndSubmit,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(_isSending ? '送信中...' : 'フィードバックを送信'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
