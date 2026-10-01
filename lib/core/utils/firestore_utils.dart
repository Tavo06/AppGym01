import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? firestoreDateFrom(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}
