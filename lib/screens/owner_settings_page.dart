import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/owner_contact_info.dart';
import '../services/owner_settings_service.dart';
import 'owner_permission_management_page.dart';

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
  final TextEditingController _storeIdController = TextEditingController();
  final TextEditingController _siteUrlController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _xController = TextEditingController();
  final TextEditingController _businessHoursController =
      TextEditingController();
  final Random _random = Random.secure();
  static const int _storeIdLength = 28;
  static const String _storeIdChars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';

  int _selectedRate = 5;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isContactSaving = false;
  String? _storeIdError;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _siteUrlController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _xController.dispose();
    _businessHoursController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final rateFuture = _ownerSettingsService.fetchPointRate();
      final contactFuture = _ownerSettingsService.fetchContactInfo();
      final rate = await rateFuture;
      final contactInfo = await contactFuture ?? OwnerContactInfo.empty;
      if (!mounted) return;
      if (rate != null && rate >= 1 && rate <= _rateOptions.length) {
        _selectedRate = rate;
      }
      _applyContactInfo(contactInfo);
    } catch (_) {
      // Ignore load errors and keep default value.
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applyContactInfo(OwnerContactInfo info) {
    final storeId = info.storeId.isNotEmpty ? info.storeId : _generateStoreId();
    _storeIdController.text = storeId;
    _storeIdError = null;
    _siteUrlController.text = info.siteUrl;
    _emailController.text = info.email;
    _phoneController.text = info.phoneNumber;
    _addressController.text = info.address;
    _facebookController.text = info.facebook;
    _instagramController.text = info.instagram;
    _xController.text = info.xAccount;
    _businessHoursController.text = info.businessHours;
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

  Future<void> _saveContactInfo() async {
    if (!_validateStoreId()) {
      return;
    }
    setState(() => _isContactSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final info = OwnerContactInfo(
      storeId: _storeIdController.text.trim(),
      siteUrl: _siteUrlController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      facebook: _facebookController.text.trim(),
      instagram: _instagramController.text.trim(),
      xAccount: _xController.text.trim(),
      businessHours: _businessHoursController.text.trim(),
    );
    try {
      await _ownerSettingsService.saveContactInfo(info);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('店舗情報を保存しました')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('店舗情報の保存に失敗しました')),
      );
    } finally {
      if (mounted) setState(() => _isContactSaving = false);
    }
  }

  Future<void> _showContactSaveConfirmation() async {
    final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('確認'),
            content: const Text('この店舗情報を保存しますか？'),
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
    await _saveContactInfo();
  }

  void _openOwnerPermissionManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OwnerPermissionManagementPage(),
      ),
    );
  }

  String _generateStoreId() {
    final buffer = StringBuffer();
    for (var i = 0; i < _storeIdLength; i++) {
      buffer.write(
        _storeIdChars[_random.nextInt(_storeIdChars.length)],
      );
    }
    return buffer.toString();
  }

  bool _validateStoreId() {
    final value = _storeIdController.text.trim();
    final isValid = value.length == _storeIdLength &&
        RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
    if (!isValid) {
      setState(() {
        _storeIdError = '28文字の英数字(-, _)で入力してください';
      });
      return false;
    }
    if (_storeIdError != null) {
      setState(() => _storeIdError = null);
    }
    return true;
  }

  void _regenerateStoreId() {
    setState(() {
      _storeIdController.text = _generateStoreId();
      _storeIdError = null;
    });
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
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: const Text('オーナー権限管理'),
                        subtitle: const Text('オーナー・サブオーナーの権限を変更'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _openOwnerPermissionManagement,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                    const SizedBox(height: 32),
                    Text(
                      '店舗情報',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'アプリ内で共有する基本情報を入力してください。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _storeIdController,
                              decoration: InputDecoration(
                                labelText: '店舗ID',
                                helperText:
                                    'Firebase UID と同じ形式 (28文字の英数字 + -_)',
                                errorText: _storeIdError,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.autorenew),
                                  tooltip: '自動作成',
                                  onPressed:
                                      _isContactSaving ? null : _regenerateStoreId,
                                ),
                              ),
                              maxLength: _storeIdLength,
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[A-Za-z0-9_-]'),
                                ),
                              ],
                              onChanged: (_) {
                                if (_storeIdError != null) {
                                  _validateStoreId();
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _siteUrlController,
                              decoration: const InputDecoration(
                                labelText: 'サイトURL',
                                hintText: 'https://example.com',
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'メールアドレス',
                                hintText: 'info@example.com',
                              ),
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: '電話番号',
                                hintText: '000-0000-0000',
                              ),
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _addressController,
                              decoration: const InputDecoration(
                                labelText: '住所',
                              ),
                              keyboardType: TextInputType.streetAddress,
                              minLines: 1,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _facebookController,
                              decoration: const InputDecoration(
                                labelText: 'Facebook',
                                hintText: 'https://www.facebook.com/...',
                              ),
                              keyboardType: TextInputType.url,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _instagramController,
                              decoration: const InputDecoration(
                                labelText: 'Instagram',
                                hintText: '@cocoshiba',
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _xController,
                              decoration: const InputDecoration(
                                labelText: 'X (旧Twitter)',
                                hintText: '@cocoshiba',
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _businessHoursController,
                              decoration: const InputDecoration(
                                labelText: '営業時間',
                                hintText: '例: 平日 10:00-20:00 / 土日 9:00-18:00',
                              ),
                              minLines: 1,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isContactSaving
                          ? null
                          : _showContactSaveConfirmation,
                      icon: _isContactSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.storefront_outlined),
                      label: Text(_isContactSaving ? '保存中...' : '店舗情報を保存'),
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
