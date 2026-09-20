import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_spell_doc.dart';
import 'admin_spell_repository.dart';

/// `content/spells/items/{id}` — un document par sort.
class FirestoreAdminSpellRepository implements AdminSpellRepository {
  FirestoreAdminSpellRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _spells =>
      _db.collection('content').doc('spells').collection('items');

  @override
  Stream<List<AdminSpellDoc>> watchAll() => _spells.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminSpellDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminSpellDoc doc) => _spells
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _spells.doc().id;

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
