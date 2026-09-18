import 'character_doc.dart';

/// Accès aux personnages d'un utilisateur. Implémenté par Firestore, et en mémoire pour les tests.
abstract class CharacterRepository {
  /// Personnages non supprimés, du plus récent au plus ancien.
  Stream<List<CharacterDoc>> watchAll(String uid);

  Future<void> upsert(String uid, CharacterDoc doc);

  /// Suppression douce (`deletedAt`), conservée pour la synchro.
  Future<void> softDelete(String uid, String id);

  /// Suppression définitive de tout : uniquement avant suppression du compte.
  Future<void> deleteAll(String uid);

  /// Identifiant neuf, généré côté client pour fonctionner hors-ligne.
  String newId();
}
