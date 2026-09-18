/// Bonus de maîtrise selon le niveau de personnage (1–20) : +2 aux niveaux 1–4,
/// puis +1 tous les quatre niveaux jusqu'à +6 au niveau 17.
int proficiencyBonus(int level) {
  if (level < 1 || level > 20) {
    throw RangeError.range(level, 1, 20, 'level');
  }
  return 2 + (level - 1) ~/ 4;
}
