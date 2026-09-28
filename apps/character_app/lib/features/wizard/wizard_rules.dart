import 'dart:math';

import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_class_doc.dart';

/// Règles de l'assistant de création, sans UI : répartition des valeurs,
/// jets, bonus d'historique par défaut, statistiques dérivées.

/// Valeurs standard (PHB 2024).
const standardArrayValues = [15, 14, 13, 12, 10, 8];

/// Langues courantes au choix (le Commun est acquis d'office).
const commonLanguages = [
  'Draconique',
  'Elfique',
  'Gigant',
  'Gnome',
  'Gobelin',
  'Halfelin',
  'Langue des signes',
  'Naine',
  'Orc',
];

/// Nombre de langues courantes à choisir en plus du Commun.
const languagesToChoose = 2;

/// Libellé français → caractéristique (« Force » → [Ability.strength]).
Ability? abilityFromLabel(String label) {
  final i = AdminClassDoc.abilities.indexOf(label.trim());
  return i < 0 ? null : Ability.values[i];
}

/// Libellé français d'une caractéristique.
String abilityLabel(Ability ability) => AdminClassDoc.abilities[ability.index];

/// Ordre de répartition par défaut : la caractéristique principale de la
/// classe d'abord, puis Constitution, Dextérité, Sagesse, Charisme,
/// Intelligence.
List<Ability> defaultAssignmentOrder(Ability? primary) =>
    {
      if (primary != null) primary,
      Ability.constitution,
      Ability.dexterity,
      Ability.wisdom,
      Ability.charisma,
      Ability.intelligence,
      Ability.strength,
    }.toList();

/// Attribue [values] (du plus haut au plus bas) aux caractéristiques dans
/// l'ordre [order].
AbilityScores assignValues(List<int> values, List<Ability> order) {
  final sorted = [...values]..sort((a, b) => b.compareTo(a));
  return AbilityScores.fromMap({
    for (var i = 0; i < order.length; i++) order[i]: sorted[i],
  });
}

/// Six jets de 4d6 en gardant les trois meilleurs dés, du plus haut au plus
/// bas.
List<int> roll4d6DropLowest(Random rng) => [
  for (var i = 0; i < 6; i++)
    ([for (var d = 0; d < 4; d++) rng.nextInt(6) + 1]
      ..sort()).skip(1).reduce((a, b) => a + b),
]..sort((a, b) => b.compareTo(a));

/// +2 sur la caractéristique principale si l'historique la propose (sinon
/// la première), +1 sur la suivante.
BackgroundBonus defaultBonus(List<Ability> background, Ability? primary) {
  final plusTwo = background.contains(primary) ? primary! : background.first;
  final plusOne = background.firstWhere((a) => a != plusTwo);
  return PlusTwoPlusOne(plusTwo: plusTwo, plusOne: plusOne);
}

/// Statistiques calculées au niveau 1.
class DerivedStats {
  const DerivedStats({
    required this.hitPoints,
    required this.armorClass,
    required this.initiative,
    required this.proficiencyBonus,
    required this.passivePerception,
    required this.saves,
  });

  final int hitPoints;

  /// Sans armure : 10 + Dextérité.
  final int armorClass;
  final int initiative;
  final int proficiencyBonus;
  final int passivePerception;

  /// Modificateur de sauvegarde et maîtrise, par caractéristique.
  final Map<Ability, (int, bool)> saves;
}

/// Statistiques d'un personnage niveau 1 : [hitDie] au format « d10 »,
/// [savingThrows] le texte libre des sauvegardes maîtrisées de la classe.
DerivedStats deriveStats({
  required AbilityScores scores,
  required String hitDie,
  required String savingThrows,
}) {
  final proficiency = proficiencyBonus(1);
  int mod(Ability a) => abilityModifier(scores[a]);
  final proficient = {
    for (final a in Ability.values)
      if (savingThrows.contains(abilityLabel(a))) a,
  };
  return DerivedStats(
    hitPoints:
        (int.tryParse(hitDie.replaceAll('d', '')) ?? 8) +
        mod(Ability.constitution),
    armorClass: 10 + mod(Ability.dexterity),
    initiative: mod(Ability.dexterity),
    proficiencyBonus: proficiency,
    passivePerception: 10 + mod(Ability.wisdom),
    saves: {
      for (final a in Ability.values)
        a: (
          mod(a) + (proficient.contains(a) ? proficiency : 0),
          proficient.contains(a),
        ),
    },
  );
}

/// Langues courantes citées dans le texte des langues d'une espèce.
List<String> suggestedLanguages(String speciesLanguages) {
  final text = speciesLanguages.toLowerCase();
  return [
    for (final l in commonLanguages)
      if (text.contains(l.toLowerCase())) l,
  ];
}

/// Sépare un texte d'équipement (« Tenue de voyage, Corde, 14 po ») en
/// objets et pièces d'or.
(List<String>, int) parseEquipment(String text) {
  final items = <String>[];
  var gold = 0;
  for (final part in text.split(',')) {
    final item = part.trim();
    if (item.isEmpty) continue;
    final po = RegExp(r'^(\d+)\s*po$').firstMatch(item);
    if (po != null) {
      gold += int.parse(po.group(1)!);
    } else {
      items.add(item);
    }
  }
  return (items, gold);
}
