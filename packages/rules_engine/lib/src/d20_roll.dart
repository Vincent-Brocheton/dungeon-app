import 'dart:math';

/// Avantage, désavantage ou jet simple.
enum RollMode {
  /// Un d20.
  normal,

  /// Deux d20, le plus haut est retenu.
  advantage,

  /// Deux d20, le plus bas est retenu.
  disadvantage,
}

/// Un jet de d20 : les dés lancés, celui retenu et le total.
class D20Roll {
  /// Crée un jet à partir de dés déjà lancés.
  const D20Roll({
    required this.dice,
    required this.modifier,
    required this.mode,
  });

  /// Lance un d20 (deux avec avantage ou désavantage) et ajoute [modifier].
  factory D20Roll.roll(
    Random rng,
    int modifier, {
    RollMode mode = RollMode.normal,
  }) => D20Roll(
    dice: [
      rng.nextInt(20) + 1,
      if (mode != RollMode.normal) rng.nextInt(20) + 1,
    ],
    modifier: modifier,
    mode: mode,
  );

  /// Les dés lancés, dans l'ordre.
  final List<int> dice;

  /// Modificateur ajouté au dé retenu.
  final int modifier;

  /// Mode du jet.
  final RollMode mode;

  /// Le dé retenu.
  int get kept => switch (mode) {
    RollMode.normal => dice.first,
    RollMode.advantage => dice.reduce(max),
    RollMode.disadvantage => dice.reduce(min),
  };

  /// Dé retenu + modificateur.
  int get total => kept + modifier;
}
