import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import 'sign_up_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = FirebaseAuthService();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _passwordVisible = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _isGoogleLoading = false;
    });

    try {
      await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'ログインに失敗しました');
    } catch (_) {
      _showError('ログインに失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isGoogleLoading = true;
      _isLoading = false;
    });

    try {
      await _authService.signInWithGoogle();

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Googleログインに失敗しました');
    } catch (_) {
      _showError('Googleログインに失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _openSignUp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ログイン')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'メールアドレス'),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'メールアドレスを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _passwordVisible = !_passwordVisible),
                    icon: Icon(
                      _passwordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                  ),
                ),
                obscureText: !_passwordVisible,
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return '6文字以上のパスワードを入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (_isLoading || _isGoogleLoading) ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('ログイン'),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed:
                    (_isLoading || _isGoogleLoading) ? null : _signInWithGoogle,
                icon: const Icon(Icons.login),
                label: _isGoogleLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Googleでログイン/登録'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isLoading ? null : _openSignUp,
                child: const Text('アカウントがない？新規作成へ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
