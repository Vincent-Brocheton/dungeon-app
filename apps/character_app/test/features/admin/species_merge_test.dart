import 'package:character_app/data/admin_species_doc.dart';
import 'package:character_app/features/admin/species_merge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

ContentPack _pack(List<SpeciesDef> species) => ContentPack(
  id: 'test-pack',
  name: 'Test',
  schemaVersion: 1,
  license: 'CC-BY-4.0',
  species: species,
);

void main() {
  test('sans surcharge, reprend le pack SRD tel quel', () {
    final pack = _pack([
      const SpeciesDef(
        id: 'human',
        name: 'Human',
        sizeOptions: ['small', 'medium'],
        speed: 30,
      ),
    ]);

    final result = mergeSpecies(pack, const []);

    expect(result, hasLength(1));
    expect(result.single.id, 'human');
    expect(result.single.name, 'Human');
    expect(result.single.source, SpeciesSource.srd);
    expect(result.single.size, 'Moyenne');
    expect(result.single.speed, '9 m');
  });

  test('une surcharge remplace entièrement l\'entrée SRD correspondante', () {
    final pack = _pack([
      const SpeciesDef(
        id: 'human',
        name: 'Human',
        sizeOptions: ['medium'],
        speed: 30,
      ),
    ]);
    final override = AdminSpeciesDoc(
      id: 'human',
      name: 'Humain',
      source: SpeciesSource.official,
      description: 'Version enrichie par la table.',
      updatedAt: DateTime(2026, 9, 20),
    );

    final result = mergeSpecies(pack, [override]);

    expect(result, hasLength(1));
    expect(result.single.name, 'Humain');
    expect(result.single.source, SpeciesSource.official);
    expect(result.single.description, 'Version enrichie par la table.');
  });

  test('une surcharge sans entrée SRD correspondante s\'ajoute', () {
    final pack = _pack(const []);
    final homebrew = AdminSpeciesDoc(
      id: 'sylvanite',
      name: 'Sylvanite',
      source: SpeciesSource.homebrew,
      updatedAt: DateTime(2026, 9, 20),
    );

    final result = mergeSpecies(pack, [homebrew]);

    expect(result, hasLength(1));
    expect(result.single.name, 'Sylvanite');
    expect(result.single.source, SpeciesSource.homebrew);
  });

  test('la liste résultante est triée par nom', () {
    final pack = _pack(const []);
    final overrides = [
      AdminSpeciesDoc(
        id: 'z',
        name: 'Zorbek',
        updatedAt: DateTime(2026, 9, 20),
      ),
      AdminSpeciesDoc(
        id: 'a',
        name: 'Aelindra',
        updatedAt: DateTime(2026, 9, 20),
      ),
    ];

    final result = mergeSpecies(pack, overrides);

    expect(result.map((s) => s.name), ['Aelindra', 'Zorbek']);
  });

  test(
    'un pack nul (chargement pas encore terminé) ne casse pas la fusion',
    () {
      final override = AdminSpeciesDoc(
        id: 'sylvanite',
        name: 'Sylvanite',
        updatedAt: DateTime(2026, 9, 20),
      );

      final result = mergeSpecies(null, [override]);

      expect(result, hasLength(1));
      expect(result.single.name, 'Sylvanite');
    },
  );
}
