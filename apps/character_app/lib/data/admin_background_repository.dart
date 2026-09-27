import 'admin_background_doc.dart';

/// Accès aux historiques édités par un admin (`content/backgrounds`). Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract class AdminBackgroundRepository {
  Stream<List<AdminBackgroundDoc>> watchAll();

  Future<void> upsert(AdminBackgroundDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
