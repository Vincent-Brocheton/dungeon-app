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

  test(
    "niveau et compétences : PV fixes par niveau, maîtrises d'historique",
    () {
      final stats = deriveStats(
        scores: const AbilityScores(
          strength: 17,
          dexterity: 14,
          constitution: 14,
          intelligence: 8,
          wisdom: 10,
          charisma: 12,
        ),
        hitDie: 'd10',
        savingThrows: '',
        skillProficiencies: 'Perception, Athlétisme',
        level: 5,
      );
      // 10 + 2, puis 4 niveaux à (5 + 1 + 2).
      expect(stats.hitPoints, 44);
      expect(stats.proficiencyBonus, 3);
      expect(stats.skills['Perception'], (3, true));
      expect(stats.skills['Perspicacité'], (0, false));
      expect(stats.passivePerception, 13);
      expect(stats.skills, hasLength(18));
    },
  );

  test("dégâts : PV temporaires absorbés d'abord, plafonnés au maximum", () {
    expect(takeDamage(3, hpLost: 0, tempHp: 5, maxHp: 10), (0, 2));
    expect(takeDamage(8, hpLost: 1, tempHp: 5, maxHp: 10), (4, 0));
    expect(takeDamage(50, hpLost: 0, tempHp: 0, maxHp: 10), (10, 0));
  });

  test('langues suggérées d\'après le texte de l\'espèce', () {
    expect(suggestedLanguages('Commun, Naine'), ['Naine']);
    expect(suggestedLanguages(''), isEmpty);
  });

  test('équipement : objets séparés par des virgules, or extrait', () {
    final (items, gold) = parseEquipment(
      'Tenue de voyage, Insigne de rang,  14 po, Corde (15 m)',
    );
    expect(items, ['Tenue de voyage', 'Insigne de rang', 'Corde (15 m)']);
    expect(gold, 14);
    final (none, noGold) = parseEquipment('');
    expect(none, isEmpty);
    expect(noGold, 0);
  });

  test("arme d'un objet : le nom le plus long l'emporte", () {
    const lance = WeaponDef(
      id: 'lance',
      name: 'Lance',
      diceCount: 1,
      diceSides: 6,
      damageType: 'perforant',
    );
    const lanceDArcon = WeaponDef(
      id: 'lance-d-arcon',
      name: "Lance d'arçon",
      diceCount: 1,
      diceSides: 10,
      damageType: 'perforant',
    );
    const weapons = [lance, lanceDArcon];
    expect(weaponForItem("Lance d'arçon", weapons), lanceDArcon);
    expect(weaponForItem('2 lances', weapons), lance);
    expect(weaponForItem('Corde', weapons), isNull);
  });

  test('attaque : Force au CAC, Dextérité à distance ou en finesse', () {
    const scores = AbilityScores(
      strength: 12,
      dexterity: 16,
      constitution: 10,
      intelligence: 10,
      wisdom: 10,
      charisma: 10,
    );
    WeaponDef weapon({bool ranged = false, bool finesse = false}) => WeaponDef(
      id: 'w',
      name: 'W',
      diceCount: 1,
      diceSides: 8,
      damageType: 'perforant',
      ranged: ranged,
      finesse: finesse,
    );
    expect(weaponAttack(weapon(), scores, 2), (Ability.strength, 3, 1));
    expect(weaponAttack(weapon(ranged: true), scores, 2), (
      Ability.dexterity,
      5,
      3,
    ));
    expect(weaponAttack(weapon(finesse: true), scores, 2), (
      Ability.dexterity,
      5,
      3,
    ));
  });

  test('repos court : dé + Constitution, au moins 1 PV par dé', () {
    expect(hitDiceHealing([6, 3], 2), 13);
    expect(hitDiceHealing([1, 2], -2), 2);
    expect(hitDiceHealing([], 3), 0);
  });

  test('PV par niveau : dé enregistré ou moyenne, plus Constitution', () {
    expect(levelUpHitPoints(10, 2, 1, const []), 0);
    expect(levelUpHitPoints(10, 2, 3, const [4]), (4 + 2) + (6 + 2));
  });

  test('amélioration de caractéristique plafonnée à 20', () {
    const scores = AbilityScores(
      strength: 19,
      dexterity: 14,
      constitution: 14,
      intelligence: 8,
      wisdom: 10,
      charisma: 12,
    );
    final improved = improveAbilities(scores, {
      Ability.strength: 2,
      Ability.dexterity: 1,
    });
    expect(improved.strength, 20);
    expect(improved.dexterity, 15);
    expect(improved.wisdom, 10);
  });
}
