import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../models/achievement_model.dart';
import 'app_firebase.dart';

/// Logros conseguidos en `users/{uid}/achievements/{id}`: un documento por
/// logro con la fecha en que se consiguió. Las reglas existentes de
/// `users/{uid}` ya impiden leer o escribir los de otra cuenta.
class AchievementService {
  final FirebaseFirestore _db = AppFirebase.firestore;

  CollectionReference<Map<String, dynamic>> _ref(String uid) => _db
      .collection(AppConstants.collectionUsers)
      .doc(uid)
      .collection(AppConstants.subAchievements);

  /// Logros conseguidos. Un documento ilegible se omite.
  Future<List<UnlockedAchievement>> getUnlocked(String uid) async {
    final snap = await _ref(uid).get();
    final result = <UnlockedAchievement>[];
    for (final doc in snap.docs) {
      try {
        result.add(UnlockedAchievement.fromMap(doc.id, doc.data()));
      } catch (error) {
        debugPrint('Logro ${doc.id} ilegible, se omite: $error');
      }
    }
    return result;
  }

  /// Guarda varios logros en una sola escritura.
  Future<void> saveUnlocked(
    String uid,
    Iterable<UnlockedAchievement> achievements,
  ) async {
    final batch = _db.batch();
    for (final achievement in achievements) {
      batch.set(_ref(uid).doc(achievement.id), achievement.toMap());
    }
    await batch.commit();
  }
}
