import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/firebase_auth_service.dart';

class QrCodePage extends StatefulWidget {
  const QrCodePage({super.key});

  @override
  State<QrCodePage> createState() => _QrCodePageState();
}

class _QrCodePageState extends State<QrCodePage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  String? _scanResult;
  bool _hasResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_hasResult) return;
    final barcode = capture.barcodes.firstWhere((code) => code.rawValue != null,
        orElse: () => capture.barcodes.first);
    final value = barcode.rawValue;
    if (value == null) return;

    setState(() {
      _scanResult = value;
      _hasResult = true;
    });
    _controller.stop();
  }

  Future<void> _scanAgain() async {
    setState(() {
      _scanResult = null;
      _hasResult = false;
    });
    await _controller.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRコード')),
      body: SafeArea(
        child: StreamBuilder<Map<String, dynamic>?>(
          stream: FirebaseAuthService().watchCurrentUserProfile(),
          builder: (context, snapshot) {
            final name = (snapshot.data?['name'] as String?) ?? 'お客さま';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$name さん、QRコードをスキャンしてください',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '画面中央の枠にコードを合わせると自動で読み取ります。',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Colors.black),
                        child: MobileScanner(
                          controller: _controller,
                          fit: BoxFit.cover,
                          onDetect: _handleDetection,
                          placeholderBuilder: (context, child) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                          errorBuilder: (context, error, child) {
                            String message = 'カメラを初期化できませんでした';
                            if (error is MobileScannerException) {
                              switch (error.errorCode) {
                                case MobileScannerErrorCode
                                      .controllerUninitialized:
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
                const SizedBox(height: 12),
                _ScannerControls(controller: _controller),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        elevation: 0,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _hasResult
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '読み取り結果',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      _scanResult ?? '',
                                      style:
                                          Theme.of(context).textTheme.bodyLarge,
                                    ),
                                  ],
                                )
                              : Text(
                                  '読み取り結果はここに表示されます。',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _hasResult ? _scanAgain : null,
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('もう一度スキャン'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ScannerControls extends StatelessWidget {
  const _ScannerControls({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: controller,
          builder: (context, state, _) {
            final torchState = state.torchState;
            final isOn = torchState == TorchState.on;
            final isAvailable = torchState != TorchState.unavailable;
            return IconButton.filledTonal(
              onPressed: isAvailable ? () => controller.toggleTorch() : null,
              icon: Icon(isOn ? Icons.flash_on : Icons.flash_off),
              tooltip: isOn ? 'ライトを消す' : 'ライトを点ける',
            );
          },
        ),
        const SizedBox(width: 16),
        ValueListenableBuilder<MobileScannerState>(
          valueListenable: controller,
          builder: (context, state, _) {
            final isBack = state.cameraDirection == CameraFacing.back;
            return IconButton.filledTonal(
              onPressed: () => controller.switchCamera(),
              icon: Icon(isBack ? Icons.camera_front : Icons.camera_rear),
              tooltip: isBack ? 'インカメラに切替' : 'バックカメラに切替',
            );
          },
        ),
      ],
    );
  }
}
