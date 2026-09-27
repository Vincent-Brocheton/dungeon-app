import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_monster_doc.dart';
import 'admin_monster_repository.dart';

/// `content/monsters/items/{id}` — un document par monstre.
class FirestoreAdminMonsterRepository implements AdminMonsterRepository {
  FirestoreAdminMonsterRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _monsters =>
      _db.collection('content').doc('monsters').collection('items');

  @override
  Stream<List<AdminMonsterDoc>> watchAll() => _monsters.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminMonsterDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminMonsterDoc doc) => _monsters
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _monsters.doc().id;

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
