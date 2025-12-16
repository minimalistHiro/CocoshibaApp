import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_chat_models.dart';
import 'notification_service.dart';
import 'dart:async';

class UserChatService {
  UserChatService({
    FirebaseFirestore? firestore,
    FirebaseAuth? firebaseAuth,
    NotificationService? notificationService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = firebaseAuth ?? FirebaseAuth.instance,
        _notificationService =
            notificationService ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService;

  Future<void> sendMessage({
    required String threadId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final sender = _auth.currentUser;
    if (sender == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインしていません',
      );
    }

    final senderProfile =
        await _firestore.collection('users').doc(sender.uid).get();
    final senderData = senderProfile.data();
    final senderName =
        (senderData?['name'] as String?)?.trim().isNotEmpty == true
            ? (senderData?['name'] as String)
            : (sender.displayName ?? sender.email ?? 'ユーザー');
    final senderPhoto =
        (senderData?['photoUrl'] as String?) ?? sender.photoURL ?? '';

    await _ensureThreadMetadata(threadId: threadId);

    final messagesRef = _firestore
        .collection('userChats')
        .doc(threadId)
        .collection('messages')
        .doc();

    await messagesRef.set({
      'text': trimmed,
      'senderId': sender.uid,
      'senderName': senderName,
      'senderPhotoUrl': senderPhoto,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('userChats').doc(threadId).set(
      {
        'lastMessage': trimmed,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': sender.uid,
        'lastMessageSenderName': senderName,
      },
      SetOptions(merge: true),
    );

    if (sender.uid == threadId) {
      // ユーザーから送信: 全オーナーへ通知
      await _notifyOwnersOfUserMessage(
        userId: threadId,
        text: trimmed,
      );
    } else {
      // オーナーから送信: ユーザーへ通知
      await _notificationService.createPersonalNotification(
        userId: threadId,
        title: 'チャットサポートから返信が届きました',
        body: trimmed,
        category: 'support',
      );
    }
  }

  Future<void> _ensureThreadMetadata({required String threadId}) async {
    final docRef = _firestore.collection('userChats').doc(threadId);
    final snapshot = await docRef.get();
    final hasUserName = snapshot.exists &&
        snapshot.data()?['userName'] != null &&
        (snapshot.data()?['userName'] as String).trim().isNotEmpty;

    if (!hasUserName) {
      final userDoc = await _firestore.collection('users').doc(threadId).get();
      final data = userDoc.data();

      final nameValue = data?['name'] as String?;
      final hasName = (nameValue?.trim().isNotEmpty ?? false);
      final userName = hasName ? nameValue : null;
      final userPhoto = (data?['photoUrl'] as String?) ?? '';

      final payload = <String, dynamic>{
        'userId': threadId,
        'userName': userName ?? 'ユーザー',
        'userPhotoUrl': userPhoto,
      };

      if (!snapshot.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['lastMessageAt'] = FieldValue.serverTimestamp();
      }

      await docRef.set(payload, SetOptions(merge: true));
    }
  }

  Stream<List<UserChatThread>> watchAllThreads() {
    return _firestore
        .collection('userChats')
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final updatedAt = data['lastMessageAt'] as Timestamp?;
        return UserChatThread(
          id: doc.id,
          userName: (data['userName'] as String?) ?? 'ユーザー',
          avatarUrl: (data['userPhotoUrl'] as String?) ?? '',
          lastMessage: (data['lastMessage'] as String?) ?? '',
          lastMessageSenderId: (data['lastMessageSenderId'] as String?) ?? '',
          updatedAt: updatedAt?.toDate(),
        );
      }).toList();
    });
  }

  Stream<DateTime?> watchLastReadAt({
    required String threadId,
    required String viewerId,
  }) {
    return _firestore
        .collection('userChats')
        .doc(threadId)
        .collection('readStatus')
        .doc(viewerId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();
      return (data?['lastReadAt'] as Timestamp?)?.toDate();
    });
  }

  Future<void> markThreadAsRead({
    required String threadId,
    required String viewerId,
  }) {
    return _firestore
        .collection('userChats')
        .doc(threadId)
        .collection('readStatus')
        .doc(viewerId)
        .set(
      {
        'lastReadAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Stream<Map<String, DateTime?>> watchReadStatusesForViewer(
      String viewerId) {
    return _firestore
        .collectionGroup('readStatus')
        .where(FieldPath.documentId, isEqualTo: viewerId)
        .snapshots()
        .map((snapshot) {
      final map = <String, DateTime?>{};
      for (final doc in snapshot.docs) {
        final parent = doc.reference.parent.parent;
        if (parent == null) continue;
        final threadId = parent.id;
        map[threadId] =
            (doc.data()['lastReadAt'] as Timestamp?)?.toDate();
      }
      return map;
    });
  }

  Stream<bool> watchHasUnreadForOwner(String viewerId) {
    final controller = StreamController<bool>.broadcast();
    List<UserChatThread> threads = const [];
    Map<String, DateTime?> readMap = const {};
    StreamSubscription<List<UserChatThread>>? threadSub;
    StreamSubscription<Map<String, DateTime?>>? readSub;

    void emit() {
      final hasUnread = threads.any((thread) {
        final lastRead = readMap[thread.id];
        return thread.updatedAt != null &&
            (lastRead == null || lastRead.isBefore(thread.updatedAt!)) &&
            thread.lastMessageSenderId != viewerId;
      });
      controller.add(hasUnread);
    }

    controller.onListen = () {
      threadSub = watchAllThreads().listen((value) {
        threads = value;
        emit();
      }, onError: controller.addError);

      readSub = watchReadStatusesForViewer(viewerId).listen((value) {
        readMap = value;
        emit();
      }, onError: controller.addError);
    };

    controller.onCancel = () async {
      await threadSub?.cancel();
      await readSub?.cancel();
    };

    return controller.stream;
  }

  Stream<List<UserChatMessage>> watchMessages(String threadId) {
    return _firestore
        .collection('userChats')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return UserChatMessage(
          id: doc.id,
          text: (data['text'] as String?) ?? '',
          senderId: (data['senderId'] as String?) ?? '',
          senderName: (data['senderName'] as String?) ?? '',
          senderPhotoUrl: (data['senderPhotoUrl'] as String?) ?? '',
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        );
      }).toList();
    });
  }

  Stream<Map<String, dynamic>?> threadMetaStream({required String threadId}) {
    return _firestore.collection('userChats').doc(threadId).snapshots().map(
      (snapshot) {
        return snapshot.data();
      },
    );
  }

  Future<void> _notifyOwnersOfUserMessage({
    required String userId,
    required String text,
  }) async {
    final ownersSnapshot = await _firestore
        .collection('users')
        .where('isOwner', isEqualTo: true)
        .get();
    final futures = ownersSnapshot.docs.map((doc) {
      return _notificationService.createPersonalNotification(
        userId: doc.id,
        title: 'ユーザーからチャットが届きました',
        body: text,
        category: 'support',
      );
    });
    await Future.wait(futures);
  }
}
