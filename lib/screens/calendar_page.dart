import 'package:flutter/material.dart';

import '../services/firebase_auth_service.dart';

class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: FirebaseAuthService().watchCurrentUserProfile(),
      builder: (context, snapshot) {
        final name = (snapshot.data?['name'] as String?) ?? 'お客さま';
        return _CenteredPlaceholder(text: '$name さんのカレンダー（準備中）');
      },
    );
  }
}

class _CenteredPlaceholder extends StatelessWidget {
  const _CenteredPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
