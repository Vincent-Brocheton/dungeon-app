import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_background_doc.dart';
import 'admin_background_repository.dart';

/// `content/backgrounds/{id}` — un document par historique édité par un admin.
class FirestoreAdminBackgroundRepository implements AdminBackgroundRepository {
  FirestoreAdminBackgroundRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _backgrounds =>
      _db.collection('content').doc('backgrounds').collection('items');

  @override
  Stream<List<AdminBackgroundDoc>> watchAll() => _backgrounds.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminBackgroundDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminBackgroundDoc doc) => _backgrounds
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _backgrounds.doc().id;

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
