import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/firebase_auth_service.dart';
import '../services/owner_settings_service.dart';
import 'point_earned_page.dart';
import 'point_grant_page.dart';
import 'point_payment_page.dart';

class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuthService _authService = FirebaseAuthService();
  final OwnerSettingsService _ownerSettingsService = OwnerSettingsService();
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final TextEditingController _manualInputController = TextEditingController();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _roleSubscription;

  String? _scanResult;
  String? _ownerStoreId;
  bool _canGrantPoints = false;

  @override
  void dispose() {
    _roleSubscription?.cancel();
    _controller.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _listenOwnerRole();
    _loadOwnerStoreId();
  }

  void _listenOwnerRole() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      setState(() => _canGrantPoints = false);
      return;
    }
    _roleSubscription?.cancel();
    _roleSubscription = _firestore.collection('users').doc(uid).snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        final data = snapshot.data();
        final isOwner = data?['isOwner'] == true;
        setState(() => _canGrantPoints = isOwner);
      },
      onError: (_) {
        if (!mounted) return;
        setState(() => _canGrantPoints = false);
      },
    );
  }

  Future<void> _loadOwnerStoreId() async {
    try {
      final info = await _ownerSettingsService.fetchContactInfo();
      final storeId = info?.storeId.trim();
      if (!mounted) return;
      setState(() {
        _ownerStoreId =
            (storeId != null && storeId.isNotEmpty) ? storeId : null;
      });
      _maybeOpenPointPayment(_scanResult);
    } catch (_) {
      // Ignore errors – the scanner will continue to work without auto-navigation.
    }
  }

  void _handleDetection(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstWhere((code) => code.rawValue != null,
        orElse: () => capture.barcodes.first);
    final value = barcode.rawValue?.trim();
    if (value == null || value == _scanResult) return;

    setState(() {
      _scanResult = value;
    });
    _handleScannedValue(value);
  }

  void _applyManualInput() {
    final manualValue = _manualInputController.text.trim();
    if (manualValue.isEmpty) return;
    setState(() {
      _scanResult = manualValue;
    });
    _handleScannedValue(manualValue);
  }

  void _handleScannedValue(String value) {
    if (_matchesOwnerStoreId(value)) {
      _openPointPayment(value);
    } else if (_canGrantPoints) {
      _openPointGrant(value);
    } else {
      _showGrantNotAllowedMessage();
    }
  }

  bool get _hasResult => (_scanResult?.isNotEmpty ?? false);

  bool _matchesOwnerStoreId(String value) {
    final target = _ownerStoreId;
    if (target == null || target.isEmpty) return false;
    return value.trim() == target;
  }

  void _maybeOpenPointPayment(String? code) {
    if (code == null || code.isEmpty) return;
    if (_matchesOwnerStoreId(code)) {
      _openPointPayment(code);
    }
  }

  void _openPointPayment(String code) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointPaymentPage(
          storeId: _ownerStoreId ?? code,
          scannedValue: code,
        ),
      ),
    );
  }

  void _openPointGrant(String userId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointGrantPage(targetUserId: userId),
      ),
    );
  }

  void _showGrantNotAllowedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ポイント付与はオーナーのみ利用できます')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('QRコード')),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: TabBarView(
                  children: [
                    _ScanTab(
                      controller: _controller,
                      manualInputController: _manualInputController,
                      hasResult: _hasResult,
                      scanResult: _scanResult,
                      onDetect: _handleDetection,
                      onManualApply: _applyManualInput,
                    ),
                    _MyQrTab(authService: _authService),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Material(
                  elevation: 4,
                  color: colorScheme.surface,
                  child: TabBar(
                    indicatorColor: colorScheme.primary,
                    labelColor: colorScheme.primary,
                    unselectedLabelColor:
                        colorScheme.onSurface.withOpacity(0.6),
                    tabs: const [
                      Tab(
                        icon: Icon(Icons.qr_code_scanner),
                        text: 'スキャン',
                      ),
                      Tab(
                        icon: Icon(Icons.qr_code_2),
                        text: 'QRコード',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanTab extends StatelessWidget {
  const _ScanTab({
    required this.controller,
    required this.manualInputController,
    required this.hasResult,
    required this.scanResult,
    required this.onDetect,
    required this.onManualApply,
  });

  final MobileScannerController controller;
  final TextEditingController manualInputController;
  final bool hasResult;
  final String? scanResult;
  final void Function(BarcodeCapture capture) onDetect;
  final VoidCallback onManualApply;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: MobileScanner(
                  controller: controller,
                  fit: BoxFit.cover,
                  onDetect: onDetect,
                  placeholderBuilder: (context, child) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  errorBuilder: (context, error, child) {
                    String message = 'カメラを初期化できませんでした';
                    if (error is MobileScannerException) {
                      switch (error.errorCode) {
                        case MobileScannerErrorCode.controllerUninitialized:
                          message = 'カメラの初期化が完了していません。しばらくお待ちください。';
                          break;
                        case MobileScannerErrorCode.permissionDenied:
                          message = 'カメラの権限が必要です。設定から許可してください。';
                          break;
                        default:
                          message = 'エラー: ${error.errorCode.name}';
                      }
                    }
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          message,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: manualInputController,
            decoration: InputDecoration(
              labelText: 'コードを手入力',
              hintText: 'テキストを入力してください',
              suffixIcon: IconButton(
                onPressed: onManualApply,
                icon: const Icon(Icons.check),
                tooltip: '入力内容を反映',
              ),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onManualApply(),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: hasResult
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '読み取り結果',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          scanResult ?? '',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    )
                  : Text(
                      '読み取り結果はここに表示されます。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _MyQrTab extends StatefulWidget {
  const _MyQrTab({required this.authService});

  final FirebaseAuthService authService;

  @override
  State<_MyQrTab> createState() => _MyQrTabState();
}

class _MyQrTabState extends State<_MyQrTab> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _historySubscription;
  String? _listeningUid;
  String? _lastHandledHistoryId;
  bool _capturedInitialSnapshot = false;

  @override
  void initState() {
    super.initState();
    _ensureHistoryListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureHistoryListener();
  }

  @override
  void didUpdateWidget(covariant _MyQrTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authService != widget.authService) {
      _ensureHistoryListener(forceRestart: true);
    }
  }

  void _ensureHistoryListener({bool forceRestart = false}) {
    final uid = widget.authService.currentUser?.uid;
    if (uid == null) {
      _historySubscription?.cancel();
      _historySubscription = null;
      _listeningUid = null;
      _lastHandledHistoryId = null;
      _capturedInitialSnapshot = false;
      return;
    }
    if (!forceRestart && _historySubscription != null && _listeningUid == uid) {
      return;
    }
    _historySubscription?.cancel();
    _listeningUid = uid;
    _lastHandledHistoryId = null;
    _capturedInitialSnapshot = false;
    _historySubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('pointHistories')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      if (!_capturedInitialSnapshot) {
        _capturedInitialSnapshot = true;
        _lastHandledHistoryId =
            snapshot.docs.isNotEmpty ? snapshot.docs.first.id : null;
        return;
      }
      if (snapshot.docs.isEmpty) {
        _lastHandledHistoryId = null;
        return;
      }
      final doc = snapshot.docs.first;
      if (doc.id == _lastHandledHistoryId) {
        return;
      }
      _lastHandledHistoryId = doc.id;
      final points = _parsePoints(doc.data()['points']);
      if (points > 0) {
        _openPointEarned(points);
      }
    });
  }

  int _parsePoints(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  void _openPointEarned(int points) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PointEarnedPage(points: points),
      ),
    );
  }

  @override
  void dispose() {
    _historySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: widget.authService.watchCurrentUserProfile(),
      builder: (context, _) {
        final uid = widget.authService.currentUser?.uid;
        if (uid == null) {
          return Center(
            child: Text(
              'QRコードを表示するにはログインしてください',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'あなたのQRコード',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: uid,
                  version: QrVersions.auto,
                  size: 240,
                  backgroundColor: Colors.white,
                  embeddedImage: const AssetImage(
                    'assets/images/ココシバアプリアイコン.png',
                  ),
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(44, 44),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                'UID: $uid',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}
