import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

const _json = <String, dynamic>{
  'id': 'test-pack',
  'name': 'Pack de test',
  'schemaVersion': 1,
  'license': 'CC-BY-4.0',
  'species': [
    {
      'id': 'human',
      'name': 'Humain',
      'sizeOptions': ['small', 'medium'],
      'speed': 30,
    },
  ],
  'backgrounds': [
    {
      'id': 'scribe-test',
      'name': 'Scribe (test)',
      'abilities': ['INT', 'WIS', 'CHA'],
      'originFeat': 'test-feat',
      'skills': ['history', 'arcana'],
      'tool': 'calligraphers-supplies',
    },
  ],
};

void main() {
  group('ContentPack.fromJson', () {
    test('lit espèces et backgrounds', () {
      final pack = ContentPack.fromJson(_json);
      expect(pack.id, 'test-pack');
      expect(pack.speciesById('human')?.speed, 30);
      final background = pack.backgroundById('scribe-test')!;
      expect(
        background.abilities,
        {Ability.intelligence, Ability.wisdom, Ability.charisma},
      );
      expect(background.skills, ['history', 'arcana']);
    });

    test('refuse un schéma plus récent que le moteur', () {
      final json = Map<String, dynamic>.of(_json)
        ..['schemaVersion'] = supportedSchemaVersion + 1;
      expect(
        () => ContentPack.fromJson(json),
        throwsA(isA<UnsupportedSchemaVersion>()),
      );
    });

    test('refuse un Background sans exactement 3 caracs', () {
      final json = Map<String, dynamic>.of(_json)
        ..['backgrounds'] = [
          {
            'id': 'bad',
            'name': 'Bad',
            'abilities': ['INT', 'WIS'],
            'originFeat': 'x',
            'skills': <String>[],
            'tool': 'x',
          },
        ];
      expect(() => ContentPack.fromJson(json), throwsFormatException);
    });

    test('refuse un champ obligatoire manquant', () {
      final json = Map<String, dynamic>.of(_json)..remove('license');
      expect(() => ContentPack.fromJson(json), throwsFormatException);
    });
  });
}
