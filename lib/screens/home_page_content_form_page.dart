import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/home_page_content.dart';
import '../services/home_page_content_service.dart';

class HomePageContentFormPage extends StatefulWidget {
  const HomePageContentFormPage({super.key, this.content});

  final HomePageContent? content;

  @override
  State<HomePageContentFormPage> createState() =>
      _HomePageContentFormPageState();
}

class _HomePageContentFormPageState extends State<HomePageContentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _priceController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _startTimeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<_EditableImage> _images = [];
  final HomePageContentService _contentService = HomePageContentService();

  bool _isSubmitting = false;
  late HomePageGenre _genre;
  late HomePageButtonType _buttonType;
  DateTime? _eventDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void initState() {
    super.initState();
    final content = widget.content;
    _genre = content?.genre ?? HomePageGenre.sales;
    _buttonType = content?.buttonType ?? HomePageButtonType.reserve;
    if (content != null) {
      _titleController.text = content.title;
      _bodyController.text = content.body;
      if (content.price != null) {
        _priceController.text = content.price.toString();
      }
      _eventDate = content.eventDate;
      _startTime = _parseTimeLabel(content.startTimeLabel);
      _endTime = _parseTimeLabel(content.endTimeLabel);
      _images.addAll(
        content.imageUrls.map(
          (url) => _EditableImage(remoteUrl: url),
        ),
      );
      if (content.eventDate != null) {
        _eventDate = content.eventDate;
        _eventDateController.text = _formatDate(content.eventDate!);
      }
      if (content.startTimeLabel != null) {
        final parsed = _parseTimeLabel(content.startTimeLabel);
        if (parsed != null) {
          _startTime = parsed;
          _startTimeController.text = _timeOfDayToLabel(parsed);
        }
      }
      if (content.endTimeLabel != null) {
        final parsed = _parseTimeLabel(content.endTimeLabel);
        if (parsed != null) {
          _endTime = parsed;
          _endTimeController.text = _timeOfDayToLabel(parsed);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _priceController.dispose();
    _eventDateController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remainingSlots = 3 - _images.length;
    if (remainingSlots <= 0) return;
    final pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    if (pickedFiles == null || pickedFiles.isEmpty) return;
    setState(() {
      _images.addAll(
        pickedFiles.take(remainingSlots).map(
              (file) => _EditableImage(file: file),
            ),
      );
    });
  }

  void _removeImage(_EditableImage image) {
    setState(() => _images.remove(image));
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final initialDate = _eventDate ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate != null) {
      setState(() {
        _eventDate = pickedDate;
        _eventDateController.text = _formatDate(pickedDate);
      });
    }
  }

  Future<void> _pickStartTime() async {
    final initial = _roundToFiveMinutes(_startTime ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final normalized = _roundToFiveMinutes(picked);
      setState(() {
        _startTime = normalized;
        _startTimeController.text = _timeOfDayToLabel(normalized);
        if (_endTime == null || _compareTimes(_endTime!, normalized) <= 0) {
          final endInitial = TimeOfDay(
            hour: (normalized.hour + 1) % 24,
            minute: normalized.minute,
          );
          _endTime = endInitial;
          _endTimeController.text = _timeOfDayToLabel(endInitial);
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    final base = _endTime ?? _startTime ?? TimeOfDay.now();
    final initial = _roundToFiveMinutes(base);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      final normalized = _roundToFiveMinutes(picked);
      setState(() {
        _endTime = normalized;
        _endTimeController.text = _timeOfDayToLabel(normalized);
      });
    }
  }

  TimeOfDay? _parseTimeLabel(String? label) {
    if (label == null || label.isEmpty) return null;
    final parts = label.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatDate(DateTime date) {
    final twoDigits = (int value) => value.toString().padLeft(2, '0');
    return '${date.year}/${twoDigits(date.month)}/${twoDigits(date.day)}';
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) {
    if (a.hour != b.hour) return a.hour - b.hour;
    return a.minute - b.minute;
  }

  TimeOfDay _roundToFiveMinutes(TimeOfDay time) {
    const interval = 5;
    final totalMinutes = time.hour * 60 + time.minute;
    final adjusted = totalMinutes - (totalMinutes % interval);
    return TimeOfDay(
      hour: adjusted ~/ 60,
      minute: adjusted % 60,
    );
  }

  String _timeOfDayToLabel(TimeOfDay time) {
    final twoDigits = (int value) => value.toString().padLeft(2, '0');
    return '${twoDigits(time.hour)}:${twoDigits(time.minute)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_images.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('画像を1枚以上追加してください')),
      );
      return;
    }

    int? price;
    DateTime? eventDate;
    String? startTimeLabel;
    String? endTimeLabel;

    if (_genre == HomePageGenre.sales) {
      final rawPrice = _priceController.text.trim();
      final parsedPrice = int.tryParse(rawPrice);
      if (parsedPrice == null || parsedPrice <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('価格を正しく入力してください')),
        );
        return;
      }
      price = parsedPrice;
    }

    if (_genre == HomePageGenre.event) {
      if (_eventDate == null || _startTime == null || _endTime == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('開催日と時間を設定してください')),
        );
        return;
      }
      if (_compareTimes(_endTime!, _startTime!) <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('終了時刻は開始時刻より後にしてください')),
        );
        return;
      }
      eventDate = _eventDate;
      startTimeLabel = _timeOfDayToLabel(_startTime!);
      endTimeLabel = _timeOfDayToLabel(_endTime!);
    }

    setState(() => _isSubmitting = true);
    final newImages = _images
        .where((item) => item.file != null)
        .map((item) => item.file!)
        .toList(growable: false);
    final retainedUrls = _images
        .where((item) => item.remoteUrl != null)
        .map((item) => item.remoteUrl!)
        .toList(growable: false);
    try {
      if (widget.content == null) {
        await _contentService.createContent(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          genre: _genre,
          images: newImages,
          buttonType: _buttonType,
          price: price,
          eventDate: eventDate,
          startTimeLabel: startTimeLabel,
          endTimeLabel: endTimeLabel,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('ホーム画面ページを追加しました')),
        );
      } else {
        await _contentService.updateContent(
          contentId: widget.content!.id,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          genre: _genre,
          retainedImageUrls: retainedUrls,
          newImages: newImages,
          previousImageUrls: widget.content!.imageUrls,
          buttonType: _buttonType,
          price: price,
          eventDate: eventDate,
          startTimeLabel: startTimeLabel,
          endTimeLabel: endTimeLabel,
        );
        messenger.showSnackBar(
          const SnackBar(content: Text('ホーム画面ページを更新しました')),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('保存に失敗しました。接続状況をご確認ください')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.content != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'ホームページ編集' : '新規ホームページ'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'タイトル',
                  hintText: '例）春の新作グッズが登場！',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'タイトルを入力してください';
                  }
                  if (value.trim().length > 40) {
                    return '40文字以内で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<HomePageGenre>(
                value: _genre,
                decoration: const InputDecoration(labelText: 'ジャンル'),
                items: HomePageGenre.values
                    .map(
                      (genre) => DropdownMenuItem(
                        value: genre,
                        child: Text(genre.label),
                      ),
                    )
                    .toList(),
                onChanged: (genre) {
                  if (genre == null) return;
                  setState(() => _genre = genre);
                },
              ),
              if (_genre == HomePageGenre.sales) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _priceController,
                  decoration: const InputDecoration(
                    labelText: '価格',
                    hintText: '例）1500',
                    suffixText: '円',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !_isSubmitting,
                ),
              ],
              if (_genre == HomePageGenre.event) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _eventDateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: '開催日',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _isSubmitting ? null : _pickEventDate,
                  validator: (value) => value == null || value.isEmpty
                      ? '開催日を選択してください'
                      : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _startTimeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: '開始時刻',
                          suffixIcon: Icon(Icons.play_circle_outline),
                        ),
                        onTap: _isSubmitting ? null : _pickStartTime,
                        validator: (value) => value == null || value.isEmpty
                            ? '開始時刻を選択してください'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endTimeController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: '終了時刻',
                          suffixIcon: Icon(Icons.stop_circle_outlined),
                        ),
                        onTap: _isSubmitting ? null : _pickEndTime,
                        validator: (value) => value == null || value.isEmpty
                            ? '終了時刻を選択してください'
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<HomePageButtonType>(
                value: _buttonType,
                decoration: const InputDecoration(labelText: 'ボタンの種類'),
                items: HomePageButtonType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      ),
                    )
                    .toList(),
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() => _buttonType = value);
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bodyController,
                decoration: const InputDecoration(
                  labelText: '本文',
                  hintText: 'ホーム画面に表示する内容を入力してください',
                ),
                minLines: 5,
                maxLines: 8,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '本文を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              _HomePageImagePicker(
                images: _images,
                isBusy: _isSubmitting,
                onAdd: _pickImages,
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
                    : Text(isEditing ? '更新する' : '作成する'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomePageImagePicker extends StatelessWidget {
  const _HomePageImagePicker({
    required this.images,
    required this.onAdd,
    required this.onRemove,
    required this.isBusy,
  });

  final List<_EditableImage> images;
  final VoidCallback onAdd;
  final ValueChanged<_EditableImage> onRemove;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final canAddMore = images.length < 3 && !isBusy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ホーム画面画像（最大3枚・1:1推奨）',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 8),
            Text(
              '${images.length}/3',
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
                    child: SizedBox(
                      width: 110,
                      height: 110,
                      child: image.remoteUrl != null
                          ? Image.network(
                              image.remoteUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            )
                          : Image.file(
                              File(image.file!.path),
                              fit: BoxFit.cover,
                            ),
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

class _EditableImage {
  _EditableImage({this.remoteUrl, this.file});

  final String? remoteUrl;
  final XFile? file;
}
