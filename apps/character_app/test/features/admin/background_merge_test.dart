import 'package:character_app/data/admin_background_doc.dart';
import 'package:character_app/data/admin_species_doc.dart';
import 'package:character_app/features/admin/background_merge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

const _acolyte = BackgroundDef(
  id: 'acolyte',
  name: 'Acolyte',
  abilities: {Ability.intelligence, Ability.wisdom, Ability.charisma},
  originFeat: 'magic-initiate-cleric',
  skills: ['insight', 'religion'],
  tool: 'calligraphers-supplies',
);

ContentPack _pack(List<BackgroundDef> backgrounds) => ContentPack(
  id: 'test-pack',
  name: 'Test',
  schemaVersion: 1,
  license: 'CC-BY-4.0',
  backgrounds: backgrounds,
);

void main() {
  test('sans surcharge, reprend le pack SRD, caractéristiques en français', () {
    final result = mergeBackgrounds(_pack(const [_acolyte]), const []);

    expect(result, hasLength(1));
    final acolyte = result.single;
    expect(acolyte.id, 'acolyte');
    expect(acolyte.source, SpeciesSource.srd);
    expect(acolyte.abilities, ['Intelligence', 'Sagesse', 'Charisme']);
    expect(acolyte.originFeat, 'magic-initiate-cleric');
    expect(acolyte.skills, 'insight, religion');
    expect(acolyte.tool, 'calligraphers-supplies');
  });

  test('une surcharge remplace l\'entrée SRD, un nouvel id s\'ajoute, trié '
      'par nom', () {
    final now = DateTime(2026);
    final result = mergeBackgrounds(_pack(const [_acolyte]), [
      AdminBackgroundDoc(
        id: 'acolyte',
        name: 'Acolyte (maison)',
        updatedAt: now,
      ),
      AdminBackgroundDoc(
        id: 'mist',
        name: 'Marchand des Brumes',
        updatedAt: now,
      ),
    ]);

    expect(
      [for (final b in result) b.name],
      ['Acolyte (maison)', 'Marchand des Brumes'],
    );
  });

  test('sans pack, ne garde que les surcharges', () {
    final result = mergeBackgrounds(null, [
      AdminBackgroundDoc(id: 'x', name: 'X', updatedAt: DateTime(2026)),
    ]);
    expect(result.single.id, 'x');
  });
}
