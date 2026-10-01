import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  test('Empoisonné : désavantage aux attaques et aux tests, pas aux '
      'sauvegardes', () {
    const poisoned = {Condition.poisoned};
    expect(d20Effects(poisoned, 0, D20Test.attack).mode, RollMode.disadvantage);
    expect(d20Effects(poisoned, 0, D20Test.check).mode, RollMode.disadvantage);
    expect(
      d20Effects(poisoned, 0, D20Test.save, ability: Ability.wisdom).mode,
      RollMode.normal,
    );
  });

  test('avantage et désavantage s\'annulent', () {
    final effects = d20Effects(
      {Condition.invisible, Condition.prone},
      0,
      D20Test.attack,
    );
    expect(effects.advantage, [Condition.invisible]);
    expect(effects.disadvantage, [Condition.prone]);
    expect(effects.mode, RollMode.normal);
  });

  test('échec automatique aux sauvegardes de Force et Dextérité', () {
    const stunned = {Condition.stunned};
    expect(
      d20Effects(stunned, 0, D20Test.save, ability: Ability.dexterity).autoFail,
      [Condition.stunned],
    );
    expect(
      d20Effects(stunned, 0, D20Test.save, ability: Ability.wisdom).autoFail,
      isEmpty,
    );
    expect(
      d20Effects(
        {Condition.restrained},
        0,
        D20Test.save,
        ability: Ability.dexterity,
      ).mode,
      RollMode.disadvantage,
    );
  });

  test('épuisement : -2 par niveau à tous les tests de d20', () {
    expect(d20Effects({}, 3, D20Test.save).penalty, -6);
    expect(d20Effects({}, 0, D20Test.check).penalty, 0);
  });

  test('vitesse à 0', () {
    expect(Condition.grappled.zeroSpeed, isTrue);
    expect(Condition.poisoned.zeroSpeed, isFalse);
  });
}
