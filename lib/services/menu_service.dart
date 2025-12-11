import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/menu_item.dart';

class MenuService {
  MenuService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _menusRef =>
      _firestore.collection('menus');

  Stream<List<MenuItem>> watchMenus() {
    return _menusRef.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) =>
              snapshot.docs.map(MenuItem.fromDocument).toList(growable: false),
        );
  }

  Future<void> createMenu({
    required String name,
    required int price,
    required MenuCategory category,
    XFile? image,
  }) async {
    final docRef = _menusRef.doc();
    final String? imageUrl =
        image != null ? await _uploadMenuImage(docRef.id, image) : null;

    await docRef.set({
      'name': name,
      'price': price,
      'category': category.firestoreValue,
      'imageUrl': imageUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMenu({
    required String menuId,
    required String name,
    required int price,
    required MenuCategory category,
    XFile? newImage,
    String? previousImageUrl,
  }) async {
    String? imageUrl = previousImageUrl;

    if (newImage != null) {
      imageUrl = await _uploadMenuImage(menuId, newImage);
      if (previousImageUrl != null) {
        _removeImageFromStorage(previousImageUrl);
      }
    }

    await _menusRef.doc(menuId).update({
      'name': name,
      'price': price,
      'category': category.firestoreValue,
      'imageUrl': imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMenu({
    required String menuId,
    String? imageUrl,
  }) async {
    await _menusRef.doc(menuId).delete();
    if (imageUrl != null) {
      _removeImageFromStorage(imageUrl);
    }
  }

  Future<String?> _uploadMenuImage(String menuId, XFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child('menu_images/$menuId/$filename');
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return uploadTask.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _removeImageFromStorage(String imageUrl) async {
    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (_) {
      // ignore cleanup failures to avoid interrupting UX
    }
  }
}
