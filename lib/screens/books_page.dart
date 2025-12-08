import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class BooksPage extends StatelessWidget {
  const BooksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FirebaseAuthService().watchCurrentUserProfile(),
      builder: (context, snapshot) {
        final name = (snapshot.data?['name'] as String?) ?? 'お客さま';
        return Center(
          child: Text(
            '$name さんの本の画面（準備中）',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        );
      },
    );
  }
}
