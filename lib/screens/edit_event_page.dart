import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import '../services/existing_event_service.dart';
import '../services/event_service.dart';

class EditEventPage extends StatefulWidget {
  const EditEventPage({super.key, required this.event});

  final CalendarEvent event;

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
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
  final _existingEventIdController = TextEditingController();
  final _organizerController = TextEditingController();
  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _contentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  final EventService _eventService = EventService();
  final ExistingEventService _existingEventService = ExistingEventService();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late int _selectedColorIndex;
  late int _selectedCapacity;
  late List<String> _existingImageUrls;
  final List<String> _removedImageUrls = [];
  final List<XFile> _newImages = [];
  bool _isSubmitting = false;
  bool _isSavingExistingEvent = false;

  TimeOfDay _roundToFiveMinutes(TimeOfDay time) {
    const interval = 5;
    final totalMinutes = time.hour * 60 + time.minute;
    final adjusted = totalMinutes - (totalMinutes % interval);
    return TimeOfDay(hour: adjusted ~/ 60, minute: adjusted % 60);
  }

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  void _initializeForm() {
    final event = widget.event;
    _nameController.text = event.name;
    _organizerController.text = event.organizer;
    _contentController.text = event.content;
    _existingEventIdController.text = event.existingEventId ?? '';
    _existingImageUrls = List<String>.from(event.imageUrls);

    _selectedDate = DateTime(
      event.startDateTime.year,
      event.startDateTime.month,
      event.startDateTime.day,
    );
    _dateController.text = _formatDateLabel(_selectedDate!);

    _startTime = TimeOfDay.fromDateTime(event.startDateTime);
    _startTimeController.text = _formatTimeLabel(_startTime!);

    _endTime = TimeOfDay.fromDateTime(event.endDateTime);
    _endTimeController.text = _formatTimeLabel(_endTime!);

    _selectedCapacity = event.capacity > 0 ? event.capacity : 1;
    final colorIndex = _colorPalette.indexWhere(
      (color) => color.value == event.colorValue,
    );
    _selectedColorIndex = colorIndex >= 0 ? colorIndex : 0;
  }

