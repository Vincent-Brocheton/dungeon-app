import 'admin_species_doc.dart';

/// Accès aux espèces éditées par un admin (`content/species`). Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract class AdminSpeciesRepository {
  Stream<List<AdminSpeciesDoc>> watchAll();

  Future<void> upsert(AdminSpeciesDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
