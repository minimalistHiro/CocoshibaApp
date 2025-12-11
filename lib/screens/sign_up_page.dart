import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firebase_auth_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

enum _SignUpStep { userInfo, credentials }

class _SignUpPageState extends State<SignUpPage> {
  final _userInfoFormKey = GlobalKey<FormState>();
  final _credentialsFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _picker = ImagePicker();
  final _authService = FirebaseAuthService();
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  Uint8List? _profileImageBytes;
  _SignUpStep _currentStep = _SignUpStep.userInfo;
  String? _selectedAgeGroup;
  String? _selectedArea;

  final _ageGroups = const [
    '10代以下',
    '20代',
    '30代',
    '40代',
    '50代',
    '60代以上',
  ];

  final _areas = const [
    '川口市',
    '蕨市',
    'さいたま市',
    '戸田市',
    'その他県内',
    '県外',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_credentialsFormKey.currentState!.validate()) return;
    if (_selectedAgeGroup == null || _selectedArea == null) {
      setState(() => _currentStep = _SignUpStep.userInfo);
      _showError('ユーザー情報を入力してください');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      Uint8List? imageBytes = _profileImageBytes;

      await _authService.signUp(
        name: _nameController.text,
        ageGroup: _selectedAgeGroup!,
        area: _selectedArea!,
        email: _emailController.text,
        password: _passwordController.text,
        bio: _bioController.text,
        profileImageBytes: imageBytes,
      );

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      debugPrint(
        'SignUp FirebaseAuthException code=${e.code}, message=${e.message}',
      );
      final message = e.message ?? 'アカウント作成に失敗しました';
      _showError('[${e.code}] $message');
    } catch (e, stackTrace) {
      debugPrint('SignUp unexpected error: $e');
      debugPrint('$stackTrace');
      _showError('アカウント作成に失敗しました（詳細はデバッグログ参照）');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImage() async {
    if (_isLoading) return;
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxHeight: 600,
        maxWidth: 600,
        imageQuality: 85,
      );
      if (pickedFile == null) return;
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() => _profileImageBytes = bytes);
    } catch (e) {
      _showError('画像の選択に失敗しました');
    }
  }

  void _goToCredentialsStep() {
    if (!_userInfoFormKey.currentState!.validate()) {
      return;
    }
    setState(() => _currentStep = _SignUpStep.credentials);
  }

  void _goBackToUserInfoStep() {
    if (_isLoading) return;
    setState(() => _currentStep = _SignUpStep.userInfo);
  }

  Widget _buildProfilePicker(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'プロフィール画像（任意）',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _pickImage,
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  backgroundImage: _profileImageBytes != null
                      ? MemoryImage(_profileImageBytes!)
                      : null,
                  child: _profileImageBytes == null
                      ? Icon(
                          Icons.camera_alt,
                          size: 32,
                          color: theme.colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(
                    Icons.edit,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
        TextButton(
          onPressed: _pickImage,
          child: const Text('写真を選択'),
        ),
      ],
    );
  }

  Widget _buildUserInfoForm(BuildContext context) {
    return Form(
      key: _userInfoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildProfilePicker(context),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'ユーザー名'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'ユーザー名を入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '年代'),
            value: _selectedAgeGroup,
            items: _ageGroups
                .map(
                  (age) => DropdownMenuItem<String>(
                    value: age,
                    child: Text(age),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedAgeGroup = value),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '年代を選択してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: '住所'),
            value: _selectedArea,
            items: _areas
                .map(
                  (area) => DropdownMenuItem<String>(
                    value: area,
                    child: Text(area),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _selectedArea = value),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '住所を選択してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bioController,
            decoration: const InputDecoration(
              labelText: '自己紹介（任意）',
              alignLabelWithHint: true,
              hintText: '趣味や好きなことを書いてみましょう',
            ),
            keyboardType: TextInputType.multiline,
            minLines: 5,
            maxLines: 8,
            maxLength: 200,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _goToCredentialsStep,
            child: const Text('次へ'),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialsForm() {
    return Form(
      key: _credentialsFormKey,
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
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            decoration: InputDecoration(
              labelText: 'パスワード（確認用）',
              suffixIcon: IconButton(
                onPressed: () => setState(
                    () => _confirmPasswordVisible = !_confirmPasswordVisible),
                icon: Icon(
                  _confirmPasswordVisible
                      ? Icons.visibility_off
                      : Icons.visibility,
                ),
              ),
            ),
            obscureText: !_confirmPasswordVisible,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '確認用パスワードを入力してください';
              }
              if (value != _passwordController.text) {
                return 'パスワードが一致しません';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登録する'),
          ),
          TextButton(
            onPressed: _isLoading ? null : _goBackToUserInfoStep,
            child: const Text('戻って修正する'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('新規会員登録')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _currentStep == _SignUpStep.userInfo
              ? _buildUserInfoForm(context)
              : _buildCredentialsForm(),
        ),
      ),
    );
  }
}
