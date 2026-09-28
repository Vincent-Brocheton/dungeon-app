import 'dart:math';

import 'package:character_app/features/wizard/wizard_rules.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rules_engine/rules_engine.dart';

void main() {
  test('valeurs standard réparties selon la caractéristique principale', () {
    final scores = assignValues(
      standardArrayValues,
      defaultAssignmentOrder(Ability.strength),
    );
    expect(scores.strength, 15);
    expect(scores.constitution, 14);
    expect(scores.dexterity, 13);
    expect(scores.wisdom, 12);
    expect(scores.charisma, 10);
    expect(scores.intelligence, 8);
  });

  test('4d6 en gardant les 3 meilleurs : 6 valeurs entre 3 et 18, '
      'triées', () {
    final values = roll4d6DropLowest(Random(42));
    expect(values, hasLength(6));
    expect(values.every((v) => v >= 3 && v <= 18), isTrue);
    expect(values, [...values]..sort((a, b) => b.compareTo(a)));
  });

  test('bonus d\'historique par défaut : +2 sur la caractéristique '
      'principale si possible, +1 sur la suivante', () {
    const bg = [Ability.strength, Ability.dexterity, Ability.constitution];
    final bonus = defaultBonus(bg, Ability.strength) as PlusTwoPlusOne;
    expect(bonus.plusTwo, Ability.strength);
    expect(bonus.plusOne, Ability.dexterity);

    final other = defaultBonus(bg, Ability.wisdom) as PlusTwoPlusOne;
    expect(other.plusTwo, Ability.strength);
  });

  test('stats dérivées d\'un guerrier niveau 1', () {
    const scores = AbilityScores(
      strength: 17,
      dexterity: 14,
      constitution: 14,
      intelligence: 8,
      wisdom: 10,
      charisma: 12,
    );
    final stats = deriveStats(
      scores: scores,
      hitDie: 'd10',
      savingThrows: 'Force, Constitution',
    );
    expect(stats.hitPoints, 12);
    expect(stats.armorClass, 12);
    expect(stats.initiative, 2);
    expect(stats.proficiencyBonus, 2);
    expect(stats.passivePerception, 10);
    expect(stats.saves[Ability.strength], (5, true));
    expect(stats.saves[Ability.constitution], (4, true));
    expect(stats.saves[Ability.dexterity], (2, false));
  });

  test('langues suggérées d\'après le texte de l\'espèce', () {
    expect(suggestedLanguages('Commun, Naine'), ['Naine']);
    expect(suggestedLanguages(''), isEmpty);
  });
}
