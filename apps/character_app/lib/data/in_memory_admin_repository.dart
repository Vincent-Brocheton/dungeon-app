import 'admin_repository.dart';

/// Implémentation en mémoire : tests de widgets et développement sans Firebase.
class InMemoryAdminRepository implements AdminRepository {
  InMemoryAdminRepository({Set<String> admins = const {}})
    : _admins = {...admins};

  final Set<String> _admins;

  @override
  Stream<bool> watchIsAdmin(String uid) => Stream.value(_admins.contains(uid));
}
