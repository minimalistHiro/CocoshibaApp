import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import '../services/firebase_auth_service.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key, required this.email});

  final String email;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final _codeController = TextEditingController();
  final _authService = FirebaseAuthService();

  bool _isSubmitting = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendCode(initial: true);
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool initial = false}) async {
    if (_isSending) return;
    setState(() => _isSending = true);
    try {
      await _authService.sendEmailVerificationCode(email: widget.email);
      if (!mounted) return;
      _showMessage(
        initial ? '認証コードを送信しました' : '認証コードを再送しました',
      );
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'requestEmailVerification failed: code=${e.code}, message=${e.message}, details=${e.details}',
      );
      _showMessage(
        e.message != null && e.message!.isNotEmpty
            ? '${e.message} (${e.code})'
            : '認証コードの送信に失敗しました (${e.code})',
        isError: true,
      );
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'FirebaseAuthException in sendEmailVerificationCode: code=${e.code}, message=${e.message}',
      );
      _showMessage(e.message ?? '認証コードの送信に失敗しました', isError: true);
    } catch (_) {
      debugPrint('Failed to send email verification code (unknown error)');
      _showMessage('認証コードの送信に失敗しました', isError: true);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length != 6) {
      _showMessage('6桁の認証コードを入力してください', isError: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _authService.verifyEmailCode(_codeController.text.trim());
      if (!mounted) return;
      _showMessage('メール認証が完了しました');
    } on FirebaseFunctionsException catch (e) {
      _showMessage(
        e.message ?? 'メール認証に失敗しました',
        isError: true,
      );
    } on FirebaseAuthException catch (e) {
      _showMessage(e.message ?? 'メール認証に失敗しました', isError: true);
    } catch (e) {
      _showMessage('メール認証に失敗しました', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _signOut() async {
    await _authService.signOut();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('メール認証'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '送信先: ${widget.email}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '入力したメールアドレス宛に6桁の認証コードを送信しました。届いたコードを入力してください。',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: '6桁の認証コード',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isSubmitting ? null : _verify,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('認証する'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isSending ? null : _sendCode,
              child: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('コードを再送する'),
            ),
            const Spacer(),
            TextButton(
              onPressed: _signOut,
              child: const Text('別のアカウントでログインする'),
            ),
          ],
        ),
      ),
    );
  }
}