  String _formatDateLabel(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeLabel(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _existingEventIdController.dispose();
    _organizerController.dispose();
    _dateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final initialDate = _selectedDate ?? widget.event.startDateTime;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = _formatDateLabel(picked);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final baseTime = _startTime ?? TimeOfDay.now();
    final initialTime = _roundToFiveMinutes(baseTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      final normalized = _roundToFiveMinutes(picked);
      setState(() {
        _startTime = normalized;
        _startTimeController.text = _formatTimeLabel(normalized);
        if (_endTime == null || _compareTimes(_endTime!, normalized) <= 0) {
          final endInitial = TimeOfDay(
            hour: (normalized.hour + 1) % 24,
            minute: normalized.minute,
          );
          _endTime = endInitial;
          _endTimeController.text = _formatTimeLabel(endInitial);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final baseTime = _endTime ?? _startTime ?? TimeOfDay.now();
    final initialTime = _roundToFiveMinutes(baseTime);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked != null) {
      final normalized = _roundToFiveMinutes(picked);
      setState(() {
        _endTime = normalized;
        _endTimeController.text = _formatTimeLabel(normalized);
      });
    }
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour - b.hour;
    return a.minute - b.minute;
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _existingImageUrls.length - _newImages.length;
    if (remaining <= 0) return;

    final pickedFiles = await _picker.pickMultiImage(
      maxHeight: 1080,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (pickedFiles == null || pickedFiles.isEmpty) return;
    setState(() {
      _newImages.addAll(pickedFiles.take(remaining));
    });
  }

  void _removeExistingImage(String url) {
    setState(() {
      _existingImageUrls.remove(url);
      _removedImageUrls.add(url);
    });
  }

  void _removeNewImage(XFile image) {
    setState(() {
      _newImages.remove(image);
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

    final existingEventIdText = _existingEventIdController.text.trim();
    final existingEventId =
        existingEventIdText.isEmpty ? null : existingEventIdText;

    setState(() => _isSubmitting = true);
    try {
      final updatedImageUrls = await _eventService.updateEvent(
        eventId: widget.event.id,
        name: _nameController.text.trim(),
        organizer: _organizerController.text.trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        content: _contentController.text.trim(),
        colorValue: _colorPalette[_selectedColorIndex].value,
        capacity: _selectedCapacity,
        remainingImageUrls: _existingImageUrls,
        newImages: _newImages,
        removedImageUrls: _removedImageUrls,
        existingEventId: existingEventId,
      );

      final updatedEvent = CalendarEvent(
        id: widget.event.id,
        name: _nameController.text.trim(),
        organizer: _organizerController.text.trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        content: _contentController.text.trim(),
        imageUrls: updatedImageUrls,
        colorValue: _colorPalette[_selectedColorIndex].value,
        capacity: _selectedCapacity,
        isClosedDay: widget.event.isClosedDay,
        existingEventId: existingEventId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('イベントを更新しました')),
      );
      Navigator.of(context).pop(updatedEvent);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalImages = _existingImageUrls.length + _newImages.length;
    final canAddMore = totalImages < 5 && !_isSubmitting;
    return Scaffold(
      appBar: AppBar(
        title: const Text('イベント編集'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _existingEventIdController,
                decoration: const InputDecoration(
                  labelText: '既存イベントID (任意)',
                  helperText: '既存イベントのUIDを紐付ける場合に入力します',
                ),
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _selectedCapacity,
                decoration: const InputDecoration(labelText: '定員'),
                items: _capacityOptions
                    .map(
                      (capacity) => DropdownMenuItem(
                        value: capacity,
                        child: Text('$capacity人'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedCapacity = value);
                },
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
                  Text('$totalImages/5'),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final url in _existingImageUrls)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (!_isSubmitting)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(url),
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
                  for (final file in _newImages)
                    Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(file.path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (!_isSubmitting)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeNewImage(file),
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
                      onTap: _isSubmitting ? null : _pickImages,
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
              const SizedBox(height: 24),
              FilledButton.tonal(
                onPressed: _isSubmitting || _isSavingExistingEvent
                    ? null
                    : _saveAsExistingEvent,
                child: _isSavingExistingEvent
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('既存イベントに保存'),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('更新する'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAsExistingEvent() async {
    if (!_formKey.currentState!.validate()) return;
    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('既存イベントに保存'),
            content: const Text('この内容で既存イベントとして保存しますか？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存する'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldSave) return;

    var existingEventId = _existingEventIdController.text.trim();
    if (existingEventId.isEmpty) {
      existingEventId = _generateRandomExistingEventId();
      _existingEventIdController.text = existingEventId;
    }

    setState(() => _isSavingExistingEvent = true);
    try {
      const maxImages = 5;
      final urlsToDownload = _existingImageUrls.take(maxImages).toList();
      final downloadedImages = await _downloadImagesFromUrls(urlsToDownload);
      final images = <XFile>[...downloadedImages];
      final remainingSlots = maxImages - images.length;
      if (remainingSlots > 0) {
        images.addAll(_newImages.take(remainingSlots));
      }
      final savedId = await _existingEventService.createExistingEvent(
        name: _nameController.text.trim(),
        organizer: _organizerController.text.trim(),
        content: _contentController.text.trim(),
        images: images,
        colorValue: _colorPalette[_selectedColorIndex].value,
        capacity: _selectedCapacity,
        existingEventId: existingEventId,
      );
      if (!mounted) return;
      if (savedId != existingEventId) {
        _existingEventIdController.text = savedId;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('既存イベントとして保存しました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('既存イベントへの保存に失敗しました: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingExistingEvent = false);
      }
    }
  }

  Future<List<XFile>> _downloadImagesFromUrls(List<String> urls) async {
    final client = http.Client();
    final List<XFile> downloaded = [];
    try {
      for (final url in urls) {
        final uri = Uri.tryParse(url);
        if (uri == null) continue;
        try {
          final response = await client.get(uri);
          if (response.statusCode == HttpStatus.ok) {
            final mimeType = response.headers['content-type'];
            final name = uri.pathSegments.isNotEmpty
                ? uri.pathSegments.last
                : 'existing_${DateTime.now().millisecondsSinceEpoch}.jpg';
            downloaded.add(
              XFile.fromData(
                response.bodyBytes,
                mimeType: mimeType,
                name: name,
              ),
            );
          }
        } catch (_) {
          // ignore and continue downloading other images
        }
      }
    } finally {
      client.close();
    }
    return downloaded;
  }

  String _generateRandomExistingEventId({int length = 20}) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
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
