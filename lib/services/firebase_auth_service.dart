import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  User? get currentUser => _auth.currentUser;

  Future<String?> fetchProfileImageUrl() async {
    final user = currentUser;
    if (user == null) return null;

    final authPhotoUrl = user.photoURL;
    if (authPhotoUrl != null && authPhotoUrl.isNotEmpty) {
      return authPhotoUrl;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final data = doc.data();
      final firestorePhotoUrl = data?['photoUrl'] as String?;
      if (firestorePhotoUrl != null && firestorePhotoUrl.isNotEmpty) {
        return firestorePhotoUrl;
      }
    } catch (e) {
      // Ignore and fallback to null so the UI can handle missing images gracefully.
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    return doc.data();
  }

  Stream<Map<String, dynamic>?> watchCurrentUserProfile() {
    final user = currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((snapshot) => snapshot.data());
  }

  Future<UserCredential> signUp({
    required String name,
    required String ageGroup,
    required String area,
    required String email,
    required String password,
    Uint8List? profileImageBytes,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final trimmedName = name.trim();
    final trimmedEmail = email.trim();

    final user = credential.user;
    await user?.updateDisplayName(trimmedName);

    String? photoUrl;
    if (profileImageBytes != null && user != null) {
      photoUrl = await _uploadProfileImage(user.uid, profileImageBytes);
      await user.updatePhotoURL(photoUrl);
    }

    if (user != null) {
      await _firestore.collection('users').doc(user.uid).set({
        'name': trimmedName,
        'email': trimmedEmail,
        'ageGroup': ageGroup,
        'area': area,
        'photoUrl': photoUrl,
        'points': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> updateProfile({
    required String name,
    required String ageGroup,
    required String area,
    String? bio,
    Uint8List? profileImageBytes,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインしていません',
      );
    }

    final trimmedName = name.trim();
    final trimmedBio = bio?.trim();

    await user.updateDisplayName(trimmedName);

    final Map<String, dynamic> updateData = {
      'name': trimmedName,
      'ageGroup': ageGroup,
      'area': area,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (trimmedBio != null && trimmedBio.isNotEmpty) {
      updateData['bio'] = trimmedBio;
    } else {
      updateData['bio'] = FieldValue.delete();
    }

    if (profileImageBytes != null) {
      final photoUrl = await _uploadProfileImage(user.uid, profileImageBytes);
      await user.updatePhotoURL(photoUrl);
      updateData['photoUrl'] = photoUrl;
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(updateData, SetOptions(merge: true));
  }

  /// Updates email and/or password.
  ///
  /// Returns `true` if an email verification is required before the email
  /// change takes effect.
  Future<bool> updateLoginInfo({
    required String email,
    required String currentPassword,
    String? newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインしていません',
      );
    }

    final trimmedEmail = email.trim();
    final trimmedNewPassword = newPassword?.trim();
    final credential = EmailAuthProvider.credential(
      email: user.email ?? trimmedEmail,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);

    final bool emailChanged =
        trimmedEmail.isNotEmpty && trimmedEmail != (user.email ?? '').trim();

    if (emailChanged) {
      await user.verifyBeforeUpdateEmail(trimmedEmail);
    }

    if (trimmedNewPassword != null && trimmedNewPassword.isNotEmpty) {
      await user.updatePassword(trimmedNewPassword);
    }

    final updateData = <String, dynamic>{
      'email': trimmedEmail,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('users')
        .doc(user.uid)
        .set(updateData, SetOptions(merge: true));

    return emailChanged;
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final uid = user.uid;
    final imageRef = _storage.ref().child('profile_images').child('$uid.jpg');
    try {
      await imageRef.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        rethrow;
      }
    }

    await _firestore.collection('users').doc(uid).delete();
    await user.delete();
    await _auth.signOut();
  }

  Future<int> fetchCurrentUserPoints() async {
    final user = currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインしていません',
      );
    }

    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    final pointsValue = data?['points'];

    if (pointsValue is int) {
      return pointsValue;
    } else if (pointsValue is num) {
      return pointsValue.toInt();
    }

    return 0;
  }

  Future<String> _uploadProfileImage(String uid, Uint8List data) async {
    final ref = _storage.ref().child('profile_images').child('$uid.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(data, metadata);
    return ref.getDownloadURL();
  }
}
