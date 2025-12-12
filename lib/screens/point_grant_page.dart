import 'package:characters/characters.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';
import '../services/owner_settings_service.dart';

class PointGrantPage extends StatefulWidget {
  const PointGrantPage({super.key, required this.targetUserId});

  final String targetUserId;

  @override
  State<PointGrantPage> createState() => _PointGrantPageState();
}

class _PointGrantPageState extends State<PointGrantPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final OwnerSettingsService _ownerSettingsService = OwnerSettingsService();

  bool _isLoading = true;
  bool _isProcessing = false;
  String? _loadError;
  Map<String, dynamic>? _targetUserData;
  int? _pointRate;
  String _amountText = '0';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final userDocFuture =
          _firestore.collection('users').doc(widget.targetUserId).get();
      final rateFuture = _ownerSettingsService.fetchPointRate();
      final userDoc = await userDocFuture;
      final rate = await rateFuture;

      if (!userDoc.exists) {
        throw StateError('user-not-found');
      }

      if (!mounted) return;
      setState(() {
        _targetUserData = userDoc.data();
        _pointRate = rate;
        _loadError = null;
      });
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.message == 'user-not-found'
            ? '対象のユーザーが見つかりませんでした'
            : '情報の取得に失敗しました';
        _targetUserData = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = '情報の取得に失敗しました';
        _targetUserData = null;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Map<String, dynamic>? get _userData => _targetUserData;

  String get _targetName =>
      (_userData?['name'] as String?)?.trim().isNotEmpty == true
          ? (_userData?['name'] as String)
          : 'お客さま';

  String? get _targetPhotoUrl {
    final uri = (_userData?['photoUrl'] as String?)?.trim();
    if (uri == null || uri.isEmpty) return null;
    return uri;
  }

  int get _amount => int.tryParse(_amountText) ?? 0;

  int get _grantPoints {
    final rate = _pointRate;
    if (rate == null || rate <= 0) return 0;
    return ((_amount * rate) / 100).floor();
  }

  String get _amountDisplay => '¥${_formatNumber(_amount)}';

  String get _grantPointsDisplay => '${_formatNumber(_grantPoints)} pt';

  bool get _hasValidRate => (_pointRate ?? 0) > 0;

  bool get _canSubmit {
    if (_isProcessing || _isLoading || _loadError != null) return false;
    if (_userData == null) return false;
    if (!_hasValidRate) return false;
    if (_amount <= 0 || _grantPoints <= 0) return false;
    return true;
  }

  void _appendDigit(String digit) {
    if (_amountText.length >= 9 || digit.isEmpty) return;
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

  String _formatNumber(int value) {
    final digits = value.abs().toString();
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

  Future<void> _confirmGrant() async {
    if (!_canSubmit) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ポイント付与の確認'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SummaryRow(label: '支払い金額', value: _amountDisplay),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: '還元率',
                  value: _pointRate == null ? '-' : '${_pointRate!} %',
                ),
                const SizedBox(height: 8),
                _SummaryRow(label: '付与ポイント', value: _grantPointsDisplay),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('付与する'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _grantPointsToUser();
  }

  Future<void> _grantPointsToUser() async {
    final grantPoints = _grantPoints;
    if (grantPoints <= 0) return;
    setState(() => _isProcessing = true);
    try {
      await _firestore.runTransaction((transaction) async {
        final userRef =
            _firestore.collection('users').doc(widget.targetUserId);
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) {
          throw StateError('user-not-found');
        }
        final currentPoints = _parsePoints(snapshot.data()?['points']);
        transaction.update(userRef, {
          'points': currentPoints + grantPoints,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        final historyRef = userRef.collection('pointHistories').doc();
        transaction.set(historyRef, {
          'description': 'ポイント付与',
          'points': grantPoints,
          'sourceAmount': _amount,
          'rate': _pointRate,
          'grantedBy': _authService.currentUser?.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'type': 'grant',
        });
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => PointGrantSuccessPage(points: grantPoints),
        ),
      );
    } on StateError catch (_) {
      if (!mounted) return;
      _showMessage('対象のユーザーが見つかりませんでした');
    } catch (_) {
      if (!mounted) return;
      _showMessage('ポイントの付与に失敗しました');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ポイント付与'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _loadError != null
                  ? _ErrorView(
                      message: _loadError!,
                      onRetry: _loadInitialData,
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _UserSummaryCard(
                          name: _targetName,
                          photoUrl: _targetPhotoUrl,
                          userId: widget.targetUserId,
                        ),
                        const SizedBox(height: 16),
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.percent),
                            title: const Text('還元率'),
                            subtitle: Text(
                              _hasValidRate
                                  ? '${_pointRate!} %'
                                  : '還元率が設定されていません',
                            ),
                            trailing: _hasValidRate
                                ? null
                                : Icon(Icons.error_outline,
                                    color: theme.colorScheme.error),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '支払い金額',
                                  style: theme.textTheme.labelMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _amountDisplay,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '付与ポイント',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    Text(
                                      _grantPointsDisplay,
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Column(
                            children: [
                              _KeypadRow(
                                children: [
                                  _KeypadButton(
                                    label: '1',
                                    onTap: () => _appendDigit('1'),
                                  ),
                                  _KeypadButton(
                                    label: '2',
                                    onTap: () => _appendDigit('2'),
                                  ),
                                  _KeypadButton(
                                    label: '3',
                                    onTap: () => _appendDigit('3'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _KeypadRow(
                                children: [
                                  _KeypadButton(
                                    label: '4',
                                    onTap: () => _appendDigit('4'),
                                  ),
                                  _KeypadButton(
                                    label: '5',
                                    onTap: () => _appendDigit('5'),
                                  ),
                                  _KeypadButton(
                                    label: '6',
                                    onTap: () => _appendDigit('6'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _KeypadRow(
                                children: [
                                  _KeypadButton(
                                    label: '7',
                                    onTap: () => _appendDigit('7'),
                                  ),
                                  _KeypadButton(
                                    label: '8',
                                    onTap: () => _appendDigit('8'),
                                  ),
                                  _KeypadButton(
                                    label: '9',
                                    onTap: () => _appendDigit('9'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _KeypadRow(
                                children: [
                                  _KeypadButton(
                                    label: 'C',
                                    onTap: _clearAmount,
                                    color: theme.colorScheme.errorContainer,
                                    foregroundColor:
                                        theme.colorScheme.onErrorContainer,
                                  ),
                                  _KeypadButton(
                                    label: '0',
                                    onTap: () => _appendDigit('0'),
                                  ),
                                  _KeypadButton(
                                    icon: Icons.backspace_outlined,
                                    onTap: _backspace,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _canSubmit ? _confirmGrant : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: _isProcessing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child:
                                        CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('ポイントを付与する'),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _UserSummaryCard extends StatelessWidget {
  const _UserSummaryCard({
    required this.name,
    required this.userId,
    this.photoUrl,
  });

  final String name;
  final String userId;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name.characters.first : '?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UID: $userId',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
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

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          value,
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            child: const Text('再読み込み'),
          ),
        ],
      ),
    );
  }
}

class PointGrantSuccessPage extends StatelessWidget {
  const PointGrantSuccessPage({super.key, required this.points});

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
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('付与完了'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.volunteer_activism_outlined,
                size: 88,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                '${_formattedPoints}ポイント付与しました',
                style:
                    theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'ホーム画面に戻って続けることができます。',
                style: theme.textTheme.bodyMedium,
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
