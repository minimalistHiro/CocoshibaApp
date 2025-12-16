import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_chat_models.dart';
import '../services/user_chat_service.dart';
import 'user_chat_thread_page.dart';

class UserChatSupportPage extends StatelessWidget {
  UserChatSupportPage({super.key});

  final UserChatService _chatService = UserChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(
          child: Text('ログインが必要です'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('ユーザーチャットサポート'),
      ),
      body: StreamBuilder<List<UserChatThread>>(
        stream: _chatService.watchAllThreads(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final threads = snapshot.data ?? [];
          if (threads.isEmpty) {
            return Center(
              child: Text(
                'ユーザーからのチャットはまだありません',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return StreamBuilder<DateTime?>(
                stream: _chatService.watchLastReadAt(
                  threadId: thread.id,
                  viewerId: currentUserId,
                ),
                builder: (context, readSnapshot) {
                  final readAt = readSnapshot.data;
                  final hasUnread = thread.updatedAt != null &&
                      (readAt == null || readAt.isBefore(thread.updatedAt!)) &&
                      thread.lastMessageSenderId != currentUserId;

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: thread.avatarUrl.isNotEmpty
                          ? NetworkImage(thread.avatarUrl)
                          : null,
                      child: thread.avatarUrl.isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(
                      thread.userName,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      thread.lastMessage.isEmpty
                          ? 'メッセージなし'
                          : thread.lastMessage,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: hasUnread
                        ? Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => UserChatThreadPage(
                            thread: thread,
                            isAdminView: true,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
