import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_class_doc.dart';
import 'admin_class_repository.dart';

/// `content/classes/items/{id}` — un document par classe.
class FirestoreAdminClassRepository implements AdminClassRepository {
  FirestoreAdminClassRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _classes =>
      _db.collection('content').doc('classes').collection('items');

  @override
  Stream<List<AdminClassDoc>> watchAll() => _classes.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminClassDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminClassDoc doc) => _classes
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _classes.doc().id;

  static Map<String, Object?> _toFirestore(Map<String, Object?> map) => {
    for (final entry in map.entries)
      entry.key:
          entry.value is DateTime
              ? Timestamp.fromDate(entry.value as DateTime)
              : entry.value,
  };

  static Map<String, Object?> _fromFirestore(Map<String, dynamic> map) => {
    for (final entry in map.entries)
      entry.key:
          entry.value is Timestamp
              ? (entry.value as Timestamp).toDate()
              : entry.value,
  };
}
