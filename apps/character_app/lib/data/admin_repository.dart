/// Sait si un utilisateur a le rôle admin.
abstract class AdminRepository {
  /// `true` si un document `admins/{uid}` existe.
  Stream<bool> watchIsAdmin(String uid);
}
