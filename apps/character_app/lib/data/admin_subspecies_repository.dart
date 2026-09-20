import 'admin_subspecies_doc.dart';

/// Accès aux sous-espèces éditées par un admin (`content/subspecies`).
/// Collection globale, non scopée par utilisateur. Implémenté par Firestore,
/// et en mémoire pour les tests.
abstract class AdminSubspeciesRepository {
  Stream<List<AdminSubspeciesDoc>> watchAll();

  Future<void> upsert(AdminSubspeciesDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
