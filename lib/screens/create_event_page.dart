import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import '../models/existing_event.dart';
import '../services/event_service.dart';
import '../services/existing_event_service.dart';

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
  final _existingEventIdController = TextEditingController();
  final _organizerController = TextEditingController();
  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _contentController = TextEditingController();
  static final List<int> _capacityOptions =
      List<int>.generate(30, (index) => index + 1);

  final EventService _eventService = EventService();
  final ExistingEventService _existingEventService = ExistingEventService();
  final ImagePicker _picker = ImagePicker();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final List<XFile> _images = [];
  bool _isSubmitting = false;
  bool _isImportingExistingImages = false;
  int _selectedColorIndex = 5;
  int _selectedCapacity = 10;

  TimeOfDay _roundToFiveMinutes(TimeOfDay time) {
    const interval = 5;
    final totalMinutes = time.hour * 60 + time.minute;
    final adjusted = totalMinutes - (totalMinutes % interval);
    return TimeOfDay(hour: adjusted ~/ 60, minute: adjusted % 60);
  }

  String _formatDateLabel(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTimeLabel(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
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

    final existingEventIdText = _existingEventIdController.text.trim();
    final existingEventId =
        existingEventIdText.isEmpty ? null : existingEventIdText;

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
        capacity: _selectedCapacity,
        existingEventId: existingEventId,
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

  Future<void> _openExistingEventPicker() async {
    final eventsStream = _existingEventService.watchExistingEvents();
    final selected = await showModalBottomSheet<ExistingEvent>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _ExistingEventPickerSheet(existingEventsStream: eventsStream),
    );
    if (selected == null) return;
    await _applyExistingEventToForm(selected);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selected.name}の情報を読み込みました')),
    );
  }

  Future<void> _applyExistingEventToForm(ExistingEvent event) async {
    if (!mounted) return;
    final colorIndex = _colorPalette.indexWhere(
      (color) => color.value == event.colorValue,
    );

    setState(() {
      _nameController.text = event.name;
      _organizerController.text = event.organizer;
      _contentController.text = event.content;
      _existingEventIdController.text = event.id;
      if (colorIndex >= 0) {
        _selectedColorIndex = colorIndex;
      }
      if (_capacityOptions.contains(event.capacity)) {
        _selectedCapacity = event.capacity;
      }
      _images.clear();
      _isImportingExistingImages = event.imageUrls.isNotEmpty;
    });

    if (event.imageUrls.isEmpty) {
      setState(() => _isImportingExistingImages = false);
      return;
    }

    try {
      final downloadedImages =
          await _downloadExistingEventImages(event.imageUrls.take(5).toList());
      if (!mounted) return;
      if (downloadedImages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('画像の読み込みに失敗しました')),
        );
      } else {
        setState(() {
          _images.addAll(downloadedImages);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isImportingExistingImages = false);
      }
    }
  }

  Future<List<XFile>> _downloadExistingEventImages(List<String> urls) async {
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
          // Skip failed downloads to allow others to complete.
        }
      }
    } finally {
      client.close();
    }
    return downloaded;
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
              FilledButton.tonalIcon(
                onPressed: _openExistingEventPicker,
                icon: const Icon(Icons.history),
                label: const Text('既存のイベントを呼び出す'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _existingEventIdController,
                decoration: const InputDecoration(
                  labelText: '既存イベントID (任意)',
                  helperText: '既存イベントのUIDを紐付ける場合に入力します',
                ),
              ),
              const SizedBox(height: 24),
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
              _ImagePickerGrid(
                images: _images,
                onAdd: () => _pickImages(),
                onRemove: _removeImage,
                isBusy: _isSubmitting || _isImportingExistingImages,
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
    required this.isBusy,
  });

  final List<XFile> images;
  final VoidCallback onAdd;
  final void Function(XFile image) onRemove;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final canAddMore = !isBusy && images.length < 5;
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
        if (isBusy && images.isEmpty)
          Container(
            width: 100,
            height: 100,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          )
        else
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
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: isBusy ? null : () => onRemove(image),
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
                  onTap: isBusy ? null : onAdd,
                  child: Container(
                    width: 100,
                    height: 100,
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

class _ExistingEventPickerSheet extends StatelessWidget {
  const _ExistingEventPickerSheet({required this.existingEventsStream});

  final Stream<List<ExistingEvent>> existingEventsStream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.85,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '既存のイベントを選択',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<ExistingEvent>>(
                  stream: existingEventsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text('イベントの取得に失敗しました'),
                      );
                    }
                    final events = snapshot.data ?? const <ExistingEvent>[];
                    if (events.isEmpty) {
                      return const Center(
                        child: Text('表示できるイベントがありません'),
                      );
                    }
                    return ListView.separated(
                      itemCount: events.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: event.color,
                            child: const Icon(Icons.event, color: Colors.white),
                          ),
                          title: Text(event.name),
                          subtitle: Text(
                            _buildSubtitle(event),
                          ),
                          isThreeLine: true,
                          onTap: () => Navigator.of(context).pop(event),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _buildSubtitle(ExistingEvent event) {
    final organizer =
        event.organizer.isEmpty ? '主催者未設定' : '主催: ${event.organizer}';
    final capacity = event.capacity > 0 ? '定員: ${event.capacity}人' : '定員未設定';
    return '$organizer\n$capacity';
  }
}
