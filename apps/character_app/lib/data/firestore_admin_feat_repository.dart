import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_feat_doc.dart';
import 'admin_feat_repository.dart';

/// `content/feats/items/{id}` — un document par don.
class FirestoreAdminFeatRepository implements AdminFeatRepository {
  FirestoreAdminFeatRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _feats =>
      _db.collection('content').doc('feats').collection('items');

  @override
  Stream<List<AdminFeatDoc>> watchAll() => _feats.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminFeatDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminFeatDoc doc) => _feats
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _feats.doc().id;

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
