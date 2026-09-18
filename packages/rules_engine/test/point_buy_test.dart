import 'package:rules_engine/rules_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PointBuy', () {
    test('tout à 8 coûte 0, il reste 27 points', () {
      expect(PointBuy.totalCost(PointBuy.standardStart), 0);
      expect(PointBuy.remaining(PointBuy.standardStart), 27);
      expect(PointBuy.validate(PointBuy.standardStart), isEmpty);
    });

    test('le tableau standard 15/14/13/12/10/8 coûte exactement 27', () {
      expect(PointBuy.totalCost(PointBuy.standardArray), 27);
      expect(PointBuy.remaining(PointBuy.standardArray), 0);
      expect(PointBuy.validate(PointBuy.standardArray), isEmpty);
    });

    test('tout à 15 dépasse le budget', () {
      const scores = AbilityScores.all(15);
      expect(PointBuy.totalCost(scores), 54);
      final violations = PointBuy.validate(scores);
      expect(violations.map((v) => v.code), ['point_buy.over_budget']);
    });

    test('un score hors 8–15 est signalé sur la bonne caractéristique', () {
      const scores = AbilityScores(strength: 16, dexterity: 7);
      final violations = PointBuy.validate(scores);
      expect(
        violations.map((v) => (v.code, v.ability)),
        containsAll([
          ('point_buy.out_of_range', Ability.strength),
          ('point_buy.out_of_range', Ability.dexterity),
        ]),
      );
    });

    test('costOf lève hors plage', () {
      expect(() => PointBuy.costOf(16), throwsArgumentError);
      expect(() => PointBuy.costOf(7), throwsArgumentError);
    });

    test('deltaCost : passer de 13 à 14 coûte 2, de 14 à 15 coûte 2', () {
      expect(PointBuy.deltaCost(13, 14), 2);
      expect(PointBuy.deltaCost(14, 15), 2);
      expect(PointBuy.deltaCost(15, 14), -2);
    });
  });
}
