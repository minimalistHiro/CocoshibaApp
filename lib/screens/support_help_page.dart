import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'faq_page.dart';

class SupportHelpPage extends StatelessWidget {
  const SupportHelpPage({super.key});

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${uri.scheme}を開けませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サポート・ヘルプ'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '困ったときの連絡先やガイドをご案内します。',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.chat),
                  title: const Text('チャットサポート'),
                  subtitle: const Text('11:00-18:00（月・火定休） / 平均返信30分'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('ダミー: チャットサポートを開きます')),
                    );
                  },
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.mail_outline),
                  title: const Text('メールで問い合わせ'),
                  subtitle: const Text('info@groumapapp.com'),
                  trailing: const Icon(Icons.send),
                  onTap: () => _launchUri(
                    context,
                    Uri(
                      scheme: 'mailto',
                      path: 'info@groumapapp.com',
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.phone),
                  title: const Text('電話で問い合わせ'),
                  subtitle: const Text('080-6050-7194（11:00-18:00 / 月・火定休）'),
                  trailing: const Icon(Icons.call),
                  onTap: () => _launchUri(
                    context,
                    Uri(
                      scheme: 'tel',
                      path: '08060507194',
                    ),
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.help_center_outlined),
                  title: const Text('よくある質問'),
                  subtitle: const Text('アカウント、イベント参加、ポイントなど'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FaqPage(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '最近のアナウンス',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Card(
                child: ListTile(
                  title: Text('アプリバージョン1.2.0を公開しました'),
                  subtitle: Text('QRコード改善と新しいログイン情報変更機能を追加'),
                ),
              ),
              const Card(
                child: ListTile(
                  title: Text('コミュニティガイドライン更新'),
                  subtitle: Text('2025年1月より新ポリシーが適用されます'),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ダミー: フィードバックフォームを開きます')),
                  );
                },
                icon: const Icon(Icons.feedback_outlined),
                label: const Text('フィードバックを送信'),
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
