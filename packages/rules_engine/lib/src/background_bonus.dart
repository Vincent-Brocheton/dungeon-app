import 'ability.dart';
import 'ability_scores.dart';
import 'rule_violation.dart';

/// Bonus de caractéristiques accordé par le Background (PHB 2024) :
/// +2/+1 sur deux des trois caracs du Background, ou +1 sur les trois.
sealed class BackgroundBonus {
  /// Constructeur de base.
  const BackgroundBonus();

  /// Bonus par caractéristique.
  Map<Ability, int> get bonuses;

  /// Violations vis-à-vis des caractéristiques [allowed] du Background.
  List<RuleViolation> validate(Set<Ability> allowed);

  /// Applique le bonus à [base]. Ne vérifie pas les règles : appeler [validate] avant.
  AbilityScores applyTo(AbilityScores base) {
    var result = base;
    for (final entry in bonuses.entries) {
      result = result.withScore(entry.key, result[entry.key] + entry.value);
    }
    return result;
  }

  /// Violations dues au plafond de 20 après application sur [base].
  List<RuleViolation> validateCap(AbilityScores base) {
    final applied = applyTo(base);
    return [
      for (final ability in bonuses.keys)
        if (applied[ability] > abilityScoreCap)
          RuleViolation(
            'ability.over_cap',
            '${ability.code} = ${applied[ability]}, plafond $abilityScoreCap',
            ability: ability,
          ),
    ];
  }
}

/// +2 sur une caractéristique, +1 sur une autre.
final class PlusTwoPlusOne extends BackgroundBonus {
  /// Crée un bonus +2 sur [plusTwo] et +1 sur [plusOne].
  const PlusTwoPlusOne({required this.plusTwo, required this.plusOne});

  /// Caractéristique recevant +2.
  final Ability plusTwo;

  /// Caractéristique recevant +1.
  final Ability plusOne;

  @override
  Map<Ability, int> get bonuses => {plusTwo: 2, plusOne: 1};

  @override
  List<RuleViolation> validate(Set<Ability> allowed) => [
    if (plusTwo == plusOne)
      const RuleViolation(
        'background_bonus.same_ability',
        'Le +2 et le +1 doivent viser deux caractéristiques différentes',
      ),
    for (final ability in {plusTwo, plusOne})
      if (!allowed.contains(ability))
        RuleViolation(
          'background_bonus.not_allowed',
          '${ability.code} ne fait pas partie des caractéristiques du Background',
          ability: ability,
        ),
  ];
}

/// +1 sur les trois caractéristiques du Background.
final class PlusOneEach extends BackgroundBonus {
  /// Crée un bonus +1 sur chacune des [abilities].
  const PlusOneEach(this.abilities);

  /// Les trois caractéristiques bonifiées.
  final Set<Ability> abilities;

  @override
  Map<Ability, int> get bonuses => {for (final a in abilities) a: 1};

  @override
  List<RuleViolation> validate(Set<Ability> allowed) => [
    if (abilities.length != 3)
      RuleViolation(
        'background_bonus.wrong_count',
        'Le +1/+1/+1 vise exactement 3 caractéristiques, reçu ${abilities.length}',
      ),
    for (final ability in abilities)
      if (!allowed.contains(ability))
        RuleViolation(
          'background_bonus.not_allowed',
          '${ability.code} ne fait pas partie des caractéristiques du Background',
          ability: ability,
        ),
  ];
}
