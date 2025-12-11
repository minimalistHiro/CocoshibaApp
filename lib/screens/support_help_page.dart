import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/owner_contact_info.dart';
import '../services/owner_settings_service.dart';
import 'faq_page.dart';

class SupportHelpPage extends StatefulWidget {
  const SupportHelpPage({super.key});

  @override
  State<SupportHelpPage> createState() => _SupportHelpPageState();
}

class _SupportHelpPageState extends State<SupportHelpPage> {
  final OwnerSettingsService _ownerSettingsService = OwnerSettingsService();
  late final Future<OwnerContactInfo?> _contactInfoFuture;

  @override
  void initState() {
    super.initState();
    _contactInfoFuture = _ownerSettingsService.fetchContactInfo();
  }

  Future<void> _launchUri(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${uri.scheme}を開けませんでした')),
      );
    }
  }

  void _showMissingInfoMessage(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label が未設定です。オーナー設定で登録してください。')),
    );
  }

  Future<void> _openSiteLink(BuildContext context, String? siteUrl) async {
    final trimmed = siteUrl?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      _showMissingInfoMessage(context, 'サイトURL');
      return;
    }
    Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || (!uri.hasScheme && !uri.hasAuthority)) {
      uri = Uri.tryParse('https://$trimmed');
    }
    if (uri == null) {
      _showMissingInfoMessage(context, 'サイトURL');
      return;
    }
    await _launchUri(context, uri);
  }

  String _displayValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return '未設定';
    }
    return trimmed;
  }

  String _phoneSubtitle(String? phone, String? hours) {
    final parts = <String>[];
    final phoneValue = phone?.trim();
    final hoursValue = hours?.trim();
    if (phoneValue != null && phoneValue.isNotEmpty) {
      parts.add(phoneValue);
    }
    if (hoursValue != null && hoursValue.isNotEmpty) {
      parts.add(hoursValue);
    }
    if (parts.isEmpty) {
      return '未設定';
    }
    return parts.join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('サポート・ヘルプ'),
      ),
      body: SafeArea(
        child: FutureBuilder<OwnerContactInfo?>(
          future: _contactInfoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'サポート情報の取得に失敗しました。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }

            final contactInfo = snapshot.data ?? OwnerContactInfo.empty;
            final email = contactInfo.email.trim();
            final phone = contactInfo.phoneNumber.trim();
            final hours = contactInfo.businessHours.trim();

            return SingleChildScrollView(
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
                      subtitle: Text(_displayValue(contactInfo.businessHours)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _openSiteLink(
                        context,
                        contactInfo.siteUrl,
                      ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.mail_outline),
                      title: const Text('メールで問い合わせ'),
                      subtitle: Text(_displayValue(email)),
                      trailing: const Icon(Icons.send),
                      onTap: email.isEmpty
                          ? () => _showMissingInfoMessage(context, 'メールアドレス')
                          : () => _launchUri(
                                context,
                                Uri(
                                  scheme: 'mailto',
                                  path: email,
                                ),
                              ),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.phone),
                      title: const Text('電話で問い合わせ'),
                      subtitle: Text(_phoneSubtitle(phone, hours)),
                      trailing: const Icon(Icons.call),
                      onTap: phone.isEmpty
                          ? () => _showMissingInfoMessage(context, '電話番号')
                          : () => _launchUri(
                                context,
                                Uri(
                                  scheme: 'tel',
                                  path: phone.replaceAll('-', ''),
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
            );
          },
        ),
      ),
    );
  }
}
