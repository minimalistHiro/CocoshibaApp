import 'package:flutter/material.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  List<Map<String, String>> get _faqs => const [
        {
          'question': 'Q. ログインできません。どうすればいいですか？',
          'answer':
              'A. パスワードを忘れた場合はログイン画面から再設定してください。'
                  'メールが届かないときは迷惑メールフォルダもご確認ください。'
                  'それでも解決しない場合はサポートへお問い合わせください。',
        },
        {
          'question': 'Q. イベント参加のキャンセルはできますか？',
          'answer':
              'A. イベント詳細画面から「参加を取り消す」をタップしてください。'
                  '開始2時間前を過ぎるとキャンセルできない場合があります。',
        },
        {
          'question': 'Q. プロフィール情報はどこで変更できますか？',
          'answer':
              'A. アカウント > プロフィール編集 から名前や自己紹介、アイコンを更新できます。',
        },
        {
          'question': 'Q. データの削除を依頼したいのですが。',
          'answer':
              'A. データとプライバシー画面から「データ削除の申請」を選び、案内に従ってください。',
        },
        {
          'question': 'Q. アプリの最新情報を知りたい。',
          'answer':
              'A. サポート・ヘルプ画面の「最近のアナウンス」や公式SNSをご確認ください。',
        },
      ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('よくある質問'),
      ),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemBuilder: (context, index) {
            final faq = _faqs[index];
            return Card(
              child: ExpansionTile(
                title: Text(faq['question']!),
                childrenPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  Text(
                    faq['answer']!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: _faqs.length,
        ),
      ),
    );
  }
}
