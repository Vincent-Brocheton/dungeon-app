import 'dart:math';

import 'package:rules_engine/rules_engine.dart';

import '../../data/admin_class_doc.dart';
import '../../data/character_doc.dart';

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

/// Les 18 compétences (PHB 2024) et leur caractéristique.
const skills = {
  'Acrobaties': Ability.dexterity,
  'Arcanes': Ability.intelligence,
  'Athlétisme': Ability.strength,
  'Discrétion': Ability.dexterity,
  'Dressage': Ability.wisdom,
  'Escamotage': Ability.dexterity,
  'Histoire': Ability.intelligence,
  'Intimidation': Ability.charisma,
  'Investigation': Ability.intelligence,
  'Médecine': Ability.wisdom,
  'Nature': Ability.intelligence,
  'Perception': Ability.wisdom,
  'Perspicacité': Ability.wisdom,
  'Persuasion': Ability.charisma,
  'Religion': Ability.intelligence,
  'Représentation': Ability.charisma,
  'Survie': Ability.wisdom,
  'Tromperie': Ability.charisma,
};

/// Statistiques calculées d'un personnage.
class DerivedStats {
  const DerivedStats({
    required this.hitPoints,
    required this.armorClass,
    required this.initiative,
    required this.proficiencyBonus,
    required this.passivePerception,
    required this.saves,
    required this.skills,
  });

  final int hitPoints;

  /// Sans armure : 10 + Dextérité.
  final int armorClass;
  final int initiative;
  final int proficiencyBonus;
  final int passivePerception;

  /// Modificateur de sauvegarde et maîtrise, par caractéristique.
  final Map<Ability, (int, bool)> saves;

  /// Modificateur de compétence et maîtrise, par nom de [skills].
  final Map<String, (int, bool)> skills;
}

/// PV gagnés des niveaux 2 à [level] : dé de [hpGains] (moyenne fixe, moitié
/// + 1, quand il manque) + Constitution.
int levelUpHitPoints(int die, int con, int level, List<int> hpGains) => [
  for (var l = 2; l <= level; l++)
    (l - 2 < hpGains.length ? hpGains[l - 2] : die ~/ 2 + 1) + con,
].fold(0, (a, b) => a + b);

/// [scores] après une amélioration de caractéristique (+2, ou +1 et +1),
/// chaque score plafonné à 20.
AbilityScores improveAbilities(AbilityScores scores, Map<Ability, int> bonus) =>
    AbilityScores.fromMap({
      for (final a in Ability.values)
        a: min(abilityScoreCap, scores[a] + (bonus[a] ?? 0)),
    });

/// Statistiques d'un personnage : [hitDie] au format « d10 »,
/// [savingThrows] et [skillProficiencies] les textes libres des sauvegardes
/// et compétences maîtrisées (« Perspicacité, Religion »). PV au-delà du
/// niveau 1 : cf. [levelUpHitPoints].
DerivedStats deriveStats({
  required AbilityScores scores,
  required String hitDie,
  required String savingThrows,
  String skillProficiencies = '',
  int level = 1,
  List<int> hpGains = const [],
}) {
  final proficiency = proficiencyBonus(level);
  int mod(Ability a) => abilityModifier(scores[a]);
  final con = mod(Ability.constitution);
  final die = int.tryParse(hitDie.replaceAll('d', '')) ?? 8;
  final proficient = {
    for (final a in Ability.values)
      if (savingThrows.contains(abilityLabel(a))) a,
  };
  final skillText = skillProficiencies.toLowerCase();
  final skillMods = {
    for (final MapEntry(key: name, value: a) in skills.entries)
      name: switch (skillText.contains(name.toLowerCase())) {
        final p => (mod(a) + (p ? proficiency : 0), p),
      },
  };
  return DerivedStats(
    hitPoints: die + con + levelUpHitPoints(die, con, level, hpGains),
    armorClass: 10 + mod(Ability.dexterity),
    initiative: mod(Ability.dexterity),
    proficiencyBonus: proficiency,
    passivePerception: 10 + skillMods['Perception']!.$1,
    saves: {
      for (final a in Ability.values)
        a: (
          mod(a) + (proficient.contains(a) ? proficiency : 0),
          proficient.contains(a),
        ),
    },
    skills: skillMods,
  );
}

/// Nouvel état (PV perdus, PV temporaires) après [amount] dégâts : les PV
/// temporaires absorbent d'abord, les PV perdus plafonnent à [maxHp].
(int, int) takeDamage(
  int amount, {
  required int hpLost,
  required int tempHp,
  required int maxHp,
}) {
  final absorbed = min(amount, tempHp);
  return (min(maxHp, hpLost + amount - absorbed), tempHp - absorbed);
}

/// PV rendus par des dés de vie dépensés au repos court : chaque dé
/// + Constitution, au moins 1 PV par dé.
int hitDiceHealing(List<int> rolls, int constitutionModifier) =>
    rolls.fold(0, (sum, r) => sum + max(1, r + constitutionModifier));

/// Bourse après conversion de toutes les pièces de [from] vers la pièce
/// supérieure (10 pc → 1 pa, 10 pa → 1 po) : (po, pa, pc).
(int, int, int) convertCoins(int gold, int silver, int copper, Coin from) =>
    switch (from) {
      Coin.copper => (gold, silver + copper ~/ 10, copper % 10),
      Coin.silver => (gold + silver ~/ 10, silver % 10, copper),
      Coin.gold => (gold, silver, copper),
    };

/// Valeur totale en po, au centième (« 24,95 »).
String goldValue(int gold, int silver, int copper) {
  final total = gold * 100 + silver * 10 + copper;
  final cents = total % 100;
  return cents == 0
      ? '${total ~/ 100}'
      : '${total ~/ 100},${cents.toString().padLeft(2, '0')}';
}

/// Arme de [weapons] désignée par un objet d'équipement (« Arbalète
/// légère et 20 carreaux »), le nom le plus long l'emportant (« Lance
/// d'arçon » plutôt que « Lance »).
WeaponDef? weaponForItem(String item, List<WeaponDef> weapons) =>
    _longestMatch(item, weapons, (w) => w.name);

/// Armure ou bouclier de [armors] désigné par un objet d'inventaire.
ArmorDef? armorForItem(String item, List<ArmorDef> armors) =>
    _longestMatch(item, armors, (a) => a.name);

T? _longestMatch<T>(String item, List<T> defs, String Function(T) nameOf) {
  final text = item.toLowerCase();
  T? best;
  for (final d in defs) {
    if (text.contains(nameOf(d).toLowerCase()) &&
        nameOf(d).length > (best == null ? 0 : nameOf(best).length)) {
      best = d;
    }
  }
  return best;
}

/// Caractéristique, bonus d'attaque et bonus de dégâts d'une arme : Force
/// au corps à corps, Dextérité à distance, la meilleure des deux en finesse.
// ponytail: maîtrise de l'arme supposée, en attendant les maîtrises d'armes
// par classe.
(Ability, int, int) weaponAttack(
  WeaponDef weapon,
  AbilityScores scores,
  int proficiency,
) {
  final str = abilityModifier(scores.strength);
  final dex = abilityModifier(scores.dexterity);
  final ability =
      weapon.ranged || (weapon.finesse && dex > str)
          ? Ability.dexterity
          : Ability.strength;
  final mod = ability == Ability.dexterity ? dex : str;
  return (ability, mod + proficiency, mod);
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
