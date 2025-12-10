import 'package:flutter/material.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;
  bool _eventReminderEnabled = true;
  bool _newsEnabled = false;
  String _quietHours = 'なし';

  final List<String> _quietHourOptions = [
    'なし',
    '22:00 - 7:00',
    '21:00 - 8:00',
  ];

  void _handleSave() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('通知設定を保存しました（ダミー）')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'イベントやお知らせの受信方法をカスタマイズできます。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                value: _pushEnabled,
                title: const Text('プッシュ通知'),
                subtitle: const Text('アプリからのお知らせを受け取る'),
                onChanged: (value) => setState(() => _pushEnabled = value),
              ),
              SwitchListTile(
                value: _emailEnabled,
                title: const Text('メール通知'),
                subtitle: const Text('重要なお知らせをメールで受け取る'),
                onChanged: (value) => setState(() => _emailEnabled = value),
              ),
              const Divider(height: 32),
              SwitchListTile(
                value: _eventReminderEnabled,
                title: const Text('イベントリマインダー'),
                subtitle: const Text('参加予定イベントの前日に通知'),
                onChanged: (value) =>
                    setState(() => _eventReminderEnabled = value),
              ),
              SwitchListTile(
                value: _newsEnabled,
                title: const Text('新着ニュース'),
                subtitle: const Text('ココシバからのお知らせやブログ更新を通知'),
                onChanged: (value) => setState(() => _newsEnabled = value),
              ),
              const Divider(height: 32),
              Text(
                '通知を控える時間帯',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _quietHours,
                items: _quietHourOptions
                    .map(
                      (option) => DropdownMenuItem(
                        value: option,
                        child: Text(option),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _quietHours = value);
                },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _handleSave,
                icon: const Icon(Icons.save),
                label: const Text('保存する'),
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
