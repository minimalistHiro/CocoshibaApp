import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/owner_contact_info.dart';

class OwnerSettingsService {
  OwnerSettingsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collectionName = 'owner_settings';
  static const String _pointRateDocId = 'pointRate';
  static const String _contactInfoDocId = 'contactInfo';

  Future<int?> fetchPointRate() async {
    final doc =
        await _firestore.collection(_collectionName).doc(_pointRateDocId).get();
    final data = doc.data();
    final rate = data?['rate'];
    if (rate is int) return rate;
    if (rate is num) return rate.toInt();
    return null;
  }

  Future<void> savePointRate(int rate) async {
    await _firestore.collection(_collectionName).doc(_pointRateDocId).set({
      'rate': rate,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<OwnerContactInfo?> fetchContactInfo() async {
    final doc = await _firestore
        .collection(_collectionName)
        .doc(_contactInfoDocId)
        .get();
    final data = doc.data();
    if (data == null) return null;
    return OwnerContactInfo.fromMap(data);
  }

  Future<void> saveContactInfo(OwnerContactInfo info) async {
    await _firestore.collection(_collectionName).doc(_contactInfoDocId).set({
      ...info.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
