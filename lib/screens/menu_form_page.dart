import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/menu_item.dart';
import '../services/menu_service.dart';

class MenuFormPage extends StatefulWidget {
  const MenuFormPage({super.key, this.menu});

  final MenuItem? menu;

  @override
  State<MenuFormPage> createState() => _MenuFormPageState();
}

class _MenuFormPageState extends State<MenuFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final MenuService _menuService = MenuService();

  MenuCategory _selectedCategory = MenuCategory.drink;
  XFile? _pickedImage;
  String? _initialImageUrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final menu = widget.menu;
    if (menu != null) {
      _nameController.text = menu.name;
      _priceController.text = menu.price.toString();
      _selectedCategory = menu.category;
      _initialImageUrl = menu.imageUrl;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        _pickedImage = picked;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('画像の選択に失敗しました')),
      );
    }
  }

  Future<void> _confirmAndSave() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final isEdit = widget.menu != null;
    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text(
              isEdit ? 'この内容でメニューを更新しますか？' : 'この内容でメニューを作成しますか？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isEdit ? '更新する' : '作成する'),
              ),
            ],
          ),
        ) ??
        false;
    if (!mounted || !shouldSave) return;
    await _saveMenu();
  }

  Future<void> _saveMenu() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final price = int.tryParse(_priceController.text.trim()) ?? 0;

    try {
      if (widget.menu == null) {
        await _menuService.createMenu(
          name: _nameController.text.trim(),
          price: price,
          category: _selectedCategory,
          image: _pickedImage,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('メニューを作成しました')),
        );
      } else {
        await _menuService.updateMenu(
          menuId: widget.menu!.id,
          name: _nameController.text.trim(),
          price: price,
          category: _selectedCategory,
          newImage: _pickedImage,
          previousImageUrl: _initialImageUrl,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('メニューを更新しました')),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('メニューの保存に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildImagePreview() {
    Widget child;
    if (_pickedImage != null) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(_pickedImage!.path),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      );
    } else if (_initialImageUrl != null && _initialImageUrl!.isNotEmpty) {
      child = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _initialImageUrl!,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          loadingBuilder: (context, widget, progress) {
            if (progress == null) return widget;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 48),
          ),
        ),
      );
    } else {
      child = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 8),
          Text(
            '1:1 比率の画像を選択',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      );
    }

    return AspectRatio(
      aspectRatio: 1,
      child: InkWell(
        onTap: _isSaving ? null : _pickImage,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade200,
          ),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.menu != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'メニューを編集' : '新規メニュー作成'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _confirmAndSave,
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'メニュー画像',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildImagePreview(),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'メニュー名',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'メニュー名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: '値段 (円)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '値段を入力してください';
                  }
                  final number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return '1円以上の値段を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MenuCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'ジャンル',
                  border: OutlineInputBorder(),
                ),
                items: MenuCategory.values
                    .map(
                      (category) => DropdownMenuItem<MenuCategory>(
                        value: category,
                        child: Text(category.label),
                      ),
                    )
                    .toList(),
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _selectedCategory = value);
                      },
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _isSaving ? null : _confirmAndSave,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? '保存中...' : '保存'),
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
