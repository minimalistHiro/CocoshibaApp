import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_chat_models.dart';
import '../services/user_chat_service.dart';

class UserChatThreadPage extends StatefulWidget {
  const UserChatThreadPage({
    super.key,
    required this.thread,
    this.isAdminView = false,
    this.title,
  });

  final UserChatThread thread;
  final bool isAdminView;
  final String? title;

  @override
  State<UserChatThreadPage> createState() => _UserChatThreadPageState();
}

class _UserChatThreadPageState extends State<UserChatThreadPage> {
  final UserChatService _chatService = UserChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _controller = TextEditingController();
  bool _isSending = false;
  String? _lastSeenMessageId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    try {
      await _chatService.sendMessage(
        threadId: widget.thread.id,
        text: text,
      );
      _controller.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('メッセージの送信に失敗しました')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _auth.currentUser?.uid;
    final appBarTitle = widget.title ??
        (widget.isAdminView ? widget.thread.userName : 'チャットサポート');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.thread.avatarUrl.isNotEmpty
                  ? NetworkImage(widget.thread.avatarUrl)
                  : null,
              child: widget.thread.avatarUrl.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                appBarTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<UserChatMessage>>(
              stream: _chatService.watchMessages(widget.thread.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isNotEmpty) {
                  final latestId = messages.last.id;
                  final userId = currentUserId;
                  if (userId != null && latestId != _lastSeenMessageId) {
                    _lastSeenMessageId = latestId;
                    unawaited(
                      _chatService.markThreadAsRead(
                        threadId: widget.thread.id,
                        viewerId: userId,
                      ),
                    );
                  }
                }
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'まだメッセージがありません',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMine = message.senderId == currentUserId;
                    final alignment =
                        isMine ? Alignment.centerRight : Alignment.centerLeft;
                    final bubbleColor = isMine
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceVariant;
                    final textColor = isMine
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).colorScheme.onSurfaceVariant;

                    return Align(
                      alignment: alignment,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.78,
                        ),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMine)
                              Text(
                                message.senderName,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            Text(
                              message.text,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: textColor),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            isSending: _isSending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.isSending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: '返信を入力...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                minLines: 1,
                maxLines: 4,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
