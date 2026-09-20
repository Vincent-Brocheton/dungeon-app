import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_subspecies_doc.dart';
import 'admin_subspecies_repository.dart';

/// `content/subspecies/items/{id}` — un document par sous-espèce.
class FirestoreAdminSubspeciesRepository implements AdminSubspeciesRepository {
  FirestoreAdminSubspeciesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _subspecies =>
      _db.collection('content').doc('subspecies').collection('items');

  @override
  Stream<List<AdminSubspeciesDoc>> watchAll() => _subspecies.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminSubspeciesDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminSubspeciesDoc doc) => _subspecies
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _subspecies.doc().id;

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
