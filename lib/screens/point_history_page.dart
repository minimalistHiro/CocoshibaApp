import 'package:flutter/material.dart';

import '../models/point_history.dart';
import '../services/firebase_auth_service.dart';
import '../services/point_history_service.dart';

class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({super.key});

  @override
  State<PointHistoryPage> createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage> {
  final FirebaseAuthService _authService = FirebaseAuthService();
  final PointHistoryService _pointHistoryService = PointHistoryService();
  late final String? _userId;
  Stream<List<PointHistory>>? _historyStream;

  @override
  void initState() {
    super.initState();
    _userId = _authService.currentUser?.uid;
    if (_userId != null) {
      _historyStream = _pointHistoryService.watchRecentHistories(
        userId: _userId!,
        limit: 50,
      );
    }
  }

  String _formatDate(DateTime? dateTime) {
    if (dateTime == null) {
      return '日時不明';
    }
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}/$month/$day $hour:$minute';
  }

  String _formatPoints(int points) {
    final buffer = StringBuffer(points >= 0 ? '+' : '-');
    buffer.write(points.abs());
    buffer.write(' pt');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ポイント履歴'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _userId == null
              ? _PointHistoryMessage(
                  icon: Icons.lock_outline,
                  message: 'ポイント履歴を表示するにはログインが必要です',
                )
              : StreamBuilder<List<PointHistory>>(
                  stream: _historyStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _PointHistoryMessage(
                        icon: Icons.error_outline,
                        message: 'ポイント履歴の取得に失敗しました',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final histories = snapshot.data ?? const <PointHistory>[];
                    if (histories.isEmpty) {
                      return _PointHistoryMessage(
                        icon: Icons.history,
                        message: 'まだポイント履歴はありません',
                      );
                    }

                    return ListView.separated(
                      itemCount: histories.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, thickness: 0.5),
                      itemBuilder: (context, index) {
                        final history = histories[index];
                        final color = history.isPositive
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: color.withOpacity(0.12),
                            child: Icon(
                              history.isPositive
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              color: color,
                            ),
                          ),
                          title: Text(
                            history.description,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          subtitle: Text(
                            _formatDate(history.createdAt),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade600,
                                    ),
                          ),
                          trailing: Text(
                            _formatPoints(history.points),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _PointHistoryMessage extends StatelessWidget {
  const _PointHistoryMessage({
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
