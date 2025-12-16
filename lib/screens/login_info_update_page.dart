import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class LoginInfoUpdatePage extends StatefulWidget {
  const LoginInfoUpdatePage({super.key});

  @override
  State<LoginInfoUpdatePage> createState() => _LoginInfoUpdatePageState();
}

class _LoginInfoUpdatePageState extends State<LoginInfoUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = FirebaseAuthService();

  bool _isUpdating = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = _authService.currentUser?.email ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updateLoginInfo() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isUpdating = true);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await _authService.updateLoginInfo(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text.isNotEmpty
            ? _newPasswordController.text
            : null,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('ログイン情報を更新しました')),
      );
      navigator.pop();
    } on FirebaseAuthException catch (e) {
      final message = e.message ?? 'ログイン情報の更新に失敗しました';
      messenger.showSnackBar(
        SnackBar(content: Text('[${e.code}] $message')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ログイン情報の更新に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログイン情報変更'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'メールアドレス',
                    helperText: 'メールアドレスは変更できません',
                  ),
                  readOnly: true,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _currentPasswordController,
                  decoration: InputDecoration(
                    labelText: '現在のパスワード',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _showCurrentPassword = !_showCurrentPassword,
                        );
                      },
                    ),
                  ),
                  obscureText: !_showCurrentPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '現在のパスワードを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _newPasswordController,
                  decoration: InputDecoration(
                    labelText: '新しいパスワード',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _showNewPassword = !_showNewPassword,
                        );
                      },
                    ),
                  ),
                  obscureText: !_showNewPassword,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '新しいパスワードを入力してください';
                    }
                    if (value.length < 6) {
                      return '6文字以上で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: '新しいパスワード（確認）',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(
                          () => _showConfirmPassword = !_showConfirmPassword,
                        );
                      },
                    ),
                  ),
                  obscureText: !_showConfirmPassword,
                  validator: (value) {
                    final newPassword = _newPasswordController.text;
                    if (value != newPassword) {
                      return '新しいパスワードが一致しません';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isUpdating ? null : _updateLoginInfo,
                  icon: _isUpdating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isUpdating ? '更新中...' : '保存する'),
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
