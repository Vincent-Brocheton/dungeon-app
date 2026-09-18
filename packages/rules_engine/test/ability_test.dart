import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  group('abilityModifier', () {
    test('suit la table du PHB', () {
      expect(abilityModifier(1), -5);
      expect(abilityModifier(8), -1);
      expect(abilityModifier(9), -1);
      expect(abilityModifier(10), 0);
      expect(abilityModifier(11), 0);
      expect(abilityModifier(15), 2);
      expect(abilityModifier(20), 5);
      expect(abilityModifier(30), 10);
    });
  });

  group('Ability.parse', () {
    test('accepte le code et le nom, insensible à la casse', () {
      expect(Ability.parse('STR'), Ability.strength);
      expect(Ability.parse('dex'), Ability.dexterity);
      expect(Ability.parse('Wisdom'), Ability.wisdom);
    });

    test('rejette une valeur inconnue', () {
      expect(() => Ability.parse('LUCK'), throwsArgumentError);
    });
  });

  group('AbilityScores', () {
    test('withScore ne modifie que la caractéristique visée', () {
      const base = AbilityScores.all(10);
      final next = base.withScore(Ability.charisma, 14);
      expect(next.charisma, 14);
      expect(next.strength, 10);
      expect(base.charisma, 10, reason: 'immutabilité');
    });

    test('égalité structurelle', () {
      expect(const AbilityScores.all(8), const AbilityScores.all(8));
      expect(const AbilityScores.all(8), isNot(const AbilityScores.all(9)));
    });
  });
}
