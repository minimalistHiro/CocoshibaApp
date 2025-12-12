import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class PointPaymentPage extends StatefulWidget {
  const PointPaymentPage({
    super.key,
    required this.storeId,
    this.scannedValue,
  });

  final String storeId;
  final String? scannedValue;

  @override
  State<PointPaymentPage> createState() => _PointPaymentPageState();
}

class _PointPaymentPageState extends State<PointPaymentPage> {
  static const String _insufficientPointsMessage = 'insufficient-points';

  final FirebaseAuthService _authService = FirebaseAuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _amountText = '0';
  bool _isLoadingPoints = true;
  bool _isProcessingPayment = false;
  int? _availablePoints;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadAvailablePoints();
  }

  Future<void> _loadAvailablePoints() async {
    if (mounted) {
      setState(() {
        _isLoadingPoints = true;
        _loadError = null;
      });
    }
    try {
      final points = await _authService.fetchCurrentUserPoints();
      if (!mounted) return;
      setState(() {
        _availablePoints = points;
        _loadError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = '保有ポイントを取得できませんでした';
        _availablePoints = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoadingPoints = false);
      }
    }
  }

  int get _amount => int.tryParse(_amountText) ?? 0;

  String get _amountDisplay => '${_formatNumber(_amount)} P';

  String _formatNumber(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  bool get _hasSufficientPoints {
    final available = _availablePoints;
    if (available == null) return true;
    return _amount <= available;
  }

  String? get _amountError {
    if (!_hasSufficientPoints) {
      return '保有ポイントが不足しています';
    }
    return null;
  }

  bool get _canConfirm {
    if (_isProcessingPayment || _isLoadingPoints) return false;
    if (_availablePoints == null && _loadError != null) return false;
    if (_amount <= 0) return false;
    return _hasSufficientPoints;
  }

  void _appendDigit(String digit) {
    if (_amountText.length >= 9) return;
    setState(() {
      if (_amountText == '0') {
        _amountText = digit;
      } else {
        _amountText += digit;
      }
    });
  }

  void _backspace() {
    setState(() {
      if (_amountText.length <= 1) {
        _amountText = '0';
      } else {
        _amountText = _amountText.substring(0, _amountText.length - 1);
      }
    });
  }

  void _clearAmount() {
    setState(() => _amountText = '0');
  }

  Future<void> _confirmPayment() async {
    if (!_hasSufficientPoints) {
      _showMessage('保有ポイントが不足しています');
      return;
    }

    final available = _availablePoints;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ポイント支払いの確認'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ConfirmationRow(
                  label: '支払いポイント',
                  value: _amountDisplay,
                ),
                if (available != null) ...[
                  const SizedBox(height: 8),
                  _ConfirmationRow(
                    label: '支払い後の残高',
                    value:
                        '${_formatNumber(((available - _amount).clamp(0, available)).toInt())} P',
                  ),
                ],
                if (available == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '保有ポイントを取得できませんでした。もう一度お試しください。',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: available == null
                    ? null
                    : () => Navigator.of(context).pop(true),
                child: const Text('支払う'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    await _processPayment();
  }

  Future<void> _processPayment() async {
    final user = _authService.currentUser;
    if (user == null) {
      _showMessage('ポイント支払いにはログインが必要です');
      return;
    }
    setState(() => _isProcessingPayment = true);

    try {
      await _firestore.runTransaction((transaction) async {
        final userRef = _firestore.collection('users').doc(user.uid);
        final snapshot = await transaction.get(userRef);
        final currentPoints = _parsePoints(snapshot.data()?['points']);
        if (currentPoints < _amount) {
          throw StateError(_insufficientPointsMessage);
        }
        transaction.update(userRef, {
          'points': currentPoints - _amount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final historyRef = userRef.collection('pointHistories').doc();
        transaction.set(historyRef, {
          'description': 'ポイント支払い',
          'points': -_amount,
          'storeId': widget.storeId,
          if (widget.scannedValue != null) 'scannedValue': widget.scannedValue,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PointPaymentSuccessPage(points: _amount),
        ),
      );
      return;
    } on StateError catch (error) {
      if (!mounted) return;
      if (error.message == _insufficientPointsMessage) {
        _showMessage('保有ポイントが不足しています');
      } else {
        _showMessage('ポイント支払いに失敗しました');
      }
    } catch (_) {
      if (!mounted) return;
      _showMessage('ポイント支払いに失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  int _parsePoints(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ポイント支払い'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StoreInfoBanner(
                storeId: widget.storeId,
                code: widget.scannedValue,
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                color: colorScheme.surfaceContainerHigh,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '支払いポイント',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _amountDisplay,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoadingPoints)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (!_isLoadingPoints && _availablePoints != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined),
                    title: const Text('保有ポイント'),
                    subtitle: Text('${_formatNumber(_availablePoints!)} P'),
                  ),
                ),
              if (_loadError != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: Text(_loadError!),
                    subtitle: const Text('通信環境を確認して再読み込みしてください'),
                    trailing: IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoadingPoints ? null : _loadAvailablePoints,
                    ),
                  ),
                ),
              if (_amountError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _amountError!,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colorScheme.error),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Column(
                  children: [
                    _KeypadRow(
                      children: [
                        _KeypadButton(label: '1', onTap: () => _appendDigit('1')),
                        _KeypadButton(label: '2', onTap: () => _appendDigit('2')),
                        _KeypadButton(label: '3', onTap: () => _appendDigit('3')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _KeypadRow(
                      children: [
                        _KeypadButton(label: '4', onTap: () => _appendDigit('4')),
                        _KeypadButton(label: '5', onTap: () => _appendDigit('5')),
                        _KeypadButton(label: '6', onTap: () => _appendDigit('6')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _KeypadRow(
                      children: [
                        _KeypadButton(label: '7', onTap: () => _appendDigit('7')),
                        _KeypadButton(label: '8', onTap: () => _appendDigit('8')),
                        _KeypadButton(label: '9', onTap: () => _appendDigit('9')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _KeypadRow(
                      children: [
                        _KeypadButton(
                          label: 'C',
                          onTap: _clearAmount,
                          color: colorScheme.errorContainer,
                          foregroundColor: colorScheme.onErrorContainer,
                        ),
                        _KeypadButton(label: '0', onTap: () => _appendDigit('0')),
                        _KeypadButton(
                          icon: Icons.backspace_outlined,
                          onTap: _backspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _canConfirm ? _confirmPayment : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: _isProcessingPayment
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('ポイントを支払う'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreInfoBanner extends StatelessWidget {
  const _StoreInfoBanner({required this.storeId, this.code});

  final String storeId;
  final String? code;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '店舗ID',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              storeId,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
            if (code != null && code != storeId) ...[
              const SizedBox(height: 8),
              Text(
                'スキャン値: $code',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KeypadRow extends StatelessWidget {
  const _KeypadRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    this.label,
    this.icon,
    required this.onTap,
    this.color,
    this.foregroundColor,
  }) : assert(label != null || icon != null);

  final String? label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
      child: icon != null
          ? Icon(icon, size: 28)
          : Text(label!, style: const TextStyle(fontSize: 28)),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class PointPaymentSuccessPage extends StatelessWidget {
  const PointPaymentSuccessPage({super.key, required this.points});

  final int points;

  String get _formattedPoints {
    final digits = points.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write(',');
      }
    }
    return '$bufferポイント';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('支払い完了'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 88,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'ポイントの$_formattedPoints支払いが完了しました',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'ご利用ありがとうございました。',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('戻る'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
