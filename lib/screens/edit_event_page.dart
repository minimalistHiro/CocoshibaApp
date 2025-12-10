import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
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
  final _organizerController = TextEditingController();
  final _dateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _contentController = TextEditingController();

  final EventService _eventService = EventService();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  late int _selectedColorIndex;
  late int _selectedCapacity;
  bool _isSubmitting = false;

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
      await _eventService.updateEvent(
        eventId: widget.event.id,
        name: _nameController.text.trim(),
        organizer: _organizerController.text.trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        content: _contentController.text.trim(),
        colorValue: _colorPalette[_selectedColorIndex].value,
        capacity: _selectedCapacity,
      );

      final updatedEvent = CalendarEvent(
        id: widget.event.id,
        name: _nameController.text.trim(),
        organizer: _organizerController.text.trim(),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
        content: _contentController.text.trim(),
        imageUrls: widget.event.imageUrls,
        colorValue: _colorPalette[_selectedColorIndex].value,
        capacity: _selectedCapacity,
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
