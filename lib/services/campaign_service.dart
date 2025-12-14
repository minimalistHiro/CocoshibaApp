import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/campaign.dart';

class CampaignService {
  CampaignService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _campaignsRef =>
      _firestore.collection('campaigns');

  Stream<List<Campaign>> watchCampaigns() {
    return _campaignsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(Campaign.fromDocument)
              .toList(growable: false),
        );
  }

  Stream<List<Campaign>> watchActiveCampaigns() {
    return watchCampaigns().map((campaigns) {
      final now = DateTime.now();
      return campaigns.where((campaign) {
        final start = campaign.displayStart;
        final end = campaign.displayEnd;
        if (start == null || end == null) return false;
        final afterStart = !now.isBefore(start);
        final beforeEnd = !now.isAfter(end);
        return afterStart && beforeEnd;
      }).toList(growable: false);
    });
  }

  Future<String> createCampaign({
    required String title,
    required String body,
    required DateTime displayStart,
    required DateTime displayEnd,
    required DateTime eventStart,
    required DateTime eventEnd,
    XFile? image,
  }) async {
    final docRef = _campaignsRef.doc();
    final imageUrl = image != null ? await _uploadImage(docRef.id, image) : null;

    await docRef.set({
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'displayStart': Timestamp.fromDate(displayStart),
      'displayEnd': Timestamp.fromDate(displayEnd),
      'eventStart': Timestamp.fromDate(eventStart),
      'eventEnd': Timestamp.fromDate(eventEnd),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  Future<void> updateCampaign({
    required String campaignId,
    required String title,
    required String body,
    required DateTime displayStart,
    required DateTime displayEnd,
    required DateTime eventStart,
    required DateTime eventEnd,
    String? currentImageUrl,
    XFile? newImage,
    bool removeImage = false,
  }) async {
    final docRef = _campaignsRef.doc(campaignId);
    String? imageUrl = removeImage ? null : currentImageUrl;

    if (newImage != null) {
      final uploadedUrl = await _uploadImage(campaignId, newImage);
      if (uploadedUrl != null) {
        imageUrl = uploadedUrl;
        if (currentImageUrl != null && currentImageUrl != uploadedUrl) {
          await _deleteImageFromStorage(currentImageUrl);
        }
      }
    } else if (removeImage && currentImageUrl != null) {
      await _deleteImageFromStorage(currentImageUrl);
    }

    await docRef.update({
      'title': title,
      'body': body,
      'imageUrl': imageUrl,
      'displayStart': Timestamp.fromDate(displayStart),
      'displayEnd': Timestamp.fromDate(displayEnd),
      'eventStart': Timestamp.fromDate(eventStart),
      'eventEnd': Timestamp.fromDate(eventEnd),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<String?> _uploadImage(String campaignId, XFile file) async {
    try {
      final Uint8List bytes = await file.readAsBytes();
      final filename = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = _storage.ref().child('campaigns/$campaignId/$filename');
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      return uploadTask.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteImageFromStorage(String imageUrl) async {
    try {
      await _storage.refFromURL(imageUrl).delete();
    } catch (_) {
      // Ignore cleanup errors to avoid blocking updates.
    }
  }
}
