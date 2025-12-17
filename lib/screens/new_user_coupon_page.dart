import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import '../services/new_user_coupon_service.dart';

class NewUserCouponPage extends StatefulWidget {
  const NewUserCouponPage({super.key});

  @override
  State<NewUserCouponPage> createState() => _NewUserCouponPageState();
}

class _NewUserCouponPageState extends State<NewUserCouponPage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final NewUserCouponService _couponService = NewUserCouponService();

  var _isSubmitting = false;

  Future<void> _confirmAndUseCoupon(String uid) async {
    final shouldUse = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('クーポンを使用しますか？'),
        content: const Text('使用すると元に戻せません。お会計時にスタッフへ画面をお見せください。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('使用する'),
          ),
        ],
      ),
    );

    if (shouldUse != true || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });
    try {
      await _couponService.markUsed(uid);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クーポンを使用済みにしました')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('クーポンの使用登録に失敗しました')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('新規ユーザー限定クーポン')),
        body: const Center(
          child: Text('クーポンを見るにはログインしてください'),
        ),
      );
    }

    return StreamBuilder<bool>(
      stream: _couponService.watchIsUsed(user.uid),
      builder: (context, snapshot) {
        final isUsed = snapshot.data ?? false;
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;
        final canUse = !isUsed && !_isSubmitting && !isLoading;

        return Scaffold(
          appBar: AppBar(title: const Text('新規ユーザー限定クーポン')),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            'assets/images/new_user_coupon.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 220,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  '画像を読み込めませんでした',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.grey.shade700),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'ご利用条件',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        const _RuleItem(text: 'クーポンのご利用は、お一人さま1回限りです。'),
                        const _RuleItem(text: 'お会計から300円引きになります。'),
                        const _RuleItem(
                          text:
                              'フード・ドリンクのお会計にのみご利用いただけます（イベント参加費／本／イベント出店のフード・ドリンクには使えません）。',
                        ),
                        const _RuleItem(
                          text:
                              'お会計が300円未満の場合はお会計が0円になりますが、差額の返金や次回への繰り越しはできません。',
                        ),
                        const SizedBox(height: 24),
                        if (isUsed)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'このクーポンは使用済みです',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          canUse ? () => _confirmAndUseCoupon(user.uid) : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isUsed
                                  ? '使用済み'
                                  : isLoading
                                      ? '読み込み中'
                                      : '使用する',
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RuleItem extends StatelessWidget {
  const _RuleItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
