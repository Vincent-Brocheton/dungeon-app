import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  // Un Background orienté Intelligence / Sagesse / Charisme.
  const allowed = {Ability.intelligence, Ability.wisdom, Ability.charisma};

  group('PlusTwoPlusOne', () {
    test('valide sur deux caracs du Background', () {
      const bonus = PlusTwoPlusOne(
        plusTwo: Ability.intelligence,
        plusOne: Ability.wisdom,
      );
      expect(bonus.validate(allowed), isEmpty);
      final applied = bonus.applyTo(PointBuy.standardArray);
      expect(applied.intelligence, 14);
      expect(applied.wisdom, 11);
      expect(applied.strength, 15, reason: 'les autres scores sont intacts');
    });

    test('refuse une carac hors Background', () {
      const bonus = PlusTwoPlusOne(
        plusTwo: Ability.strength,
        plusOne: Ability.wisdom,
      );
      final violations = bonus.validate(allowed);
      expect(violations.single.code, 'background_bonus.not_allowed');
      expect(violations.single.ability, Ability.strength);
    });

    test('refuse la même carac deux fois', () {
      const bonus = PlusTwoPlusOne(
        plusTwo: Ability.wisdom,
        plusOne: Ability.wisdom,
      );
      expect(
        bonus.validate(allowed).map((v) => v.code),
        contains('background_bonus.same_ability'),
      );
    });
  });

  group('PlusOneEach', () {
    test('valide sur les trois caracs du Background', () {
      const bonus = PlusOneEach(allowed);
      expect(bonus.validate(allowed), isEmpty);
      final applied = bonus.applyTo(const AbilityScores.all(10));
      expect(applied.intelligence, 11);
      expect(applied.wisdom, 11);
      expect(applied.charisma, 11);
      expect(applied.strength, 10);
    });

    test('refuse un nombre de caracs différent de 3', () {
      const bonus = PlusOneEach({Ability.intelligence, Ability.wisdom});
      expect(
        bonus.validate(allowed).map((v) => v.code),
        contains('background_bonus.wrong_count'),
      );
    });
  });

  group('plafond de 20', () {
    test('signale un score qui dépasserait 20', () {
      const bonus = PlusTwoPlusOne(
        plusTwo: Ability.charisma,
        plusOne: Ability.wisdom,
      );
      const base = AbilityScores(charisma: 19);
      final violations = bonus.validateCap(base);
      expect(violations.single.code, 'ability.over_cap');
      expect(violations.single.ability, Ability.charisma);
    });
  });
}
