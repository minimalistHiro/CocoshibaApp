import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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
    required String gender,
    required String email,
    required String password,
    String? bio,
    Uint8List? profileImageBytes,
  }) async {
    final trimmedEmail = email.trim();
    final trimmedPassword = password.trim();

    final credential = await _auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: trimmedPassword,
    );

    final trimmedName = name.trim();
    final trimmedBio = bio?.trim();

    final user = credential.user;
    await user?.updateDisplayName(trimmedName);

    String? photoUrl;
    if (profileImageBytes != null && user != null) {
      photoUrl = await _uploadProfileImage(user.uid, profileImageBytes);
      await user.updatePhotoURL(photoUrl);
    }

    if (user != null) {
      final data = {
        'name': trimmedName,
        'email': trimmedEmail,
        'ageGroup': ageGroup,
        'area': area,
        'gender': gender,
        'signUpPlatform': _signUpPlatform(),
        'photoUrl': photoUrl,
        'isOwner': false,
        'isSubOwner': false,
        'points': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'emailVerified': false,
      };

      if (trimmedBio != null && trimmedBio.isNotEmpty) {
        data['bio'] = trimmedBio;
      }

      await _firestore.collection('users').doc(user.uid).set(data);
    }

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;
    if (user != null) {
      await _updateLastLogin(user);
    }

    return credential;
  }

  String _signUpPlatform() {
    return 'app';
  }

  Future<UserCredential> createAccountWithEmailPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final user = credential.user;
    if (user != null) {
      await _ensureUserDocument(user);
    }

    return credential;
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // ignore sign-out errors for GoogleSignIn to avoid blocking Firebase sign-out
    }
    await _auth.signOut();
  }

  Future<UserCredential> _signInWithGoogleWeb() async {
    final provider = GoogleAuthProvider();
    final credential = await _auth.signInWithPopup(provider);
    final user = credential.user;

    if (user != null) {
      await _ensureUserDocument(user);
    }
    return credential;
  }

  Future<UserCredential> _signInWithGoogleMobile() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'canceled',
        message: 'Googleログインがキャンセルされました',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      await _ensureUserDocument(
        user,
        displayName: googleUser.displayName,
        email: googleUser.email,
        photoUrl: googleUser.photoUrl,
      );
    }

    return userCredential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final userCredential =
        kIsWeb ? await _signInWithGoogleWeb() : await _signInWithGoogleMobile();

    final user = userCredential.user;
    if (user != null) {
      await _updateLastLogin(user);
    }

    return userCredential;
  }

  Future<UserCredential> signInWithApple() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      throw FirebaseAuthException(
        code: 'unsupported-platform',
        message: 'AppleログインはiOSのみ対応しています',
      );
    }

    final rawNonce = _generateNonce();
    final nonce = _sha256ofString(rawNonce);

    late final AuthorizationCredentialAppleID appleCredential;
    try {
      appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw FirebaseAuthException(
          code: 'canceled',
          message: 'Appleログインがキャンセルされました',
        );
      }
      throw FirebaseAuthException(
        code: 'apple-signin-failed',
        message: 'Appleログインに失敗しました',
      );
    }

    final identityToken = appleCredential.identityToken;
    if (identityToken == null) {
      throw FirebaseAuthException(
        code: 'missing-identity-token',
        message: 'Appleログインに失敗しました',
      );
    }

    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: identityToken,
      rawNonce: rawNonce,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);
    final user = userCredential.user;
    if (user != null) {
      final displayName = _composeAppleDisplayName(appleCredential);
      if (displayName.isNotEmpty &&
          (user.displayName ?? '').trim().isEmpty) {
        await user.updateDisplayName(displayName);
      }
      await _ensureUserDocument(
        user,
        displayName: displayName,
        email: appleCredential.email,
      );
      await _updateLastLogin(user);
    }

    return userCredential;
  }

  Future<void> updateProfile({
    required String name,
    required String ageGroup,
    required String area,
    String? gender,
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

    if (gender != null) {
      updateData['gender'] = gender;
    }

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

  Future<void> updateLoginInfo({
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

    final userEmail = user.email;
    if (userEmail == null || userEmail.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'メールアドレスが設定されていません',
      );
    }

    final trimmedNewPassword = newPassword?.trim();
    final credential = EmailAuthProvider.credential(
      email: userEmail,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);

    if (trimmedNewPassword != null && trimmedNewPassword.isNotEmpty) {
      await user.updatePassword(trimmedNewPassword);
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
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

  Future<void> _updateLastLogin(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set(
        {'lastLoginAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to update last login: $error');
      debugPrint('$stackTrace');
    }
  }

  Future<void> sendEmailVerificationCode({
    String? email,
    bool forceResend = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインしていません',
      );
    }

    final targetEmail = (email ?? user.email ?? '').trim();
    if (targetEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'メールアドレスが設定されていません',
      );
    }

    final callable = _functions.httpsCallable('requestEmailVerification');
    await callable.call({'email': targetEmail, 'forceResend': forceResend});
  }

  Future<void> verifyEmailCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'ログインしていません',
      );
    }

    final trimmedCode = code.trim();
    final callable = _functions.httpsCallable('verifyEmailCode');
    await callable.call({'code': trimmedCode});

    await user.reload();
  }

  Future<void> _ensureUserDocument(
    User user, {
    String? displayName,
    String? email,
    String? photoUrl,
  }) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snapshot = await docRef.get();

    final resolvedDisplayName =
        _firstNonEmpty([user.displayName, displayName]);
    final resolvedEmail = _firstNonEmpty([user.email, email]);
    final resolvedPhotoUrl = _firstNonEmpty([user.photoURL, photoUrl]);

    if (!snapshot.exists) {
      await docRef.set({
        'name': resolvedDisplayName.isNotEmpty ? resolvedDisplayName : '未設定',
        'email': resolvedEmail,
        'ageGroup': '',
        'area': '',
        'gender': '未回答',
        'signUpPlatform': _signUpPlatform(),
        'photoUrl': resolvedPhotoUrl.isNotEmpty ? resolvedPhotoUrl : null,
        'isOwner': false,
        'isSubOwner': false,
        'points': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLoginAt': FieldValue.serverTimestamp(),
        'emailVerified': user.emailVerified,
      });
      return;
    }

    final data = snapshot.data();
    final Map<String, dynamic> updates = {
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    final currentName = (data?['name'] as String?)?.trim() ?? '';
    final currentEmail = (data?['email'] as String?)?.trim() ?? '';
    final currentPhotoUrl = (data?['photoUrl'] as String?)?.trim() ?? '';
    final currentSignUpPlatform =
        (data?['signUpPlatform'] as String?)?.trim() ?? '';

    if (currentName.isEmpty && resolvedDisplayName.isNotEmpty) {
      updates['name'] = resolvedDisplayName;
    }
    if (currentEmail.isEmpty && resolvedEmail.isNotEmpty) {
      updates['email'] = resolvedEmail;
    }
    if (currentPhotoUrl.isEmpty && resolvedPhotoUrl.isNotEmpty) {
      updates['photoUrl'] = resolvedPhotoUrl;
    }
    if (currentSignUpPlatform.isEmpty) {
      updates['signUpPlatform'] = _signUpPlatform();
    }

    await docRef.set(updates, SetOptions(merge: true));
  }

  String _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return '';
  }

  String _composeAppleDisplayName(AuthorizationCredentialAppleID credential) {
    final parts = <String>[];
    final familyName = credential.familyName?.trim();
    final givenName = credential.givenName?.trim();
    if (familyName != null && familyName.isNotEmpty) {
      parts.add(familyName);
    }
    if (givenName != null && givenName.isNotEmpty) {
      parts.add(givenName);
    }
    return parts.join(' ').trim();
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }
}
