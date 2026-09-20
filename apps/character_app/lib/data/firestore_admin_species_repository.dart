import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_species_doc.dart';
import 'admin_species_repository.dart';

/// `content/species/{id}` — un document par espèce éditée par un admin.
class FirestoreAdminSpeciesRepository implements AdminSpeciesRepository {
  FirestoreAdminSpeciesRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _species =>
      _db.collection('content').doc('species').collection('items');

  @override
  Stream<List<AdminSpeciesDoc>> watchAll() => _species.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        AdminSpeciesDoc.fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(AdminSpeciesDoc doc) => _species
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _species.doc().id;

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
