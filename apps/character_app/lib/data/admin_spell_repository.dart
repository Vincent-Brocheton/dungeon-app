import 'admin_spell_doc.dart';

/// Accès aux sorts édités par un admin (`content/spells`). Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract class AdminSpellRepository {
  Stream<List<AdminSpellDoc>> watchAll();

  Future<void> upsert(AdminSpellDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
