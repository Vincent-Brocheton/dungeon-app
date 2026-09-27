import 'admin_invocation_doc.dart';

/// Accès aux manifestations occultes éditées par un admin (`content/invocations`). Collection
/// globale, non scopée par utilisateur. Implémenté par Firestore, et en
/// mémoire pour les tests.
abstract class AdminInvocationRepository {
  Stream<List<AdminInvocationDoc>> watchAll();

  Future<void> upsert(AdminInvocationDoc doc);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
