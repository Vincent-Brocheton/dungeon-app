import 'admin_monster_doc.dart';

/// Accès aux monstres édités par un admin (`content/monsters`). Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract class AdminMonsterRepository {
  Stream<List<AdminMonsterDoc>> watchAll();

  Future<void> upsert(AdminMonsterDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
