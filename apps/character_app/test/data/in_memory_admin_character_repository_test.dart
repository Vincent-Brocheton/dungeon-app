import 'package:character_app/data/admin_character_entry.dart';
import 'package:character_app/data/character_doc.dart';
import 'package:character_app/data/in_memory_admin_character_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

CharacterDoc _doc(
  String id,
  String name,
  DateTime updatedAt, {
  DateTime? deletedAt,
}) =>
    CharacterDoc(
      id: id,
      name: name,
      scores: PointBuy.standardArray,
      createdAt: updatedAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );

void main() {
  test(
    'filtre les personnages supprimés et trie par updatedAt décroissant, '
    'tous propriétaires confondus',
    () async {
      final repo = InMemoryAdminCharacterRepository(
        seed: [
          AdminCharacterEntry(
            ownerUid: 'uid-a',
            doc: _doc('c1', 'Ancien', DateTime(2026, 1, 1)),
          ),
          AdminCharacterEntry(
            ownerUid: 'uid-b',
            doc: _doc('c2', 'Récent', DateTime(2026, 6, 1)),
          ),
          AdminCharacterEntry(
            ownerUid: 'uid-a',
            doc: _doc(
              'c3',
              'Supprimé',
              DateTime(2026, 9, 1),
              deletedAt: DateTime(2026, 9, 2),
            ),
          ),
        ],
      );

      final list = await repo.watchAllCharacters().first;

      expect(list.map((e) => e.doc.id), ['c2', 'c1']);
      expect(list.map((e) => e.ownerUid), ['uid-b', 'uid-a']);
    },
  );
}
