import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/nutrition_catalog.dart';
import '../models/nutrition_model.dart';
import 'app_firebase.dart';

/// Datos de alimentación del usuario en Firestore. Todo cuelga de
/// `users/{uid}`, igual que el resto de la app, así que las reglas de
/// seguridad existentes impiden leer o escribir datos de otra cuenta:
///
/// - `users/{uid}/nutrition_plans/{planId}`: planes (comidas incrustadas).
/// - `users/{uid}/nutrition_days/{yyyy-MM-dd}`: consumo real de cada día.
class NutritionService {
  final FirebaseFirestore _db = AppFirebase.firestore;

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(AppConstants.collectionUsers).doc(uid);

  CollectionReference<Map<String, dynamic>> _plansRef(String uid) =>
      _userRef(uid).collection(AppConstants.subNutritionPlans);

  CollectionReference<Map<String, dynamic>> _daysRef(String uid) =>
      _userRef(uid).collection(AppConstants.subNutritionDays);

  String get newDocId => _db.collection('_generator').doc().id;

  /// Planes del usuario, del más antiguo al más nuevo.
  ///
  /// Se leen todos los documentos sin `orderBy` (que excluiría los que no
  /// tengan `createdAt`) y se ordenan en memoria. Los planes a los que les
  /// falten campos (por ejemplo, borrados a mano en la consola) se reparan y
  /// se vuelven a guardar; un documento ilegible se omite.
  Future<List<NutritionPlan>> getPlans(String uid) async {
    final snap = await _plansRef(uid).get();
    final plans = <NutritionPlan>[];
    for (final doc in snap.docs) {
      try {
        final (:plan, :repaired) = restorePlan(doc.id, doc.data());
        plans.add(plan);
        if (repaired) {
          // Reparación en segundo plano: si falla, se reintenta en la
          // próxima carga.
          savePlan(uid, plan).catchError((Object error) {
            debugPrint('No se pudo reparar el plan ${doc.id}: $error');
          });
        }
      } catch (error) {
        debugPrint('Plan ${doc.id} ilegible, se omite: $error');
      }
    }
    plans.sort((a, b) {
      final first = a.createdAt ?? DateTime(2000);
      final second = b.createdAt ?? DateTime(2000);
      return first.compareTo(second);
    });
    return plans;
  }

  /// Campos que todo plan guardado debe tener.
  static const List<String> planFields = [
    'name',
    'goal',
    'calories',
    'protein',
    'carbs',
    'fat',
    'meals',
    'active',
    'templateId',
    'createdAt',
    'updatedAt',
  ];

  /// Lee un plan y restaura lo que falte. Si el plan viene de una plantilla
  /// (por `templateId` o por su nombre), los datos borrados se recuperan de
  /// ella; si no, se usan valores por defecto. Una lista de comidas vacía
  /// se respeta (el usuario pudo vaciarla); solo se restaura si el campo
  /// `meals` no existe.
  @visibleForTesting
  static ({NutritionPlan plan, bool repaired}) restorePlan(
    String id,
    Map<String, dynamic> data,
  ) {
    final missing = {
      for (final field in planFields)
        if (!data.containsKey(field)) field,
    };
    final plan = NutritionPlan.fromMap(id, data);
    if (missing.isEmpty) return (plan: plan, repaired: false);

    NutritionTemplate? template = NutritionTemplate.byId(plan.templateId);
    if (template == null) {
      for (final candidate in NutritionTemplate.all) {
        if (candidate.name == plan.name) template = candidate;
      }
    }
    if (template == null) {
      return (
        plan: plan.copyWith(name: plan.name.isEmpty ? 'Mi plan' : null),
        repaired: true,
      );
    }
    final base = template.toPlan(id: id);
    double? restore(String field, double value) =>
        missing.contains(field) ? value : null;
    return (
      plan: plan.copyWith(
        name: missing.contains('name') || plan.name.isEmpty ? base.name : null,
        goal: missing.contains('goal') ? base.goal : null,
        calories: restore('calories', base.calories),
        protein: restore('protein', base.protein),
        carbs: restore('carbs', base.carbs),
        fat: restore('fat', base.fat),
        meals: missing.contains('meals') ? base.meals : null,
        templateId: template.id,
      ),
      repaired: true,
    );
  }

  Future<void> savePlan(String uid, NutritionPlan plan) async {
    await _plansRef(uid).doc(plan.id).set(plan.toMap());
  }

  Future<void> deletePlan(String uid, String planId) async {
    await _plansRef(uid).doc(planId).delete();
  }

  /// Marca [planId] como activo y desactiva el resto en una sola escritura:
  /// nunca quedan dos planes activos.
  Future<void> setActivePlan(
    String uid,
    String? planId,
    Iterable<String> allPlanIds,
  ) async {
    final batch = _db.batch();
    // `set` con merge (no `update`): no falla si un plan se borró a mano.
    for (final id in allPlanIds) {
      batch.set(_plansRef(uid).doc(id), {
        'active': id == planId,
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Registros diarios desde [from] (inclusive), del más antiguo al más nuevo.
  ///
  /// La fecha sale del identificador del documento ("2026-10-01"), así que
  /// un día al que se le borró `dateKey` sigue apareciendo. Los documentos
  /// ilegibles se omiten.
  Future<List<DailyNutritionRecord>> getDays(String uid, DateTime from) async {
    final fromKey = DailyNutritionRecord.keyOf(from);
    // Sin filtros de consulta: un día sin `dateKey` también se lee. Hay un
    // documento por día, así que el volumen es pequeño.
    final snap = await _daysRef(uid).get();
    final days = <DailyNutritionRecord>[];
    for (final doc in snap.docs) {
      try {
        final record = DailyNutritionRecord.fromMap(doc.data(), id: doc.id);
        if (record.dateKey.compareTo(fromKey) >= 0) days.add(record);
      } catch (error) {
        debugPrint('Registro ${doc.id} ilegible, se omite: $error');
      }
    }
    days.sort((a, b) => a.dateKey.compareTo(b.dateKey));
    return days;
  }

  Future<void> saveDay(String uid, DailyNutritionRecord record) async {
    if (record.isEmpty) {
      await _daysRef(uid).doc(record.dateKey).delete();
      return;
    }
    await _daysRef(uid).doc(record.dateKey).set(record.toMap());
  }
}
