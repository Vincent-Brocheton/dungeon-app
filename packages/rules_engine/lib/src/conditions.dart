import 'ability.dart';
import 'd20_roll.dart';

/// Les conditions du PHB 2024 (l'Épuisement, cumulatif, est à part).
enum Condition {
  /// Aveuglé.
  blinded,

  /// Charmé.
  charmed,

  /// Assourdi.
  deafened,

  /// Effrayé.
  frightened,

  /// Agrippé.
  grappled,

  /// Incapable d'agir.
  incapacitated,

  /// Invisible.
  invisible,

  /// Paralysé.
  paralyzed,

  /// Pétrifié.
  petrified,

  /// Empoisonné.
  poisoned,

  /// À terre.
  prone,

  /// Entravé.
  restrained,

  /// Étourdi.
  stunned,

  /// Inconscient.
  unconscious;

  /// Vitesse ramenée à 0.
  bool get zeroSpeed => const {
    grappled,
    paralyzed,
    petrified,
    restrained,
    stunned,
    unconscious,
  }.contains(this);
}

/// Les trois tests de d20.
enum D20Test {
  /// Jet d'attaque.
  attack,

  /// Test de caractéristique (compétences, initiative comprises).
  check,

  /// Jet de sauvegarde.
  save,
}

/// Effets des conditions et de l'épuisement sur un test de d20.
class D20Effects {
  /// Crée les effets.
  const D20Effects({
    this.advantage = const [],
    this.disadvantage = const [],
    this.autoFail = const [],
    this.penalty = 0,
  });

  /// Conditions qui donnent l'avantage.
  final List<Condition> advantage;

  /// Conditions qui imposent le désavantage.
  final List<Condition> disadvantage;

  /// Conditions qui font rater automatiquement le jet.
  final List<Condition> autoFail;

  /// Malus d'épuisement (négatif ou nul).
  final int penalty;

  /// Avantage et désavantage s'annulent (PHB 2024).
  RollMode get mode => switch ((
    advantage.isNotEmpty,
    disadvantage.isNotEmpty,
  )) {
    (true, false) => RollMode.advantage,
    (false, true) => RollMode.disadvantage,
    _ => RollMode.normal,
  };
}

/// Effets de [conditions] et de [exhaustion] (niveaux 0–6) sur un [test] ;
/// [ability] est la caractéristique du jet de sauvegarde.
D20Effects d20Effects(
  Set<Condition> conditions,
  int exhaustion,
  D20Test test, {
  Ability? ability,
}) {
  final strDex = ability == Ability.strength || ability == Ability.dexterity;
  return D20Effects(
    advantage: [
      if (test == D20Test.attack && conditions.contains(Condition.invisible))
        Condition.invisible,
    ],
    disadvantage: [
      for (final c in conditions)
        if (switch (test) {
          D20Test.attack => const {
            Condition.blinded,
            Condition.frightened,
            Condition.poisoned,
            Condition.prone,
            Condition.restrained,
          }.contains(c),
          D20Test.check => c == Condition.frightened || c == Condition.poisoned,
          D20Test.save =>
            c == Condition.restrained && ability == Ability.dexterity,
        })
          c,
    ],
    autoFail: [
      if (test == D20Test.save && strDex)
        for (final c in conditions)
          if (const {
            Condition.paralyzed,
            Condition.petrified,
            Condition.stunned,
            Condition.unconscious,
          }.contains(c))
            c,
    ],
    penalty: -2 * exhaustion.clamp(0, 6),
  );
}
