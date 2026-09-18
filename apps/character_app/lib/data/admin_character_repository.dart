import 'admin_character_entry.dart';

/// Accès en lecture seule aux personnages de tous les utilisateurs, pour l'admin.
abstract class AdminCharacterRepository {
  /// Personnages non supprimés de tous les utilisateurs, du plus récemment
  /// mis à jour au plus ancien.
  Stream<List<AdminCharacterEntry>> watchAllCharacters();
}
