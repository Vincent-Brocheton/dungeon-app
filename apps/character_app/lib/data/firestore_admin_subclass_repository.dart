import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_subclass_doc.dart';
import 'admin_subclass_repository.dart';

/// `content/subclasses/items/{id}` — un document par sous-classe.
class FirestoreAdminSubclassRepository implements AdminSubclassRepository {
  FirestoreAdminSubclassRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _subclasses =>
      _db.collection('content').doc('subclasses').collection('items');

  @override
  Stream<List<AdminSubclassDoc>> watchAll() => _subclasses.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminSubclassDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminSubclassDoc doc) => _subclasses
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _subclasses.doc().id;

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
