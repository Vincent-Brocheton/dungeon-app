import 'ability.dart';
import 'ability_scores.dart';
import 'rule_violation.dart';

/// Achat de points (PHB 2024) : 27 points, scores de 8 à 15 avant bonus de Background.
abstract final class PointBuy {
  /// Points disponibles.
  static const int budget = 27;

  /// Score minimum achetable.
  static const int minScore = 8;

  /// Score maximum achetable (avant bonus de Background).
  static const int maxScore = 15;

  /// Coût cumulé de chaque score.
  static const Map<int, int> costs = {
    8: 0,
    9: 1,
    10: 2,
    11: 3,
    12: 4,
    13: 5,
    14: 7,
    15: 9,
  };

  /// Point de départ : tous les scores à 8, 27 points à dépenser.
  static const AbilityScores standardStart = AbilityScores.all(minScore);

  /// Exemple canonique du PHB : 15, 14, 13, 12, 10, 8 (coûte exactement 27).
  static const AbilityScores standardArray = AbilityScores(
    strength: 15,
    dexterity: 14,
    constitution: 13,
    intelligence: 12,
    wisdom: 10,
    charisma: 8,
  );

  /// Coût d'un [score]. Lève [ArgumentError] hors de 8–15.
  static int costOf(int score) {
    final cost = costs[score];
    if (cost == null) {
      throw ArgumentError.value(
        score,
        'score',
        'Un score acheté doit être compris entre $minScore et $maxScore',
      );
    }
    return cost;
  }

  /// Vrai si [score] est achetable.
  static bool isPurchasable(int score) => costs.containsKey(score);

  /// Coût total de [scores]. Les scores hors plage sont ignorés (voir [validate]).
  static int totalCost(AbilityScores scores) {
    var total = 0;
    for (final ability in Ability.values) {
      total += costs[scores[ability]] ?? 0;
    }
    return total;
  }

  /// Points restants ; négatif si le budget est dépassé.
  static int remaining(AbilityScores scores) => budget - totalCost(scores);

  /// Coût pour passer de [from] à [to] ; négatif si on rembourse.
  static int deltaCost(int from, int to) => costOf(to) - costOf(from);

  /// Violations de la répartition [scores] (liste vide = valide).
  static List<RuleViolation> validate(AbilityScores scores) {
    final violations = <RuleViolation>[];
    for (final ability in Ability.values) {
      final score = scores[ability];
      if (!isPurchasable(score)) {
        violations.add(
          RuleViolation(
            'point_buy.out_of_range',
            '${ability.code} = $score, attendu entre $minScore et $maxScore',
            ability: ability,
          ),
        );
      }
    }
    final spent = totalCost(scores);
    if (spent > budget) {
      violations.add(
        RuleViolation(
          'point_buy.over_budget',
          '$spent points dépensés pour un budget de $budget',
        ),
      );
    }
    return violations;
  }
}
