import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<UserCredential> signUp({
    required String name,
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
        'photoUrl': photoUrl,
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

  Future<String> _uploadProfileImage(String uid, Uint8List data) async {
    final ref = _storage.ref().child('profile_images').child('$uid.jpg');
    final metadata = SettableMetadata(contentType: 'image/jpeg');
    await ref.putData(data, metadata);
    return ref.getDownloadURL();
  }
}
