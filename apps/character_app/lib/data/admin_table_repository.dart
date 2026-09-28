import 'admin_table_doc.dart';

/// Accès à la table du MJ (`table/main`), lisible par les seuls admins.
/// Implémenté par Firestore, et en mémoire pour les tests.
abstract class AdminTableRepository {
  /// La table, ou `null` tant qu'elle n'a jamais été enregistrée.
  Stream<AdminTableDoc?> watch();

  Future<void> save(AdminTableDoc doc);
}
