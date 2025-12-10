import 'package:flutter/material.dart';

import '../services/owner_settings_service.dart';

class OwnerSettingsPage extends StatefulWidget {
  const OwnerSettingsPage({super.key});

  @override
  State<OwnerSettingsPage> createState() => _OwnerSettingsPageState();
}

class _OwnerSettingsPageState extends State<OwnerSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final List<int> _rateOptions =
      List<int>.generate(100, (index) => index + 1); // 1〜100
  final OwnerSettingsService _ownerSettingsService = OwnerSettingsService();

  int _selectedRate = 5;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialRate();
  }

  Future<void> _loadInitialRate() async {
    try {
      final rate = await _ownerSettingsService.fetchPointRate();
      if (!mounted || rate == null) return;
      if (rate >= 1 && rate <= _rateOptions.length) {
        setState(() => _selectedRate = rate);
      }
    } catch (_) {
      // Ignore load errors and keep default value.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showSaveConfirmation() async {
    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: Text('ポイント還元率を$_selectedRate%で保存しますか？'),
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
    if (!mounted || !shouldSave) return;
    await _saveRate();
  }

  Future<void> _saveRate() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await _ownerSettingsService.savePointRate(_selectedRate);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('ポイント還元率を$_selectedRate%に設定しました'),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('ポイント還元率の保存に失敗しました'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('オーナー設定'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ポイント還元率',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '会員へのポイント還元率を 1〜100% の範囲で選択してください。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<int>(
                              value: _selectedRate,
                              decoration: const InputDecoration(
                                labelText: '還元率 (%)',
                              ),
                              items: _rateOptions
                                  .map(
                                    (rate) => DropdownMenuItem(
                                      value: rate,
                                      child: Text('$rate%'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      if (value == null) return;
                                      setState(() => _selectedRate = value);
                                    },
                              validator: (value) {
                                if (value == null ||
                                    value < 1 ||
                                    value > _rateOptions.length) {
                                  return '1〜100の範囲で選択してください';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '現在の設定: $_selectedRate%',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isSaving ? null : _showSaveConfirmation,
                      icon: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_isSaving ? '保存中...' : '設定を保存'),
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
