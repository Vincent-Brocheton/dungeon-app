import 'character_doc.dart';

/// Un personnage vu par l'admin, avec l'identifiant de son propriétaire.
class AdminCharacterEntry {
  const AdminCharacterEntry({required this.ownerUid, required this.doc});

  final String ownerUid;
  final CharacterDoc doc;
}
