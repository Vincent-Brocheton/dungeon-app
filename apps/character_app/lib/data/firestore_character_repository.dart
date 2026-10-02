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
  Future<void> upsert(String uid, CharacterDoc doc) => _characters(
    uid,
  ).doc(doc.id).set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  Future<void> softDelete(String uid, String id) =>
      _characters(uid).doc(id).set({
        'deletedAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));

  CollectionReference<Map<String, dynamic>> _notes(String uid) =>
      _db.collection('users').doc(uid).collection('notes');

  // Filtre seul, tri côté client : pas d'index composite à déployer.
  @override
  Stream<List<CharacterNote>> watchNotes(String uid, String characterId) =>
      _notes(uid)
          .where('characterId', isEqualTo: characterId)
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs)
                CharacterNote.fromMap(doc.id, _fromFirestore(doc.data())),
            ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );

  @override
  Future<void> addNote(String uid, CharacterNote note) =>
      _notes(uid).doc(note.id).set(_toFirestore(note.toMap()));

  @override
  Future<void> deleteNote(String uid, String noteId) =>
      _notes(uid).doc(noteId).delete();

  CollectionReference<Map<String, dynamic>> _rolls(String uid) =>
      _db.collection('users').doc(uid).collection('rolls');

  @override
  Stream<List<RollRecord>> watchRolls(String uid, String characterId) =>
      _rolls(uid)
          .where('characterId', isEqualTo: characterId)
          .snapshots()
          .map(
            (snapshot) => [
              for (final doc in snapshot.docs)
                RollRecord.fromMap(doc.id, _fromFirestore(doc.data())),
            ]..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
          );

  @override
  Future<void> addRoll(String uid, RollRecord roll) =>
      _rolls(uid).doc(roll.id).set(_toFirestore(roll.toMap()));

  @override
  Future<void> deleteAll(String uid) async {
    for (final collection in [_characters(uid), _notes(uid), _rolls(uid)]) {
      final snapshot = await collection.get();
      // 500 opérations max par batch.
      for (var i = 0; i < snapshot.docs.length; i += 500) {
        final batch = _db.batch();
        for (final doc in snapshot.docs.skip(i).take(500)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }
    await _db.collection('users').doc(uid).delete();
  }

  @override
  String newId() => _db.collection('users').doc().id;

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
