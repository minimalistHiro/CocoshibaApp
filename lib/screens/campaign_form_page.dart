import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/campaign.dart';
import '../services/campaign_service.dart';

class CampaignFormPage extends StatefulWidget {
  const CampaignFormPage({super.key, this.campaign});

  final Campaign? campaign;

  @override
  State<CampaignFormPage> createState() => _CampaignFormPageState();
}

class _CampaignFormPageState extends State<CampaignFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final CampaignService _campaignService = CampaignService();
  final ImagePicker _picker = ImagePicker();

  DateTime? _displayStart;
  DateTime? _displayEnd;
  DateTime? _eventStart;
  DateTime? _eventEnd;

  XFile? _pickedImage;
  String? _existingImageUrl;
  String? _initialImageUrl;
  bool _removeExistingImage = false;
  bool _isSaving = false;
  bool _lockEventToDisplay = false;

  @override
  void initState() {
    super.initState();
    final campaign = widget.campaign;
    _initialImageUrl = campaign?.imageUrl;
    _existingImageUrl = campaign?.imageUrl;
    if (campaign != null) {
      _titleController.text = campaign.title;
      _bodyController.text = campaign.body;
      _displayStart = campaign.displayStart;
      _displayEnd = campaign.displayEnd;
      _eventStart = campaign.eventStart;
      _eventEnd = campaign.eventEnd;
      _lockEventToDisplay = _displayStart != null &&
          _displayEnd != null &&
          _displayStart == _eventStart &&
          _displayEnd == _eventEnd;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isSaving) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxHeight: 1800,
      maxWidth: 900,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _pickedImage = picked;
      _existingImageUrl = null;
      _removeExistingImage = false;
    });
  }

  void _syncEventWithDisplay() {
    if (!_lockEventToDisplay) return;
    setState(() {
      _eventStart = _displayStart;
      _eventEnd = _displayEnd;
    });
  }

  void _removeImage() {
    if (_isSaving) return;
    setState(() {
      _pickedImage = null;
      _existingImageUrl = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _selectDateTime({
    required DateTime? currentValue,
    required void Function(DateTime value) onSelected,
  }) async {
    final now = DateTime.now();
    final initialDate = currentValue ?? now;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentValue ?? now),
    );
    if (pickedTime == null) return;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    onSelected(selected);
  }

  bool _validatePeriods(ScaffoldMessengerState messenger) {
    if (_lockEventToDisplay &&
        _eventStart == null &&
        _displayStart != null &&
        _displayEnd != null) {
      _eventStart = _displayStart;
      _eventEnd = _displayEnd;
    }
    if (_displayStart == null ||
        _displayEnd == null ||
        _eventStart == null ||
        _eventEnd == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('掲載期間と開催期間をすべて設定してください')),
      );
      return false;
    }
    if (!_displayEnd!.isAfter(_displayStart!)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('掲載終了は掲載開始より後にしてください')),
      );
      return false;
    }
    if (!_eventEnd!.isAfter(_eventStart!)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('開催終了は開催開始より後にしてください')),
      );
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    if (_pickedImage == null &&
        _existingImageUrl == null &&
        !_removeExistingImage) {
      messenger.showSnackBar(
        const SnackBar(content: Text('キャンペーン画像を追加してください（縦2:横1 推奨）')),
      );
      return;
    }
    if (!_validatePeriods(messenger)) return;

    setState(() => _isSaving = true);

    try {
      if (widget.campaign == null) {
        await _campaignService.createCampaign(
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          displayStart: _displayStart!,
          displayEnd: _displayEnd!,
          eventStart: _eventStart!,
          eventEnd: _eventEnd!,
          image: _pickedImage,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('キャンペーンを作成しました')),
        );
      } else {
        await _campaignService.updateCampaign(
          campaignId: widget.campaign!.id,
          title: _titleController.text.trim(),
          body: _bodyController.text.trim(),
          displayStart: _displayStart!,
          displayEnd: _displayEnd!,
          eventStart: _eventStart!,
          eventEnd: _eventEnd!,
          currentImageUrl: _initialImageUrl,
          newImage: _pickedImage,
          removeImage: _removeExistingImage,
        );
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('キャンペーンを更新しました')),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.campaign != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'キャンペーンを編集' : '新規キャンペーン'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'キャンペーン画像（横2：縦1 推奨）',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _CampaignImagePicker(
                  imageFile: _pickedImage,
                  imageUrl: _existingImageUrl,
                  onPick: _pickImage,
                  onRemove: _removeImage,
                ),
                const SizedBox(height: 24),
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
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                  minLines: 4,
                  maxLines: 8,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '本文を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  '掲載期間',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeField(
                        label: '開始',
                        value: _displayStart,
                        onTap: () => _selectDateTime(
                          currentValue: _displayStart,
                          onSelected: (value) {
                            setState(() {
                              _displayStart = value;
                              if (_displayEnd == null ||
                                  !_displayEnd!.isAfter(value)) {
                                _displayEnd = value.add(const Duration(hours: 1));
                              }
                            });
                            _syncEventWithDisplay();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateTimeField(
                        label: '終了',
                        value: _displayEnd,
                        onTap: () => _selectDateTime(
                          currentValue: _displayEnd ?? _displayStart,
                          onSelected: (value) {
                            setState(() {
                              _displayEnd = value;
                            });
                            _syncEventWithDisplay();
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  '開催期間',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('掲載期間と同じにする'),
                  value: _lockEventToDisplay,
                  onChanged: (value) {
                    setState(() {
                      _lockEventToDisplay = value;
                      if (value) {
                        _eventStart = _displayStart;
                        _eventEnd = _displayEnd;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeField(
                        label: '開始',
                        value: _eventStart,
                        enabled: !_lockEventToDisplay,
                        onTap: () => _selectDateTime(
                          currentValue: _eventStart,
                          onSelected: (value) {
                            setState(() {
                              _eventStart = value;
                              if (_eventEnd == null ||
                                  !_eventEnd!.isAfter(value)) {
                                _eventEnd = value.add(const Duration(hours: 1));
                              }
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateTimeField(
                        label: '終了',
                        value: _eventEnd,
                        enabled: !_lockEventToDisplay,
                        onTap: () => _selectDateTime(
                          currentValue: _eventEnd ?? _eventStart,
                          onSelected: (value) {
                            setState(() {
                              _eventEnd = value;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _submit,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(isEditing ? 'キャンペーンを保存' : 'キャンペーンを作成'),
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

class _CampaignImagePicker extends StatelessWidget {
  const _CampaignImagePicker({
    required this.imageFile,
    required this.imageUrl,
    required this.onPick,
    required this.onRemove,
  });

  final XFile? imageFile;
  final String? imageUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    Widget buildPreview() {
      if (imageFile != null) {
        return Image.file(
          File(imageFile!.path),
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }
      if (imageUrl != null && imageUrl!.isNotEmpty) {
        return Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          width: double.infinity,
        );
      }
      return Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: Icon(Icons.add_photo_alternate_outlined, size: 40),
        ),
      );
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 2 / 1,
            child: buildPreview(),
          ),
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              if (imageFile != null || (imageUrl != null && imageUrl!.isNotEmpty))
                IconButton.filled(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: '画像を削除',
                ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: onPick,
                icon: const Icon(Icons.edit_outlined),
                tooltip: '画像を選択',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    String? display;
    if (value != null) {
      String twoDigits(int v) => v.toString().padLeft(2, '0');
      display = '${value!.year}/${twoDigits(value!.month)}/${twoDigits(value!.day)} '
          '${twoDigits(value!.hour)}:${twoDigits(value!.minute)}';
    }

    return InkWell(
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          enabled: enabled,
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            display ?? '未選択',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}
