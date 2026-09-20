import 'ability.dart';

/// Les six scores d'un personnage. Immuable.
class AbilityScores {
  /// Crée un jeu de scores ; toute valeur absente vaut 10.
  const AbilityScores({
    this.strength = 10,
    this.dexterity = 10,
    this.constitution = 10,
    this.intelligence = 10,
    this.wisdom = 10,
    this.charisma = 10,
  });

  /// Tous les scores à la même [value].
  const AbilityScores.all(int value)
    : this(
        strength: value,
        dexterity: value,
        constitution: value,
        intelligence: value,
        wisdom: value,
        charisma: value,
      );

  /// Construit depuis une map ; toute caractéristique absente vaut 10.
  factory AbilityScores.fromMap(Map<Ability, int> scores) => AbilityScores(
    strength: scores[Ability.strength] ?? 10,
    dexterity: scores[Ability.dexterity] ?? 10,
    constitution: scores[Ability.constitution] ?? 10,
    intelligence: scores[Ability.intelligence] ?? 10,
    wisdom: scores[Ability.wisdom] ?? 10,
    charisma: scores[Ability.charisma] ?? 10,
  );

  /// Score de Force.
  final int strength;

  /// Score de Dextérité.
  final int dexterity;

  /// Score de Constitution.
  final int constitution;

  /// Score d'Intelligence.
  final int intelligence;

  /// Score de Sagesse.
  final int wisdom;

  /// Score de Charisme.
  final int charisma;

  /// Score de la caractéristique [ability].
  int operator [](Ability ability) => switch (ability) {
    Ability.strength => strength,
    Ability.dexterity => dexterity,
    Ability.constitution => constitution,
    Ability.intelligence => intelligence,
    Ability.wisdom => wisdom,
    Ability.charisma => charisma,
  };

  /// Modificateur de la caractéristique [ability].
  int modifier(Ability ability) => abilityModifier(this[ability]);

  /// Copie avec le score de [ability] remplacé par [value].
  AbilityScores withScore(Ability ability, int value) => switch (ability) {
    Ability.strength => copyWith(strength: value),
    Ability.dexterity => copyWith(dexterity: value),
    Ability.constitution => copyWith(constitution: value),
    Ability.intelligence => copyWith(intelligence: value),
    Ability.wisdom => copyWith(wisdom: value),
    Ability.charisma => copyWith(charisma: value),
  };

  /// Copie avec les scores fournis remplacés.
  AbilityScores copyWith({
    int? strength,
    int? dexterity,
    int? constitution,
    int? intelligence,
    int? wisdom,
    int? charisma,
  }) => AbilityScores(
    strength: strength ?? this.strength,
    dexterity: dexterity ?? this.dexterity,
    constitution: constitution ?? this.constitution,
    intelligence: intelligence ?? this.intelligence,
    wisdom: wisdom ?? this.wisdom,
    charisma: charisma ?? this.charisma,
  );

  /// Vue sous forme de map, dans l'ordre des caractéristiques.
  Map<Ability, int> toMap() => {for (final a in Ability.values) a: this[a]};

  @override
  bool operator ==(Object other) =>
      other is AbilityScores &&
      strength == other.strength &&
      dexterity == other.dexterity &&
      constitution == other.constitution &&
      intelligence == other.intelligence &&
      wisdom == other.wisdom &&
      charisma == other.charisma;

  @override
  int get hashCode => Object.hash(
    strength,
    dexterity,
    constitution,
    intelligence,
    wisdom,
    charisma,
  );

  @override
  String toString() =>
      'AbilityScores(${Ability.values.map((a) => '${a.code} ${this[a]}').join(', ')})';
}
