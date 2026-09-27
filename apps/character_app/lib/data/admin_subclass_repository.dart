import 'admin_subclass_doc.dart';

/// Accès aux sous-classes éditées par un admin (`content/subclasses`).
/// Collection globale, non scopée par utilisateur. Implémenté par Firestore,
/// et en mémoire pour les tests.
abstract class AdminSubclassRepository {
  Stream<List<AdminSubclassDoc>> watchAll();

  Future<void> upsert(AdminSubclassDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
