import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/firebase_auth_service.dart';
import '../services/owner_settings_service.dart';
import 'point_payment_page.dart';

class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final OwnerSettingsService _ownerSettingsService = OwnerSettingsService();
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );
  final TextEditingController _manualInputController = TextEditingController();

  String? _scanResult;
  String? _ownerStoreId;

  @override
  void dispose() {
    _controller.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOwnerStoreId();
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

    final shouldOpenPayment = _matchesOwnerStoreId(value);
    setState(() {
      _scanResult = value;
    });
    if (shouldOpenPayment) {
      _openPointPayment(value);
    }
  }

  void _applyManualInput() {
    final manualValue = _manualInputController.text.trim();
    if (manualValue.isEmpty) return;
    final shouldOpenPayment = _matchesOwnerStoreId(manualValue);
    setState(() {
      _scanResult = manualValue;
    });
    if (shouldOpenPayment) {
      _openPointPayment(manualValue);
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

class _MyQrTab extends StatelessWidget {
  const _MyQrTab({required this.authService});

  final FirebaseAuthService authService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: authService.watchCurrentUserProfile(),
      builder: (context, _) {
        final uid = authService.currentUser?.uid;
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
