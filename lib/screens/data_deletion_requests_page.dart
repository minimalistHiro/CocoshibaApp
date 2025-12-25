import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class DataDeletionRequestsPage extends StatefulWidget {
  const DataDeletionRequestsPage({super.key});

  @override
  State<DataDeletionRequestsPage> createState() =>
      _DataDeletionRequestsPageState();
}

class _DataDeletionRequestsPageState extends State<DataDeletionRequestsPage> {
  final Set<String> _deletingRequestIds = <String>{};

  Future<void> _confirmDelete(
    BuildContext context, {
    required String requestId,
    required String userId,
    required String displayName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ユーザー削除'),
        content: Text(
          '$displayName のユーザー情報と認証データを削除します。実行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('削除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteUser(context, requestId: requestId, userId: userId);
    }
  }

  Future<void> _deleteUser(
    BuildContext context, {
    required String requestId,
    required String userId,
  }) async {
    if (_deletingRequestIds.contains(requestId)) return;
    setState(() {
      _deletingRequestIds.add(requestId);
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('adminDeleteUser');
      await callable.call(<String, dynamic>{
        'userId': userId,
        'requestId': requestId,
      });
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('ユーザーを削除しました')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? '削除に失敗しました')),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('削除に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingRequestIds.remove(requestId);
        });
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$year/$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('data_deletion_requests')
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('データ削除申請者一覧'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text('削除申請はありません'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              final userId = (data['userId'] as String?) ?? '';
              final email = (data['email'] as String?) ?? '';
              final displayName = (data['displayName'] as String?) ?? '未設定';
              final createdAt = data['createdAt'] as Timestamp?;
              final isDeleting = _deletingRequestIds.contains(doc.id);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(displayName),
                  subtitle: Text(
                    '$email\n申請日時: ${_formatTimestamp(createdAt)}',
                  ),
                  isThreeLine: true,
                  trailing: isDeleting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: userId.isEmpty || isDeleting
                      ? null
                      : () => _confirmDelete(
                            context,
                            requestId: doc.id,
                            userId: userId,
                            displayName: displayName,
                          ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
