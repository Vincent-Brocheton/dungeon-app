/// Jets de sauvegarde contre la mort d'un personnage à 0 PV (PHB 2024).
class DeathSaves {
  /// Crée l'état.
  const DeathSaves({this.successes = 0, this.failures = 0});

  /// Réussites, 0 à 3.
  final int successes;

  /// Échecs, 0 à 3.
  final int failures;

  /// Trois réussites : stable, plus de jets à faire.
  bool get stable => successes >= 3 && failures < 3;

  /// Trois échecs : mort.
  bool get dead => failures >= 3;

  /// Après un jet de [d20] (DD 10, sans bonus) : 1 naturel = 2 échecs, 20
  /// naturel = 1 PV et conscience ([revived], compteurs remis à zéro).
  ({DeathSaves saves, bool revived}) roll(int d20) => switch (d20) {
    20 => (saves: const DeathSaves(), revived: true),
    1 => (saves: _with(failures: failures + 2), revived: false),
    >= 10 => (saves: _with(successes: successes + 1), revived: false),
    _ => (saves: _with(failures: failures + 1), revived: false),
  };

  /// Dégâts subis à 0 PV : un échec, deux sur un coup critique. Un
  /// personnage stable (compteurs remis à zéro) recommence à faire des jets.
  DeathSaves damaged({bool critical = false}) => DeathSaves(
    successes: stable ? 0 : successes,
    failures: ((stable ? 0 : failures) + (critical ? 2 : 1)).clamp(0, 3),
  );

  DeathSaves _with({int? successes, int? failures}) => DeathSaves(
    successes: (successes ?? this.successes).clamp(0, 3),
    failures: (failures ?? this.failures).clamp(0, 3),
  );
}

/// Mort instantanée : les dégâts qui restent après être tombé à 0 PV
/// ([damage] − [currentHp]) égalent ou dépassent les PV maximum.
bool instantDeath({
  required int damage,
  required int currentHp,
  required int maxHp,
}) => damage - currentHp >= maxHp;
