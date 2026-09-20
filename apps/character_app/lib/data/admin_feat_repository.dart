import 'admin_feat_doc.dart';

/// Accès aux dons édités par un admin (`content/feats`). Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract class AdminFeatRepository {
  Stream<List<AdminFeatDoc>> watchAll();

  Future<void> upsert(AdminFeatDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
