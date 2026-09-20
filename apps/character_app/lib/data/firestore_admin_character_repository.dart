import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_character_entry.dart';
import 'admin_character_repository.dart';
import 'character_doc.dart';

/// Lecture cross-utilisateurs via une requête de groupe de collections sur `characters`.
///
/// Autorisée par la règle `users/{uid}/characters/{id}` : Firestore évalue la
/// règle par document, peu importe le type de requête (get, query, collection group).
class FirestoreAdminCharacterRepository implements AdminCharacterRepository {
  FirestoreAdminCharacterRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<List<AdminCharacterEntry>> watchAllCharacters() =>
      _db.collectionGroup('characters').snapshots().map(_toEntries);

  static List<AdminCharacterEntry> _toEntries(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final entries = [
      for (final doc in snapshot.docs)
        AdminCharacterEntry(
          ownerUid: doc.reference.parent.parent!.id,
          doc: CharacterDoc.fromMap(doc.id, _fromFirestore(doc.data())),
        ),
    ]..removeWhere((e) => e.doc.isDeleted);
    entries.sort((a, b) => b.doc.updatedAt.compareTo(a.doc.updatedAt));
    return entries;
  }

  static Map<String, Object?> _fromFirestore(Map<String, dynamic> map) => {
    for (final entry in map.entries)
      entry.key:
          entry.value is Timestamp
              ? (entry.value as Timestamp).toDate()
              : entry.value,
  };
}
