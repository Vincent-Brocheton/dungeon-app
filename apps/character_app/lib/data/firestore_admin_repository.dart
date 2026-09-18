import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_repository.dart';

/// Le rôle admin est déterminé par l'existence d'un document `admins/{uid}`.
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository(this._db);

  final FirebaseFirestore _db;

  @override
  Stream<bool> watchIsAdmin(String uid) =>
      _db.collection('admins').doc(uid).snapshots().map((doc) => doc.exists);
}
