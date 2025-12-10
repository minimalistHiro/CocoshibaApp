import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firebase_auth_service.dart';

class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final FirebaseAuthService _authService = FirebaseAuthService();
  final ImagePicker _picker = ImagePicker();

  bool _isSaving = false;
  bool _isLoading = true;
  String? _loadError;
  Uint8List? _selectedImageBytes;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final User? user = _authService.currentUser;
      final profile = await _authService.fetchCurrentUserProfile();
      final photoUrl = await _authService.fetchProfileImageUrl();
      final fallbackName = user?.displayName ?? '';
      final name = (profile?['name'] as String?) ?? fallbackName;
      final bio = (profile?['bio'] as String?) ?? '';
      if (!mounted) return;
      _nameController.text = name;
      _bioController.text = bio;
      setState(() {
        _photoUrl = photoUrl;
        _selectedImageBytes = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'プロフィールの取得に失敗しました。再試行してください。';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _authService.updateProfile(
        name: _nameController.text,
        bio: _bioController.text,
        profileImageBytes: _selectedImageBytes,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました')),
      );
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      final message = e.message ?? 'プロフィールの更新に失敗しました';
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('プロフィールの更新に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  String _initialLetter() {
    final text = _nameController.text.trim();
    if (text.isEmpty) {
      return '？';
    }
    return text.substring(0, 1);
  }

  Future<void> _pickImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
      });
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('画像の選択に失敗しました')),
      );
    }
  }

  void _clearSelectedImage() {
    setState(() {
      _selectedImageBytes = null;
    });
  }

  ImageProvider? _currentImageProvider() {
    if (_selectedImageBytes != null) {
      return MemoryImage(_selectedImageBytes!);
    }
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? _ErrorView(
                  message: _loadError!,
                  onRetry: _loadProfile,
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'プロフィール画像',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: _currentImageProvider(),
                                backgroundColor:
                                    Theme.of(context).colorScheme.primary,
                                child: _currentImageProvider() == null
                                    ? Text(
                                        _initialLetter(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _isSaving ? null : _pickImage,
                                      icon: const Icon(Icons.photo_camera_back),
                                      label: const Text('画像を選択'),
                                    ),
                                    if (_selectedImageBytes != null)
                                      TextButton(
                                        onPressed:
                                            _isSaving ? null : _clearSelectedImage,
                                        child: const Text('選択をクリア'),
                                      ),
                                    Text(
                                      '正方形の画像を推奨（最大1MB程度）',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: '名前',
                              hintText: '太郎 シバタ',
                            ),
                            textInputAction: TextInputAction.next,
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return '名前を入力してください';
                              }
                              if (value.trim().length > 40) {
                                return '40文字以内で入力してください';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          TextFormField(
                            controller: _bioController,
                            maxLines: 4,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              labelText: '自己紹介',
                              alignLabelWithHint: true,
                              hintText: '趣味や好きなことを書いてみましょう',
                            ),
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _saveProfile,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: const Text('保存する'),
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

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }
}
