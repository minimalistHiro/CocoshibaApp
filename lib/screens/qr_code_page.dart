import 'package:flutter/material.dart';

class QrCodePage extends StatelessWidget {
  const QrCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRコード')),
      body: Center(
        child: Text(
          'QRコード画面（準備中）',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
