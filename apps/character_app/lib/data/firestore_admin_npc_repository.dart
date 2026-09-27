import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_npc_doc.dart';
import 'admin_npc_repository.dart';

/// `npcs/{id}` — un document par PNJ ; hors de `content/`, lisible par les
/// seuls admins (fiches de scène du MJ, pas du contenu de règles).
class FirestoreAdminNpcRepository implements AdminNpcRepository {
  FirestoreAdminNpcRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _npcs => _db.collection('npcs');

  @override
  Stream<List<AdminNpcDoc>> watchAll() => _npcs.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminNpcDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminNpcDoc doc) =>
      _npcs.doc(doc.id).set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _npcs.doc().id;

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
