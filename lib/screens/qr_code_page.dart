import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class QrCodePage extends StatelessWidget {
  const QrCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRコード')),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: FirebaseAuthService().watchCurrentUserProfile(),
        builder: (context, snapshot) {
          final name = (snapshot.data?['name'] as String?) ?? 'お客さま';
          return Center(
            child: Text(
              '$name さんのQRコード画面（準備中）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          );
        },
      ),
    );
  }
}
