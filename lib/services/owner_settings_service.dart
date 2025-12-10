import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerSettingsService {
  OwnerSettingsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  static const String _collectionName = 'owner_settings';
  static const String _pointRateDocId = 'pointRate';

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
}
