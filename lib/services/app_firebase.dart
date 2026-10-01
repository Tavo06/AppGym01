import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Punto único de acceso a Firebase. En la app devuelve las instancias
/// reales; las pruebas pueden sustituirlas por implementaciones simuladas.
class AppFirebase {
  AppFirebase._();

  @visibleForTesting
  static FirebaseAuth? authOverride;

  @visibleForTesting
  static FirebaseFirestore? firestoreOverride;

  static FirebaseAuth get auth => authOverride ?? FirebaseAuth.instance;

  static FirebaseFirestore get firestore =>
      firestoreOverride ?? FirebaseFirestore.instance;
}
