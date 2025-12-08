import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/event_service.dart';

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({super.key});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
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
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _organizerController = TextEditingController();
  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _contentController = TextEditingController();

  final EventService _eventService = EventService();
  final ImagePicker _picker = ImagePicker();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final List<XFile> _images = [];
  bool _isSubmitting = false;
  int _selectedColorIndex = 5;

  @override
  void dispose() {
    _nameController.dispose();
    _organizerController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate = _selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.year}/${picked.month.toString().padLeft(2, '0')}/${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _pickStartTime() async {
    final initialTime = _startTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        _startTimeController.text = '$hour:$minute';
        if (_endTime == null ||
            _compareTimes(_endTime!, picked) <= 0) {
          final endInitial =
              TimeOfDay(hour: (picked.hour + 1) % 24, minute: picked.minute);
          _endTime = endInitial;
          _endTimeController.text =
              '${endInitial.hour.toString().padLeft(2, '0')}:${endInitial.minute.toString().padLeft(2, '0')}';
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final initialTime = _endTime ?? _startTime ?? TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      setState(() {
        _endTime = picked;
        final hour = picked.hour.toString().padLeft(2, '0');
        final minute = picked.minute.toString().padLeft(2, '0');
        _endTimeController.text = '$hour:$minute';
      });
    }
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour - b.hour;
    return a.minute - b.minute;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final date = _selectedDate;
    final startTime = _startTime;
    final endTime = _endTime;
    if (date == null || startTime == null || endTime == null) return;

    final startDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      startTime.hour,
      startTime.minute,
    );
    final endDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      endTime.hour,
      endTime.minute,
    );

    if (!endDateTime.isAfter(startDateTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('終了時間は開始時間より後にしてください')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await _eventService.createEvent(
        name: _nameController.text.trim(),
        organizer: _organizerController.text.trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        content: _contentController.text.trim(),
        images: _images,
        colorValue: _colorPalette[_selectedColorIndex].value,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('イベントを作成しました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('イベント作成に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント作成'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'イベント名'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'イベント名を入力してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _organizerController,
                decoration: const InputDecoration(labelText: '主催者'),
                validator: (value) =>
                    value == null || value.isEmpty ? '主催者を入力してください' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: '日付',
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                onTap: _pickDate,
                validator: (value) =>
                    value == null || value.isEmpty ? '日付を選択してください' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '開始時間',
                        suffixIcon: Icon(Icons.play_arrow),
                      ),
                      onTap: _pickStartTime,
                      validator: (value) => value == null || value.isEmpty
                          ? '開始時間を選択してください'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _endTimeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: '終了時間',
                        suffixIcon: Icon(Icons.stop),
                      ),
                      onTap: _pickEndTime,
                      validator: (value) => value == null || value.isEmpty
                          ? '終了時間を選択してください'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'イベント内容',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    value == null || value.isEmpty ? 'イベント内容を入力してください' : null,
              ),
              const SizedBox(height: 24),
              _ColorSelector(
                palette: _colorPalette,
                selectedIndex: _selectedColorIndex,
                onSelect: (index) {
                  setState(() => _selectedColorIndex = index);
                },
              ),
              const SizedBox(height: 24),
              _ImagePickerGrid(
                images: _images,
                onAdd: () => _pickImages(),
                onRemove: _removeImage,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('作成する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePickerGrid extends StatelessWidget {
  const _ImagePickerGrid({
    required this.images,
    required this.onAdd,
    required this.onRemove,
  });

  final List<XFile> images;
  final VoidCallback onAdd;
  final void Function(XFile image) onRemove;

  @override
  Widget build(BuildContext context) {
    final canAddMore = images.length < 5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'イベント画像（最大5枚、1:1 推奨）',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Text(
              '${images.length}/5',
              style: Theme.of(context).textTheme.bodySmall,
            ),
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
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Image.file(
                        File(image.path),
                        fit: BoxFit.cover,
                        width: 110,
                        height: 110,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onRemove(image),
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
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: const Center(
                    child: Icon(Icons.add_a_photo),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ColorSelector extends StatelessWidget {
  const _ColorSelector({
    required this.palette,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<Color> palette;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'イベントカラー',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: List.generate(
            palette.length,
            (index) {
              final color = palette[index];
              final isSelected = index == selectedIndex;
              return GestureDetector(
                onTap: () => onSelect(index),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isSelected ? Colors.black : Colors.white,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
