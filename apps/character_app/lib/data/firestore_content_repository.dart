import 'package:cloud_firestore/cloud_firestore.dart';

import 'content_repository.dart';

/// Une collection Firestore, un document par [ContentDoc]. Les `DateTime`
/// de premier niveau sont stockés en `Timestamp`.
class FirestoreContentRepository<T extends ContentDoc>
    implements ContentRepository<T> {
  FirestoreContentRepository(this._collection, this._fromMap);

  final CollectionReference<Map<String, dynamic>> _collection;
  final T Function(String id, Map<String, Object?> map) _fromMap;

  @override
  Stream<List<T>> watchAll() => _collection.snapshots().map(
    (snapshot) => [
      for (final doc in snapshot.docs)
        _fromMap(doc.id, _fromFirestore(doc.data())),
    ],
  );

  @override
  Future<void> upsert(T doc) => _collection
      .doc(doc.id)
      .set(_toFirestore(doc.toMap()), SetOptions(merge: true));

  @override
  String newId() => _collection.doc().id;

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
