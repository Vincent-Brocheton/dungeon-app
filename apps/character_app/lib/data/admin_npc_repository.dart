import 'admin_npc_doc.dart';

/// Accès aux PNJ édités par un admin (`npcs`). Collection globale, non
/// scopée par utilisateur, lisible par les seuls admins. Implémenté par
/// Firestore, et en mémoire pour les tests.
abstract class AdminNpcRepository {
  Stream<List<AdminNpcDoc>> watchAll();

  Future<void> upsert(AdminNpcDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
