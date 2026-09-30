import 'dart:math';

import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  test('dé retenu selon le mode, total avec le modificateur', () {
    const dice = [14, 9];
    expect(
      const D20Roll(dice: [16], modifier: 7, mode: RollMode.normal).total,
      23,
    );
    expect(
      const D20Roll(dice: dice, modifier: 7, mode: RollMode.advantage).kept,
      14,
    );
    expect(
      const D20Roll(dice: dice, modifier: 4, mode: RollMode.disadvantage).total,
      13,
    );
  });

  test('un dé en jet simple, deux sinon, toujours entre 1 et 20', () {
    final rng = Random(1);
    for (var i = 0; i < 200; i++) {
      final normal = D20Roll.roll(rng, 0);
      final adv = D20Roll.roll(rng, 0, mode: RollMode.advantage);
      expect(normal.dice, hasLength(1));
      expect(adv.dice, hasLength(2));
      for (final d in [...normal.dice, ...adv.dice]) {
        expect(d, inInclusiveRange(1, 20));
      }
    }
  });
}
