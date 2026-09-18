import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rules_engine/rules_engine.dart';

/// État de l'achat de points : les six scores, toujours dans une répartition légale.
class PointBuyNotifier extends Notifier<AbilityScores> {
  @override
  AbilityScores build() => PointBuy.standardStart;

  /// Augmente [ability] de 1 si le score reste ≤ 15 et le budget le permet.
  void increment(Ability ability) {
    final next = state[ability] + 1;
    if (next > PointBuy.maxScore) return;
    final candidate = state.withScore(ability, next);
    if (PointBuy.remaining(candidate) < 0) return;
    state = candidate;
  }

  /// Diminue [ability] de 1 si le score reste ≥ 8.
  void decrement(Ability ability) {
    final next = state[ability] - 1;
    if (next < PointBuy.minScore) return;
    state = state.withScore(ability, next);
  }

  /// Retour au point de départ (tout à 8).
  void reset() => state = PointBuy.standardStart;

  /// Charge le tableau standard 15/14/13/12/10/8.
  void useStandardArray() => state = PointBuy.standardArray;
}

final pointBuyProvider =
    NotifierProvider<PointBuyNotifier, AbilityScores>(PointBuyNotifier.new);
