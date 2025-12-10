import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/existing_event_service.dart';

class ExistingEventCreatePage extends StatefulWidget {
  const ExistingEventCreatePage({super.key});

  @override
  State<ExistingEventCreatePage> createState() => _ExistingEventCreatePageState();
}

class _ExistingEventCreatePageState extends State<ExistingEventCreatePage> {
  static const List<Color> _colorPalette = [
    Color(0xFFEF5350),
    Color(0xFFF06292),
    Color(0xFFAB47BC),
    Color(0xFF7E57C2),
    Color(0xFF5C6BC0),
    Color(0xFF42A5F5),
    Color(0xFF26A69A),
    Color(0xFF66BB6A),
    Color(0xFFFFCA28),
    Color(0xFFFFA726),
    Color(0xFFFF7043),
    Color(0xFF8D6E63),
  ];
  static final List<int> _capacityOptions =
      List<int>.generate(30, (index) => index + 1);

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _organizerController = TextEditingController();
  final _contentController = TextEditingController();

  final ExistingEventService _existingEventService = ExistingEventService();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  int _selectedColorIndex = 0;
  int _selectedCapacity = 10;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _organizerController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      await _existingEventService.createExistingEvent(
        name: _nameController.text.trim(),
        organizer: _organizerController.text.trim(),
        content: _contentController.text.trim(),
        images: _images,
        colorValue: _colorPalette[_selectedColorIndex].value,
        capacity: _selectedCapacity,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('既存イベントを作成しました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('既存イベントの作成に失敗しました: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _images.length;
    if (remaining <= 0) return;

    final pickedFiles = await _picker.pickMultiImage(
      maxHeight: 1080,
      maxWidth: 1080,
      imageQuality: 85,
    );

    if (pickedFiles == null || pickedFiles.isEmpty) return;

    setState(() {
      _images.addAll(pickedFiles.take(remaining));
    });
  }

  void _removeImage(XFile image) {
    setState(() {
      _images.remove(image);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('既存イベントを新規作成'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'イベント名'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'イベント名を入力してください' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _organizerController,
                  decoration: const InputDecoration(labelText: '主催者'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '主催者を入力してください' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: const InputDecoration(
                    labelText: 'イベント内容',
                    alignLabelWithHint: true,
                  ),
                  minLines: 4,
                  maxLines: 6,
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '内容を入力してください' : null,
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<int>(
                  value: _selectedCapacity,
                  decoration: const InputDecoration(labelText: '定員'),
                  items: _capacityOptions
                      .map(
                        (value) => DropdownMenuItem<int>(
                          value: value,
                          child: Text('$value 人'),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _selectedCapacity = value);
                          }
                        },
                ),
                const SizedBox(height: 24),
                Text(
                  'イベントカラー',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(_colorPalette.length, (index) {
                    final color = _colorPalette[index];
                    final selected = _selectedColorIndex == index;
                    return GestureDetector(
                      onTap: _isSubmitting
                          ? null
                          : () => setState(() => _selectedColorIndex = index),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Colors.black12,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                _ExistingEventImagePicker(
                  images: _images,
                  onAdd: _isSubmitting ? null : _pickImages,
                  onRemove: _isSubmitting ? null : _removeImage,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : const Text('既存イベントを作成'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExistingEventImagePicker extends StatelessWidget {
  const _ExistingEventImagePicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> images;
  final VoidCallback? onAdd;
  final void Function(XFile image)? onRemove;

  @override
  Widget build(BuildContext context) {
    final canAddMore = images.length < 5 && onAdd != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'イベント画像（最大5枚、1:1 推奨）',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            Text('${images.length}/5'),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final image in images)
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(image.path),
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => onRemove?.call(image),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            if (canAddMore)
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Icon(Icons.add_a_photo),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
