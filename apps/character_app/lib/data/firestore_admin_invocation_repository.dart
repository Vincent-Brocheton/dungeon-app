import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_invocation_doc.dart';
import 'admin_invocation_repository.dart';

/// `content/invocations/items/{id}` — un document par manifestation.
class FirestoreAdminInvocationRepository implements AdminInvocationRepository {
  FirestoreAdminInvocationRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _invocations =>
      _db.collection('content').doc('invocations').collection('items');

  @override
  Stream<List<AdminInvocationDoc>> watchAll() => _invocations.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminInvocationDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminInvocationDoc doc) => _invocations
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _invocations.doc().id;

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
