import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_table_doc.dart';
import 'admin_table_repository.dart';

/// `table/main` — un seul document pour la table du MJ.
class FirestoreAdminTableRepository implements AdminTableRepository {
  FirestoreAdminTableRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _db.collection('table').doc('main');

  @override
  Stream<AdminTableDoc?> watch() => _doc.snapshots().map((snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return AdminTableDoc.fromMap({
      ...data,
      if (data['updatedAt'] is Timestamp)
        'updatedAt': (data['updatedAt'] as Timestamp).toDate(),
    });
  });

  @override
  Future<void> save(AdminTableDoc doc) => _doc.set({
    ...doc.toMap(),
    'updatedAt': Timestamp.fromDate(doc.updatedAt),
  });
}
