import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/home_page_content.dart';

class HomePageContentService {
  HomePageContentService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _contentsRef =>
      _firestore.collection('home_pages');

  Stream<List<HomePageContent>> watchContents() {
    return _contentsRef
        .orderBy('displayOrder')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(HomePageContent.fromDocument)
              .toList(growable: false),
        );
  }

  Future<void> createContent({
    required String title,
    required String body,
    required HomePageGenre genre,
    required List<XFile> images,
    int? price,
    DateTime? eventDate,
    String? startTimeLabel,
    String? endTimeLabel,
  }) async {
    final docRef = _contentsRef.doc();
    final uploadedImageUrls = await _uploadImages(docRef.id, images);
    await docRef.set({
      'title': title,
      'body': body,
      'genre': genre.firestoreValue,
      'imageUrls': uploadedImageUrls,
      'displayOrder': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'price': genre == HomePageGenre.sales ? price : null,
      'eventDate': genre == HomePageGenre.event && eventDate != null
          ? Timestamp.fromDate(eventDate)
          : null,
      'startTime':
          genre == HomePageGenre.event ? startTimeLabel : null,
      'endTime': genre == HomePageGenre.event ? endTimeLabel : null,
    });
  }

  Future<void> updateContent({
    required String contentId,
    required String title,
    required String body,
    required HomePageGenre genre,
    required List<String> retainedImageUrls,
    required List<XFile> newImages,
    required List<String> previousImageUrls,
    int? price,
    DateTime? eventDate,
    String? startTimeLabel,
    String? endTimeLabel,
  }) async {
    final docRef = _contentsRef.doc(contentId);
    final newImageUrls = await _uploadImages(contentId, newImages);
    final mergedImageUrls = [
      ...retainedImageUrls,
      ...newImageUrls,
    ];

    await docRef.update({
      'title': title,
      'body': body,
      'genre': genre.firestoreValue,
      'imageUrls': mergedImageUrls,
      'updatedAt': FieldValue.serverTimestamp(),
      'price': genre == HomePageGenre.sales ? price : null,
      'eventDate': genre == HomePageGenre.event && eventDate != null
          ? Timestamp.fromDate(eventDate)
          : null,
      'startTime':
          genre == HomePageGenre.event ? startTimeLabel : null,
      'endTime': genre == HomePageGenre.event ? endTimeLabel : null,
    });

    final removedUrls = previousImageUrls
        .where((url) => !retainedImageUrls.contains(url))
        .toList(growable: false);
    for (final url in removedUrls) {
      await _removeImageFromStorage(url);
    }
  }

  Future<void> deleteContent({
    required String contentId,
    List<String>? imageUrls,
  }) async {
    await _contentsRef.doc(contentId).delete();
    if (imageUrls == null) return;
    for (final url in imageUrls) {
      await _removeImageFromStorage(url);
    }
  }

  Future<List<String>> _uploadImages(
    String contentId,
    List<XFile> files,
  ) async {
    if (files.isEmpty) return const [];
    final uploads = <String>[];
    for (final file in files) {
      final url = await _uploadImage(contentId, file);
      if (url != null) {
        uploads.add(url);
      }
    }
    return uploads;
  }

  Future<String?> _uploadImage(String contentId, XFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child('home_pages/$contentId/$filename');
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
      // Silently ignore cleanup failures.
    }
  }
}
