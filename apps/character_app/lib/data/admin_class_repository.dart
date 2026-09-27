import 'admin_class_doc.dart';

/// Accès aux classes éditées par un admin (`content/classes`). Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract class AdminClassRepository {
  Stream<List<AdminClassDoc>> watchAll();

  Future<void> upsert(AdminClassDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
