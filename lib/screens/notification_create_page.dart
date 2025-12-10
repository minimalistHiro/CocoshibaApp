import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/notification_service.dart';

class NotificationCreatePage extends StatefulWidget {
  const NotificationCreatePage({super.key});

  @override
  State<NotificationCreatePage> createState() => _NotificationCreatePageState();
}

class _NotificationCreatePageState extends State<NotificationCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _picker = ImagePicker();
  final NotificationService _notificationService = NotificationService();
  static const _categories = [
    'キャンペーン',
    'メンテナンス',
    'イベント',
    '一般',
  ];

  Uint8List? _imageBytes;
  bool _isSaving = false;
  String? _selectedCategory = _categories.first;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSaving) return;
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (pickedFile == null) {
        return;
      }
      final bytes = await pickedFile.readAsBytes();
      if (!mounted) return;
      setState(() => _imageBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の選択に失敗しました')),
      );
    }
  }

  void _removeImage() {
    if (_isSaving) return;
    setState(() => _imageBytes = null);
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await _notificationService.createNotification(
        title: _titleController.text.trim(),
        body: _bodyController.text.trim(),
        category: _selectedCategory!,
        imageBytes: _imageBytes,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, stackTrace) {
      debugPrint('Failed to create notification: $e');
      debugPrint('$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('お知らせの保存に失敗しました')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新規お知らせ'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'タイトル',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'タイトルを入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: '本文',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 6,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '本文を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'カテゴリ',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  value: _selectedCategory,
                  items: _categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                      )
                      .toList(),
                  onChanged: _isSaving ? null : (value) {
                    setState(() => _selectedCategory = value);
                  },
                  validator: (value) =>
                      value == null ? 'カテゴリを選択してください' : null,
                ),
                const SizedBox(height: 24),
                Text(
                  '画像（1枚まで）',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 12),
                _imageBytes == null
                    ? _ImagePlaceholder(onTap: _pickImage)
                    : _SelectedImage(
                        bytes: _imageBytes!,
                        onChange: _pickImage,
                        onRemove: _removeImage,
                      ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: const Icon(Icons.check),
                  label: const Text('この内容で登録'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _OutlinedContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_photo_alternate_outlined, size: 36),
            SizedBox(height: 8),
            Text('画像を追加'),
          ],
        ),
      ),
    );
  }
}

class _SelectedImage extends StatelessWidget {
  const _SelectedImage({
    required this.bytes,
    required this.onChange,
    required this.onRemove,
  });

  final Uint8List bytes;
  final VoidCallback onChange;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            bytes,
            height: 200,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onChange,
                icon: const Icon(Icons.edit),
                label: const Text('変更'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('削除'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OutlinedContainer extends StatelessWidget {
  const _OutlinedContainer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(child: child),
    );
  }
}
