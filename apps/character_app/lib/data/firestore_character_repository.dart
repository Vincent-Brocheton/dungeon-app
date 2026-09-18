import 'package:cloud_firestore/cloud_firestore.dart';

import 'character_doc.dart';
import 'character_repository.dart';

/// `users/{uid}/characters/{id}` — un document par personnage.
class FirestoreCharacterRepository implements CharacterRepository {
  FirestoreCharacterRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _characters(String uid) =>
      _db.collection('users').doc(uid).collection('characters');

  @override
  Stream<List<CharacterDoc>> watchAll(String uid) => _characters(uid)
      .orderBy('updatedAt', descending: true)
      .snapshots()
      .map(
        (snapshot) => [
          for (final doc in snapshot.docs)
            CharacterDoc.fromMap(doc.id, _fromFirestore(doc.data())),
        ]..removeWhere((c) => c.isDeleted),
      );

  @override
  Future<void> upsert(String uid, CharacterDoc doc) => _characters(uid)
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  Future<void> softDelete(String uid, String id) =>
      _characters(uid).doc(id).set(
        {'deletedAt': Timestamp.now(), 'updatedAt': Timestamp.now()},
        SetOptions(merge: true),
      );

  @override
  Future<void> deleteAll(String uid) async {
    final snapshot = await _characters(uid).get();
    // 500 opérations max par batch.
    for (var i = 0; i < snapshot.docs.length; i += 500) {
      final batch = _db.batch();
      for (final doc in snapshot.docs.skip(i).take(500)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _db.collection('users').doc(uid).delete();
  }

  @override
  String newId() => _db.collection('users').doc().id;

  static Map<String, Object?> _toFirestore(Map<String, Object?> map) => {
        for (final entry in map.entries)
          entry.key: entry.value is DateTime
              ? Timestamp.fromDate(entry.value as DateTime)
              : entry.value,
      };

  static Map<String, Object?> _fromFirestore(Map<String, dynamic> map) => {
        for (final entry in map.entries)
          entry.key: entry.value is Timestamp
              ? (entry.value as Timestamp).toDate()
              : entry.value,
      };
}
